import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/services/adhan_alarm_service.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/services/prayer_summary_notification_service.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/clock_correction_controls.dart';
import 'package:prayer_times/ui/prayer_activity_screen.dart';

class _Repository extends LocalRepository {
  _Repository(this.data);
  AppData data;
  bool failSave = false;
  @override
  Future<AppData> load() async => data;
  @override
  Future<void> save(AppData value) async {
    if (failSave) throw StateError('Storage unavailable');
    data = value;
  }
}

class _Alarms extends AdhanAlarmService {
  DateTime? rawNow;
  @override
  Future<void> synchronize(AppData data,
      {required bool requestPermissions, DateTime? now}) async {
    rawNow = now;
  }
}

class _UnsupportedSummaryNotifications extends PrayerSummaryNotificationService {
  @override
  bool get isSupported => false;
}

AppData _data({int correction = 0, bool midnight = false}) {
  final region = PrayerRegion(id: 'test', name: 'منطقة الاختبار', days: {
    for (final day in [24, 25, 26])
      '2026-10-$day': PrayerTimes({
        'fajrFirst': midnight ? '00:00' : '04:15',
        'fajrSecond': midnight ? '00:01' : '04:30',
        'sunrise': '06:00',
        'dhuhr': '12:00',
        'asr': '15:00',
        'maghrib': '18:00',
        'isha': '19:30',
      }),
  });
  return AppData(
    regions: {region.id: region},
    selectedRegionId: region.id,
    settings: AppSettings(
      clockOffsetSeconds: correction,
      adhanEnabled: true,
      iqamaMinutes: const {'dhuhr': 15},
      prayerDurationMinutes: const {'dhuhr': 8},
      postPrayerDhikrMinutes: 5,
    ),
  );
}

