import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/services/adhan_alarm_service.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/services/prayer_summary_notification_service.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/settings_screen.dart';

class _MemoryRepository extends LocalRepository {
  _MemoryRepository(this.data);
  AppData data;

  @override
  Future<AppData> load() async => data;

  @override
  Future<void> save(AppData value) async => data = value;
}

class _RecordingAlarms extends AdhanAlarmService {
  AppData? latest;

  @override
  Future<void> synchronize(
    AppData data, {
    required bool requestPermissions,
    DateTime? now,
  }) async {
    latest = data;
  }
}

// This file tests audio controls; do not wait on a real native notification
// channel that does not exist in the Flutter widget-test host.
class _UnsupportedSummary extends PrayerSummaryNotificationService {
  @override
  bool get isSupported => false;
}

void main() {
  final region = PrayerRegion(
    id: 'test-region',
    name: 'منطقة الاختبار',
    days: {
      '2026-10-25': PrayerTimes({
        'fajrFirst': '04:10',
        'fajrSecond': '04:30',
        'sunrise': '05:30',
        'dhuhr': '12:00',
        'asr': '15:00',
        'maghrib': '18:00',
        'isha': '19:30',
      }),
      '2026-10-26': PrayerTimes({
        'fajrFirst': '04:11',
        'fajrSecond': '04:31',
        'sunrise': '05:31',
        'dhuhr': '12:01',
        'asr': '15:01',
        'maghrib': '18:01',
        'isha': '19:31',
      }),
    },
  );

  AppData dataFor(AppSettings settings) => AppData(
        regions: {region.id: region},
        selectedRegionId: region.id,
        settings: settings,
      );

  test('sound alerts are opt-in and preserve per-prayer choices', () {
    const fresh = AppSettings();
    expect(fresh.adhanEnabled, isFalse);
    expect(fresh.adhanPrayerEnabled.values, everyElement(isTrue));

    final saved = AppSettings.fromJson(fresh.copyWith(
      adhanEnabled: true,
      adhanPrayerEnabled: {
        ...fresh.adhanPrayerEnabled,
        'asr': false,
      },
    ).toJson());
    expect(saved.adhanEnabled, isTrue);
    expect(saved.adhanPrayerEnabled['asr'], isFalse);
    expect(saved.adhanPrayerEnabled['maghrib'], isTrue);

    final older = AppSettings.fromJson({'timingDefaultsVersion': 1});
    expect(older.adhanEnabled, isFalse);
    expect(older.adhanPrayerEnabled.values, everyElement(isTrue));
  });

  test('schedule uses second Fajr and only the five audible prayers', () {
    final data = dataFor(const AppSettings(adhanEnabled: true));
    final events = AdhanAlarmSchedule.build(
      data,
      now: DateTime(2026, 10, 25, 4),
      horizonDays: 2,
    );

    expect(events.length, 10);
    expect(events.first, {
      'prayerId': 'fajrSecond',
      'date': '2026-10-25',
      'hour': 4,
      'minute': 30,
    });
    expect(events.any((event) => event['prayerId'] == 'fajrFirst'), isFalse);
    expect(events.any((event) => event['prayerId'] == 'sunrise'), isFalse);
  });

  test('muted prayer and already-passed times are excluded', () {
    final data = dataFor(AppSettings(
      adhanEnabled: true,
      adhanPrayerEnabled: {
        ...defaultAdhanPrayerEnabled,
        'asr': false,
      },
    ));
    final events = AdhanAlarmSchedule.build(
      data,
      now: DateTime(2026, 10, 25, 15),
      horizonDays: 1,
    );

    expect(events.map((event) => event['prayerId']), ['maghrib', 'isha']);
    expect(events.every((event) => event['date'] == '2026-10-25'), isTrue);
  });

  test('no alarms are produced while disabled or before region selection', () {
    expect(
      AdhanAlarmSchedule.build(
        dataFor(const AppSettings()),
        now: DateTime(2026, 10, 25),
        horizonDays: 1,
      ),
      isEmpty,
    );
    expect(
      AdhanAlarmSchedule.build(
        AppData(
          regions: {region.id: region},
          selectedRegionId: '',
          settings: const AppSettings(adhanEnabled: true),
        ),
        now: DateTime(2026, 10, 25),
        horizonDays: 1,
      ),
      isEmpty,
    );
  });

  testWidgets('settings enable five speakers and persist individual mute',
      (tester) async {
    final repository = _MemoryRepository(dataFor(const AppSettings()));
    final alarms = _RecordingAlarms();
    final controller = PrayerController(
      repository: repository,
      adhanAlarmService: alarms,
      prayerSummaryNotificationService: _UnsupportedSummary(),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(controller: controller),
    ));
    final master = find.widgetWithText(SwitchListTile, 'تفعيل صوت الأذان');
    await tester.ensureVisible(master);
    await tester.runAsync(() async {
      await tester.tap(master);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(repository.data.settings.adhanEnabled, isTrue);
    for (final slot in adhanPrayerSlots) {
      expect(find.byTooltip('كتم صوت ${slot.label}'), findsOneWidget);
    }
    final fajr = find.byTooltip('كتم صوت الفجر');
    await tester.ensureVisible(fajr);
    await tester.runAsync(() async {
      await tester.tap(fajr);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.byTooltip('تفعيل صوت الفجر'), findsOneWidget);
    expect(repository.data.settings.adhanPrayerEnabled['fajrSecond'], isFalse);
    expect(alarms.latest!.settings.adhanPrayerEnabled['fajrSecond'], isFalse);
    expect(repository.data.settings.adhanPrayerEnabled['dhuhr'], isTrue);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      master,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(() async {
      final toggle = tester.widget<SwitchListTile>(master);
      expect(toggle.onChanged, isNotNull);
      toggle.onChanged!(false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(repository.data.settings.adhanEnabled, isFalse);
    expect(find.byTooltip('تفعيل صوت الفجر'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
