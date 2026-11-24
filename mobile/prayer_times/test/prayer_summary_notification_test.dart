import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/services/adhan_alarm_service.dart';
import 'package:prayer_times/services/bundled_schedules.dart';
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

class _NoopAdhanService extends AdhanAlarmService {
  @override
  Future<void> synchronize(
    AppData data, {
    required bool requestPermissions,
    DateTime? now,
  }) async {}
}

class _RecordingSummaryService extends PrayerSummaryNotificationService {
  _RecordingSummaryService({this.permissionGranted = true});

  bool permissionGranted;
  final payloads = <Map<String, Object?>>[];
  var permissionRequestCount = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> requestPermission() async {
    permissionRequestCount++;
    return permissionGranted;
  }

  @override
  Future<bool> notificationsAllowed() async => permissionGranted;

  @override
  Future<bool> synchronize(Map<String, Object?> payload) async {
    payloads.add(payload);
    return true;
  }
}

final _region = PrayerRegion(
  id: 'summary-test',
  name: 'منطقة الاختبار',
  days: {
    '2026-06-09': PrayerTimes({
      'fajrFirst': '04:09',
      'fajrSecond': '04:29',
      'sunrise': '05:29',
      'dhuhr': '11:59',
      'asr': '14:59',
      'maghrib': '17:59',
      'isha': '19:29',
    }),
    '2026-06-10': PrayerTimes({
      'fajrFirst': '04:10',
      'fajrSecond': '04:30',
      'sunrise': '05:30',
      'dhuhr': '12:00',
      'asr': '15:00',
      'maghrib': '18:00',
      'isha': '19:30',
    }),
    '2026-06-11': PrayerTimes({
      'fajrFirst': '04:11',
      'fajrSecond': '04:31',
      'sunrise': '05:31',
      'dhuhr': '12:01',
      'asr': '15:01',
      'maghrib': '18:01',
      'isha': '19:31',
    }),
    '2026-06-12': PrayerTimes({
      'fajrFirst': '04:12',
      'fajrSecond': '04:32',
      'sunrise': '05:32',
      'dhuhr': '12:02',
      'asr': '15:02',
      'maghrib': '18:02',
      'isha': '19:32',
    }),
  },
);

AppData _data({
  required bool enabled,
  String selectedRegionId = 'summary-test',
  int clockOffsetSeconds = 0,
  bool? permissionRequested,
}) =>
    AppData(
      regions: {_region.id: _region},
      selectedRegionId: selectedRegionId,
      settings: AppSettings(
        prayerSummaryEnabled: enabled,
        prayerSummaryPermissionRequested: permissionRequested ?? enabled,
        clockOffsetSeconds: clockOffsetSeconds,
      ),
    );