Future<void> pumpAsyncAction(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('corrections accumulate, survive reopening and do not drift per tick',
      () async {
    var device = DateTime(2026, 10, 25, 5, 45, 15);
    final repository = _Repository(_data());
    final alarms = _Alarms();
    final controller = PrayerController(
      repository: repository,
      adhanAlarmService: alarms,
      deviceNow: () => device,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    await controller.adjustClockSeconds(15);
    expect(controller.now, DateTime(2026, 10, 25, 5, 45, 30));
    device = device.add(const Duration(seconds: 1));
    expect(controller.correctedTime(device), DateTime(2026, 10, 25, 5, 45, 31));
    await controller.adjustClockSeconds(-4);
    expect(controller.settings.clockOffsetSeconds, 11);
    await controller.adjustClockSeconds(60);
    await controller.adjustClockSeconds(60);
    expect(controller.settings.clockOffsetSeconds, 131);
    expect(alarms.rawNow, device, reason: 'Do not apply the correction twice.');
    repository.data =
        AppData.fromJson(jsonDecode(jsonEncode(repository.data.toJson())));
    final reopened = PrayerController(
        repository: repository,
        adhanAlarmService: _Alarms(),
        deviceNow: () => device);
    await reopened.initialize();
    addTearDown(reopened.dispose);
    expect(reopened.now, device.add(const Duration(seconds: 131)));
    expect(reopened.settings.clockOffsetSeconds, 131);
    expect(reopened.selectedRegionId, 'test');
    expect(reopened.selectedRegion!.timesFor(device)!['dhuhr'], '12:00');
    await expectLater(controller.adjustClockSeconds(61), throwsArgumentError);
    await expectLater(controller.adjustClockSeconds(-61), throwsArgumentError);
    expect(controller.settings.clockOffsetSeconds, 131);
  });

  test('failed save does not apply a clock adjustment', () async {
    final repository = _Repository(_data())..failSave = true;
    final device = DateTime(2026, 10, 25, 5, 45, 15);
    final controller = PrayerController(
        repository: repository,
        adhanAlarmService: _Alarms(),
        deviceNow: () => device);
    await controller.initialize();
    addTearDown(controller.dispose);
    await expectLater(controller.adjustClockSeconds(15), throwsStateError);
    expect(controller.settings.clockOffsetSeconds, 0);
    expect(controller.now, device);
    expect(repository.data.settings.clockOffsetSeconds, 0);
  });

  test('correction drives adhan, iqama, immediate prayer and dhikr boundaries',
      () async {
    final controller = PrayerController(
        repository: _Repository(_data(correction: 15)),
        adhanAlarmService: _Alarms());
    await controller.initialize();
    addTearDown(controller.dispose);
    DateTime at(int hour, int minute, int second) =>
        controller.correctedTime(DateTime(2026, 10, 25, hour, minute, second));
    expect(controller.activePrayerScreen(at(11, 59, 15))!.phase,
        PrayerScreenPhase.adhanCountdown);
    final adhanZero = controller.activePrayerScreen(at(11, 59, 45))!;
    expect(adhanZero.phase, PrayerScreenPhase.adhanCountdown);
    expect(adhanZero.remainingAt(at(11, 59, 45)), Duration.zero);
    expect(controller.activePrayerScreen(at(11, 59, 46))!.phase,
        PrayerScreenPhase.adhanAnnouncement);
    expect(controller.activePrayerScreen(at(12, 14, 15))!.phase,
        PrayerScreenPhase.iqamaCountdown);
    final iqamaZero = controller.activePrayerScreen(at(12, 14, 45))!;
    expect(iqamaZero.phase, PrayerScreenPhase.iqamaCountdown);
    expect(iqamaZero.remainingAt(at(12, 14, 45)), Duration.zero);
    expect(controller.activePrayerScreen(at(12, 14, 46))!.phase,
        PrayerScreenPhase.prayerBlackout);
    expect(controller.activePrayerScreen(at(12, 22, 44))!.phase,
        PrayerScreenPhase.prayerBlackout);
    expect(controller.activePrayerScreen(at(12, 22, 45))!.phase,
        PrayerScreenPhase.postPrayerDhikr);
    expect(controller.nextPrayerStatus(at(11, 59, 44)).prayerId, 'dhuhr');
    expect(controller.nextPrayerStatus(at(11, 59, 46)).prayerId, 'asr');
    expect(controller.correctedTime(DateTime(2026, 10, 25, 23, 59, 50)),
        DateTime(2026, 10, 26, 0, 0, 5));
  });

  test('native sound alarms match the corrected clock, including date rollover',
      () {
    for (final correction in [15, -15, 60, -60]) {
      final events = AdhanAlarmSchedule.build(_data(correction: correction),
          now: DateTime(2026, 10, 25, 11), horizonDays: 1);
      final dhuhr = events.firstWhere((event) => event['prayerId'] == 'dhuhr');
      final expected =
          DateTime(2026, 10, 25, 12).subtract(Duration(seconds: correction));
      expect(dhuhr['hour'], expected.hour);
      expect(dhuhr['minute'], expected.minute);
      expect(dhuhr['second'] ?? 0, expected.second);
    }
    final midnight = AdhanAlarmSchedule.build(
            _data(correction: 120, midnight: true),
            now: DateTime(2026, 10, 24, 23, 58),
            horizonDays: 1)
        .first;
    expect(midnight['date'], '2026-10-24');
    expect(midnight['hour'], 23);
    expect(midnight['minute'], 59);
    expect(
        AppSettings.fromJson({'timingDefaultsVersion': 1}).clockOffsetSeconds,
        0);
  });

  testWidgets(
      'save resets only the input; repeated positive/negative saves work',
      (tester) async {
    final repository = _Repository(_data());
    final controller = PrayerController(
      repository: repository,
      adhanAlarmService: _Alarms(),
      prayerSummaryNotificationService: _UnsupportedSummaryNotifications(),
      deviceNow: () => DateTime(2026, 10, 25, 5, 45, 15),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ClockCorrectionControls(controller: controller)),
    ));
    void choose(int seconds) => tester
        .widget<Slider>(find.byKey(const Key('clock-correction-slider')))
        .onChanged!(seconds.toDouble());
    for (final seconds in [15, -5, 60, -60]) {
      choose(seconds);
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-clock-correction')));
      await pumpAsyncAction(tester);
      expect(find.text('0 ثانية'), findsOneWidget);
    }
    expect(controller.settings.clockOffsetSeconds, 10);
    expect(controller.now, DateTime(2026, 10, 25, 5, 45, 25));
    choose(60);
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('clock-correction-plus')))
            .onPressed,
        isNull);
    choose(-60);
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('clock-correction-minus')))
            .onPressed,
        isNull);
    repository.failSave = true;
    await tester.tap(find.byKey(const Key('save-clock-correction')));
    await pumpAsyncAction(tester);
    expect(find.text('-60 ثانية'), findsOneWidget);
    expect(controller.settings.clockOffsetSeconds, 10);
    expect(find.textContaining('تعذر حفظ التصحيح'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('prayer screen is black, red, ordered and fits phone/TV sizes',
      (tester) async {
    final now = DateTime(2026, 10, 25, 13, 15, 7);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final entry in [
      (PrayerScreenPhase.prayerBlackout, 'الصلاة قائمة'),
      (PrayerScreenPhase.ramadanTaraweeh, 'صلاة التراويح'),
      (PrayerScreenPhase.ramadanQiyam, 'صلاة القيام'),
    ]) {
      final status = PrayerScreenStatus(
        phase: entry.$1,
        label: entry.$2,
        prayerId: 'isha',
        startsAt: now,
        endsAt: now.add(const Duration(minutes: 8)),
      );
      for (final size in [
        const Size(360, 800),
        const Size(800, 360),
        const Size(1920, 1080)
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
            MaterialApp(home: PrayerActivityScreen(status: status, now: now)));
        await tester.pump();
        expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            Colors.black);
        for (final label in ['1:15:07', entry.$2]) {
          expect(
              tester.widget<Text>(find.text(label)).style!.color, Colors.red);
        }
        final clockY = tester.getCenter(find.text('1:15:07')).dy;
        final titleY = tester.getCenter(find.text(entry.$2)).dy;
        final phone = find.byKey(const ValueKey('prayer-no-phone'));
        final phoneY = tester.getCenter(phone).dy;
        expect(clockY, lessThan(titleY));
        expect(titleY, closeTo(size.height / 2, 1));
        expect(phoneY, greaterThan(size.height * .7));
        expect(titleY, lessThan(phoneY));
        expect(find.text('يرجى إغلاق الهاتف'), findsNothing);
        expect((tester.widget<Image>(phone).image as AssetImage).assetName,
            'assets/images/no-phone.png');
        expect(find.byIcon(Icons.phonelink_off), findsNothing);
        expect(tester.widget<Text>(find.text('1:15:07')).style!.fontSize,
            lessThan(48));
        expect(tester.widget<Text>(find.text(entry.$2)).style!.fontSize,
            lessThan(68));
        expect(tester.widget<Text>(find.text(entry.$2)).style!.fontWeight,
            FontWeight.w400);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