PrayerController _controller({
  required AppData data,
  required _RecordingSummaryService summary,
  DateTime? now,
}) =>
    PrayerController(
      repository: _MemoryRepository(data),
      adhanAlarmService: _NoopAdhanService(),
      prayerSummaryNotificationService: summary,
      deviceNow: () => now ?? DateTime(2026, 6, 10, 11),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('summary sends all daily prayer times and names the next adhan',
      () async {
    final summary = _RecordingSummaryService();
    final controller =
        _controller(data: _data(enabled: true), summary: summary);
    await controller.initialize();
    addTearDown(controller.disposeController);

    final payload = summary.payloads.single;
    expect(payload['enabled'], isTrue);
    expect(payload['regionName'], 'منطقة الاختبار');
    final todaySchedule = payload['todaySchedule']! as Map;
    expect(todaySchedule['date'], '2026-06-10');
    expect(
      (todaySchedule['times'] as Map).keys,
      containsAll([
        'fajrSecond',
        'dhuhr',
        'asr',
        'maghrib',
        'isha',
      ]),
    );
    final schedules = payload['dailySchedules']! as List;
    final today = schedules
        .cast<Map>()
        .firstWhere((entry) => entry['date'] == '2026-06-10');
    final times = today['times'] as Map;
    expect(
        times.keys,
        containsAll([
          'fajrFirst',
          'fajrSecond',
          'sunrise',
          'dhuhr',
          'asr',
          'maghrib',
          'isha',
        ]));
    expect(times['fajrFirst'], '4:10');
    expect(times['fajrSecond'], '4:30');

    final states = (payload['states']! as List).cast<Map>();
    final current = states.lastWhere(
      (state) => state['at'] == '2026-06-10T04:50:00',
    );
    expect(current['label'], 'باقي لأذان الظهر');
    expect(current['target'], '2026-06-10T12:00:00');
    final reminders = (payload['reminders']! as List).cast<Map>();
    final upcomingDhuhr = reminders.first;
    expect(upcomingDhuhr['prayerId'], 'dhuhr');
    expect(upcomingDhuhr['at'], '2026-06-10T11:50:00');
    expect(controller.settings.adhanEnabled, isFalse);
  });

  test('today schedule follows the corrected local date across midnight',
      () async {
    final summary = _RecordingSummaryService();
    final controller = _controller(
      data: _data(enabled: true, clockOffsetSeconds: 20),
      summary: summary,
      now: DateTime(2026, 6, 9, 23, 59, 50),
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    final todaySchedule = summary.payloads.single['todaySchedule']! as Map;
    expect(todaySchedule['date'], '2026-06-10');
    expect((todaySchedule['times'] as Map)['fajrSecond'], '4:30');
  });

  test('Abbasi schedule is present for the date shown in the notification',
      () async {
    final abbasi = (await loadBundledSchedules())
        .firstWhere((region) => region.name.contains('العباسي'));
    final summary = _RecordingSummaryService();
    final controller = PrayerController(
      repository: _MemoryRepository(AppData(
        regions: {abbasi.id: abbasi},
        selectedRegionId: abbasi.id,
        settings: const AppSettings(prayerSummaryEnabled: true),
      )),
      adhanAlarmService: _NoopAdhanService(),
      prayerSummaryNotificationService: summary,
      deviceNow: () => DateTime(2026, 11, 6, 13, 22),
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    final payload = summary.payloads.single;
    final todaySchedule = payload['todaySchedule']! as Map;
    expect(todaySchedule['date'], '2026-11-06');
    final times = todaySchedule['times'] as Map;
    expect(times['fajrSecond'], isNot('—'));
    expect(times['dhuhr'], isNot('—'));
    expect(times['asr'], isNot('—'));
    expect(times['maghrib'], isNot('—'));
    expect(times['isha'], isNot('—'));
  });

  test('missing today schedule is explicit and never reuses yesterday',
      () async {
    final summary = _RecordingSummaryService();
    final controller = _controller(
      data: _data(enabled: true),
      summary: summary,
      now: DateTime(2026, 6, 13, 8),
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    final todaySchedule = summary.payloads.single['todaySchedule']! as Map;
    expect(todaySchedule['date'], '2026-06-13');
    expect(todaySchedule.containsKey('times'), isFalse);
    final schedules =
        (summary.payloads.single['dailySchedules']! as List).cast<Map>();
    expect(schedules.any((entry) => entry['date'] == '2026-06-12'), isTrue);
    expect(schedules.any((entry) => entry['date'] == '2026-06-13'), isFalse);
  });

  test('Fajr first has no iqama; second Fajr and prayer iqama do', () async {
    final summary = _RecordingSummaryService();
    final controller =
        _controller(data: _data(enabled: true), summary: summary);
    await controller.initialize();
    addTearDown(controller.disposeController);

    final states = (summary.payloads.single['states']! as List).cast<Map>();
    final afterFirstFajr = states.firstWhere(
      (state) => state['at'] == '2026-06-10T04:10:00',
    );
    expect(afterFirstFajr['label'], 'باقي لأذان الفجر الثاني');
    expect(afterFirstFajr['target'], '2026-06-10T04:30:00');

    final afterSecondFajr = states.firstWhere(
      (state) => state['at'] == '2026-06-10T04:30:00',
    );
    expect(afterSecondFajr['label'], 'باقي لإقامة صلاة الفجر');
    expect(afterSecondFajr['target'], '2026-06-10T04:50:00');

    final afterDhuhrAdhan = states.firstWhere(
      (state) => state['at'] == '2026-06-10T12:00:00',
    );
    expect(afterDhuhrAdhan['label'], 'باقي لإقامة صلاة الظهر');
    expect(afterDhuhrAdhan['target'], '2026-06-10T12:15:00');

    final afterDhuhrIqama = states.firstWhere(
      (state) => state['at'] == '2026-06-10T12:15:00',
    );
    expect(afterDhuhrIqama['label'], 'باقي لأذان العصر');
    expect(afterDhuhrIqama['target'], '2026-06-10T15:00:00');
  });

  test('every iqama boundary switches immediately to the next adhan', () async {
    final summary = _RecordingSummaryService();
    final controller = _controller(
      data: AppData(
        regions: {_region.id: _region},
        selectedRegionId: _region.id,
        settings: const AppSettings(
          prayerSummaryEnabled: true,
          clockOffsetSeconds: 23,
          iqamaMinutes: {
            'fajrSecond': 20,
            'dhuhr': 15,
            'asr': 15,
            'maghrib': 5,
            'isha': 15,
          },
        ),
      ),
      summary: summary,
    );
    await controller.initialize();
    addTearDown(controller.disposeController);
    final payload = summary.payloads.single;
    expect(payload['clockOffsetSeconds'], 23);
    final states = (payload['states']! as List).cast<Map>();
    final cases = {
      '2026-06-10T04:50:00': ['الظهر', '2026-06-10T12:00:00'],
      '2026-06-10T12:15:00': ['العصر', '2026-06-10T15:00:00'],
      '2026-06-10T15:15:00': ['المغرب', '2026-06-10T18:00:00'],
      '2026-06-10T18:05:00': ['العشاء', '2026-06-10T19:30:00'],
      '2026-06-10T19:45:00': ['الفجر الأول', '2026-06-11T04:11:00'],
    };
    for (final entry in cases.entries) {
      final boundary = DateTime.parse(entry.key);
      final before = controller.countdownStatus(
        boundary.subtract(const Duration(milliseconds: 1)),
      );
      expect(before.kind, DashboardStatusKind.iqama);
      final atBoundary = controller.countdownStatus(boundary);
      expect(atBoundary.kind, DashboardStatusKind.nextEvent);
      expect(atBoundary.label, entry.value.first);
      expect(atBoundary.target, DateTime.parse(entry.value.last));
      final state = states.firstWhere((state) => state['at'] == entry.key);
      expect(state['label'], 'باقي لأذان ${entry.value.first}');
      expect(state['target'], entry.value.last);
    }
  });

  test('Friday Dhuhr skips iqama countdown and clock correction is retained',
      () async {
    final summary = _RecordingSummaryService();
    final controller = _controller(
      data: _data(enabled: true, clockOffsetSeconds: 23),
      summary: summary,
      now: DateTime(2026, 6, 12, 11),
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    final payload = summary.payloads.single;
    expect(payload['clockOffsetSeconds'], 23);
    final states = (payload['states']! as List).cast<Map>();
    final afterDhuhr = states.firstWhere(
      (state) => state['at'] == '2026-06-12T12:02:00',
    );
    expect(afterDhuhr['label'], 'باقي لأذان العصر');
    final reminders = (payload['reminders']! as List).cast<Map>();
    final dhuhrReminder = reminders.firstWhere(
      (event) => event['key'] == '2026-06-12|dhuhr',
    );
    expect(dhuhrReminder['at'], '2026-06-12T11:52:00');
  });

  test('notification permission is requested only after a region is selected',
      () async {
    final summary = _RecordingSummaryService();
    final controller = _controller(
      data: _data(
        enabled: false,
        selectedRegionId: '',
        permissionRequested: false,
      ),
      summary: summary,
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    expect(summary.permissionRequestCount, 0);
    expect(controller.settings.prayerSummaryEnabled, isFalse);

    await controller.selectRegion(_region.id);
    expect(summary.permissionRequestCount, 1);
    expect(controller.settings.prayerSummaryPermissionRequested, isTrue);
    expect(controller.settings.prayerSummaryEnabled, isTrue);
    expect(summary.payloads.last['enabled'], isTrue);
  });

  test(
      'existing selected region triggers the first permission request at launch',
      () async {
    final summary = _RecordingSummaryService();
    final controller = _controller(
      data: _data(
        enabled: false,
        permissionRequested: false,
      ),
      summary: summary,
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    expect(summary.permissionRequestCount, 1);
    expect(controller.settings.prayerSummaryPermissionRequested, isTrue);
    expect(controller.settings.prayerSummaryEnabled, isTrue);
  });

  test('denied permission is not requested again and explains system settings',
      () async {
    final summary = _RecordingSummaryService(permissionGranted: false);
    final controller = _controller(
      data: _data(
        enabled: false,
        selectedRegionId: '',
        permissionRequested: false,
      ),
      summary: summary,
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    await controller.selectRegion(_region.id);
    expect(summary.permissionRequestCount, 1);
    expect(controller.settings.prayerSummaryEnabled, isFalse);
    expect(controller.settings.prayerSummaryPermissionRequested, isTrue);
    expect(controller.prayerSummaryError, contains('إعدادات Android'));

    await controller.selectRegion(_region.id);
    expect(summary.permissionRequestCount, 1);
    expect(controller.prayerSummaryError, contains('إعدادات Android'));

    summary.permissionGranted = true;
    await controller.refreshPrayerSummaryOnResume();
    expect(summary.permissionRequestCount, 1);
    expect(controller.settings.prayerSummaryEnabled, isTrue);
    expect(controller.prayerSummaryError, isNull);
  });

  test('revoked notification permission clears the enabled state', () async {
    final summary = _RecordingSummaryService(permissionGranted: false);
    final controller = _controller(
      data: _data(
        enabled: true,
        permissionRequested: true,
      ),
      summary: summary,
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    expect(summary.permissionRequestCount, 0);
    expect(controller.settings.prayerSummaryEnabled, isFalse);
    expect(controller.prayerSummaryError, contains('إعدادات Android'));
    expect(summary.payloads, isNotEmpty);
    expect(summary.payloads.last, {'enabled': false});
  });

  test('late notification refresh catches up after iqama and midnight',
      () async {
    final summary = _RecordingSummaryService();
    final controller = _controller(
      data: AppData(
        regions: {_region.id: _region},
        selectedRegionId: _region.id,
        settings: const AppSettings(
          prayerSummaryEnabled: true,
          iqamaMinutes: {'dhuhr': 15, 'fajrSecond': 20},
        ),
      ),
      summary: summary,
      now: DateTime(2026, 6, 10, 11),
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    // Simulate Android refreshing well after the Dhuhr iqama boundary.
    final afterIqama = controller.countdownStatus(
      DateTime(2026, 6, 10, 12, 40),
    );
    expect(afterIqama.kind, DashboardStatusKind.nextEvent);
    expect(afterIqama.label, 'العصر');
    expect(afterIqama.target, DateTime(2026, 6, 10, 15));

    // A late update after the new day's Fajr iqama must jump to Dhuhr.
    final afterFajrIqama = controller.countdownStatus(
      DateTime(2026, 6, 11, 4, 55),
    );
    expect(afterFajrIqama.kind, DashboardStatusKind.nextEvent);
    expect(afterFajrIqama.label, 'الظهر');
    expect(afterFajrIqama.target, DateTime(2026, 6, 11, 12, 1));

    final states = (summary.payloads.single['states']! as List).cast<Map>();
    final afterMidnight = states.firstWhere(
      (state) => state['at'] == '2026-06-11T00:00:00',
    );
    expect(afterMidnight['label'], 'باقي لأذان الفجر الأول');
    expect(afterMidnight['target'], '2026-06-11T04:11:00');
  });

  test('no selected region removes the notification payload', () async {
    final summary = _RecordingSummaryService();
    final controller = _controller(
      data: _data(enabled: true, selectedRegionId: ''),
      summary: summary,
    );
    await controller.initialize();
    addTearDown(controller.disposeController);

    expect(summary.payloads.single, {'enabled': false});
    expect(controller.prayerSummaryError, contains('اختر المنطقة'));
  });

  testWidgets('Android settings do not show a manual notification switch',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final summary = _RecordingSummaryService(permissionGranted: false);
    final controller = _controller(
      data: _data(
        enabled: false,
        permissionRequested: true,
      ),
      summary: summary,
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.disposeController);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(controller: controller)),
    );

    final toggle = find.widgetWithText(
        SwitchListTile, 'عرض مواقيت اليوم في لوحة الإشعارات');
    expect(toggle, findsNothing);
    expect(find.text('مواقيت الصلاة في الإشعارات'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('إعدادات Android'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('إعدادات Android'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
}
