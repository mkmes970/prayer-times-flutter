import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/models/ramadan_schedule.dart';
import 'package:prayer_times/services/adhan_alarm_service.dart';
import 'package:prayer_times/services/hijri_date.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/state/prayer_controller.dart';

class MemoryRepository extends LocalRepository {
  MemoryRepository(this.data);
  AppData data;
  bool failSave = false;
  @override
  Future<AppData> load() async => data;
  @override
  Future<void> save(AppData value) async {
    if (failSave) throw StateError('disk full');
    data = AppData.fromJson(jsonDecode(jsonEncode(value.toJson())));
  }
}

class SilentAlarms extends AdhanAlarmService {
  AppData? last;
  @override
  Future<void> synchronize(AppData data,
      {required bool requestPermissions, DateTime? now}) async {
    last = data;
  }
}

DateTime ramadanStart(int year) {
  var date = DateTime(2027);
  while (true) {
    final h = HijriDate.fromGregorian(date);
    if (h.year == year && h.month == 9 && h.day == 1) return date;
    date = date.add(const Duration(days: 1));
  }
}

Map<int, RamadanDay> ramadanDays({int fajr = 325, int maghrib = 1055}) => {
      for (var day = 1; day <= 30; day++)
        day: RamadanDay(fajrSecondMinutes: fajr, maghribMinutes: maghrib)
    };

AppData sampleRamadanData({AppSettings settings = const AppSettings()}) {
  final times = PrayerTimes({
    'fajrFirst': '05:15',
    'fajrSecond': '05:30',
    'sunrise': '06:30',
    'dhuhr': '12:00',
    'asr': '15:00',
    'maghrib': '17:40',
    'isha': '19:00',
  });
  return AppData(regions: {
    for (final id in ['a', 'b'])
      id: PrayerRegion(
          id: id,
          name: 'المنطقة $id',
          days: const {},
          annualDays: {
            for (var day = DateTime(2028);
                day.year == 2028;
                day = day.add(const Duration(days: 1)))
              dateKey(day).substring(5): times
          }),
  }, selectedRegionId: 'a', settings: settings);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'custom year/region overlay persists, never changes base, rolls back on failure',
      () async {
    final start = ramadanStart(1449);
    final repo = MemoryRepository(sampleRamadanData());
    final alarms = SilentAlarms();
    final c = PrayerController(
        repository: repo,
        adhanAlarmService: alarms,
        deviceNow: () => start.add(const Duration(hours: 10)));
    await c.initialize();
    addTearDown(c.dispose);
    expect(c.needsRamadanChoice, isTrue);
    await c.saveRamadanTimes(ramadanDays());
    expect(c.needsRamadanChoice, isFalse);
    final t = c.selectedRegion!.timesFor(c.now)!;
    expect(t.values, {
      'fajrFirst': '04:55',
      'fajrSecond': '05:25',
      'sunrise': '06:30',
      'dhuhr': '12:00',
      'asr': '15:00',
      'maghrib': '17:35',
      'isha': '18:55',
    });
    expect(c.regions['a']!.timesFor(c.now)!['fajrSecond'], '05:30');
    expect(
        c.selectedRegion!
            .timesFor(start.subtract(const Duration(days: 1)))!['maghrib'],
        '17:40');
    expect(
        c.selectedRegion!
            .timesFor(start.add(const Duration(days: 30)))!['maghrib'],
        '17:40');
    expect(c.selectedRegion!.timesFor(ramadanStart(1450))!['maghrib'], '17:40');
    expect(alarms.last!.settings.ramadanPlans['a']!.days.length, 30);
    final restored = PrayerController(
        repository: repo,
        adhanAlarmService: SilentAlarms(),
        deviceNow: () => start);
    await restored.initialize();
    addTearDown(restored.dispose);
    expect(restored.needsRamadanChoice, isFalse);
    expect(restored.selectedRegion!.timesFor(start)!['fajrFirst'], '04:55');
    await c.selectRegion('b');
    expect(c.needsRamadanChoice, isTrue);
    expect(c.selectedRegion!.timesFor(start)!['fajrFirst'], '05:15');
    await c.selectRegion('a');
    repo.failSave = true;
    await expectLater(
        c.saveRamadanTimes(ramadanDays(fajr: 320)), throwsStateError);
    expect(c.selectedRegion!.timesFor(start)!['fajrSecond'], '05:25');
    repo.failSave = false;
    await c.useExistingRamadanTimes();
    expect(c.needsRamadanChoice, isFalse);
    expect(c.currentRamadanPlan!.custom, isFalse);
    expect(c.selectedRegion!.timesFor(start)!['fajrFirst'], '05:15');
  });

  test(
      'Ramadan expiration purges every region on midnight and next year asks again',
      () async {
    final start = ramadanStart(1449);
    var device = start
        .add(const Duration(days: 29, hours: 23, minutes: 59, seconds: 59));
    final plan = RamadanPlan(year: 1449, custom: true, days: ramadanDays());
    final repo = MemoryRepository(sampleRamadanData(
        settings: AppSettings(ramadanPlans: {'a': plan, 'b': plan})));
    final c = PrayerController(
        repository: repo,
        adhanAlarmService: SilentAlarms(),
        deviceNow: () => device);
    await c.initialize();
    addTearDown(c.dispose);
    expect(c.currentRamadanPlan, isNotNull);
    device = device.add(const Duration(seconds: 1));
    c.clock.value = device;
    await c.updateSettings(c.settings);
    expect(c.hijriDateAt(c.now).month, 10);
    expect(c.settings.ramadanPlans, isEmpty);
    expect(repo.data.settings.ramadanPlans, isEmpty);
    expect(c.selectedRegion!.timesFor(c.now)!['fajrSecond'], '05:30');
    expect(c.needsRamadanChoice, isFalse);
    device = ramadanStart(1450);
    c.clock.value = device;
    expect(c.needsRamadanChoice, isTrue);
    expect(c.currentRamadanPlan, isNull);
  });

  test(
      'expired backup is purged on open; existing choice also expires annually',
      () async {
    final start = ramadanStart(1449);
    for (final date in [
      start.add(const Duration(days: 31)),
      ramadanStart(1450)
    ]) {
      final repo = MemoryRepository(sampleRamadanData(
          settings: AppSettings(
              ramadanPlans: {'a': RamadanPlan(year: 1449, custom: false)})));
      final c = PrayerController(
          repository: repo,
          adhanAlarmService: SilentAlarms(),
          deviceNow: () => date);
      await c.initialize();
      expect(c.settings.ramadanPlans, isEmpty);
      expect(repo.data.settings.ramadanPlans, isEmpty);
      expect(c.needsRamadanChoice, date == ramadanStart(1450));
      c.dispose();
    }
  });

  test('incomplete, unset, nonchronological and out-of-month plans cannot save',
      () async {
    final start = ramadanStart(1449);
    var device = start;
    final c = PrayerController(
        repository: MemoryRepository(sampleRamadanData()),
        adhanAlarmService: SilentAlarms(),
        deviceNow: () => device);
    await c.initialize();
    addTearDown(c.dispose);
    await expectLater(c.saveRamadanTimes({}), throwsFormatException);
    await expectLater(
        c.saveRamadanTimes(ramadanDays(fajr: 0)), throwsFormatException);
    await expectLater(
        c.saveRamadanTimes(ramadanDays(maghrib: 0)), throwsFormatException);
    await expectLater(
        c.saveRamadanTimes(ramadanDays(fajr: 400)), throwsFormatException);
    await expectLater(
        c.saveRamadanTimes(ramadanDays(maghrib: 800)), throwsFormatException);
    await expectLater(
        c.saveRamadanTimes(ramadanDays(maghrib: 1400)), throwsFormatException);
    expect(c.currentRamadanPlan, isNull);
    device = start.subtract(const Duration(days: 1));
    c.clock.value = device;
    await expectLater(c.saveRamadanTimes(ramadanDays()), throwsFormatException);
    expect(c.regions['a']!.timesFor(start)!['fajrSecond'], '05:30');
  });

  test(
      'native alarms use matching corrected Hijri, seconds and Ramadan times only for this year',
      () {
    final start = ramadanStart(1449);
    final plan = RamadanPlan(year: 1449, custom: true, days: ramadanDays());
    final data = sampleRamadanData(
        settings: AppSettings(
            adhanEnabled: true,
            clockOffsetSeconds: 15,
            ramadanPlans: {'a': plan}));
    final events = AdhanAlarmSchedule.build(data, now: start, horizonDays: 31);
    final fajr = events.firstWhere((e) => e['prayerId'] == 'fajrSecond');
    expect([fajr['hour'], fajr['minute'], fajr['second']], [5, 24, 45]);
    final isha = events.firstWhere((e) => e['prayerId'] == 'isha');
    expect([isha['hour'], isha['minute'], isha['second']], [18, 54, 45]);
    final lastFajr = events.lastWhere((e) => e['prayerId'] == 'fajrSecond');
    expect([lastFajr['hour'], lastFajr['minute']], [5, 29]);
    final nextYear =
        AdhanAlarmSchedule.build(data, now: ramadanStart(1450), horizonDays: 1);
    expect(nextYear.first['minute'], 29);

    final shifted =
        sampleRamadanData(settings: data.settings.copyWith(hijriOffsetDays: 1));
    final eve = start.subtract(const Duration(days: 1));
    final shiftedEvents =
        AdhanAlarmSchedule.build(shifted, now: eve, horizonDays: 1);
    expect(shiftedEvents.first['minute'], 24);
    final manual = sampleRamadanData(
        settings: data.settings.copyWith(
            hijriManualDay: 1,
            hijriManualMonth: 9,
            hijriAnchorDate: dateKey(eve)));
    expect(
        AdhanAlarmSchedule.build(manual, now: eve, horizonDays: 1)
            .first['minute'],
        24);
  });

  test(
      'Ramadan countdown, iqama and morning adhkar all resolve effective timetable',
      () async {
    final start = ramadanStart(1449);
    final c = PrayerController(
        repository: MemoryRepository(sampleRamadanData(
            settings: AppSettings(ramadanPlans: {
          'a': RamadanPlan(year: 1449, custom: true, days: ramadanDays())
        }))),
        adhanAlarmService: SilentAlarms(),
        deviceNow: () => start);
    await c.initialize();
    addTearDown(c.dispose);
    final at = start.add(const Duration(hours: 5, minutes: 24));
    expect(c.nextPrayerStatus(at).target,
        start.add(const Duration(hours: 5, minutes: 25)));
    expect(c.activePrayerScreen(at.add(const Duration(minutes: 1)))!.phase,
        PrayerScreenPhase.adhanAnnouncement);
    final iqama = c.currentIqamaStatus(at.add(const Duration(minutes: 2)));
    expect(iqama?.target, start.add(const Duration(hours: 5, minutes: 45)));
    expect(c.selectedRegion!.timesFor(start)!['sunrise'], '06:30');
  });

  test(
      'welcome appears after the first-day Fajr prayer, then resumes post-prayer adhkar',
      () async {
    final start = ramadanStart(1449);
    final c = PrayerController(
      repository: MemoryRepository(sampleRamadanData()),
      adhanAlarmService: SilentAlarms(),
      deviceNow: () => start,
    );
    await c.initialize();
    addTearDown(c.dispose);
    final midnight = DateTime(start.year, start.month, start.day, 0, 1);
    expect(c.activePrayerScreen(midnight), isNull);

    final beforePrayerEnds =
        DateTime(start.year, start.month, start.day, 5, 59);
    expect(c.activePrayerScreen(beforePrayerEnds)?.phase,
        PrayerScreenPhase.prayerBlackout);

    final afterPrayerEnds = DateTime(start.year, start.month, start.day, 6, 0);
    expect(c.activePrayerScreen(afterPrayerEnds)?.phase,
        PrayerScreenPhase.ramadanWelcome);
    final returnedAt = DateTime(start.year, start.month, start.day, 6, 4);
    expect(
      c
          .activePrayerScreen(
            returnedAt,
            ramadanWelcomeDismissed: true,
            ramadanWelcomeDismissedAt: returnedAt,
          )
          ?.phase,
      PrayerScreenPhase.postPrayerDhikr,
    );
    expect(
      c
          .activePrayerScreen(
            DateTime(start.year, start.month, start.day, 6, 5),
            ramadanWelcomeDismissed: true,
            ramadanWelcomeDismissedAt: returnedAt,
          )
          ?.phase,
      PrayerScreenPhase.postPrayerDhikr,
    );
    expect(
      c.activePrayerScreen(
        DateTime(start.year, start.month, start.day, 6, 13),
        ramadanWelcomeDismissed: true,
        ramadanWelcomeDismissedAt: returnedAt,
      ),
      isNull,
    );
  });

  test('Taraweeh follows Isha adhkar for its configured duration in Ramadan',
      () async {
    final start = ramadanStart(1449);
    final c = PrayerController(
      repository: MemoryRepository(sampleRamadanData(
        settings: AppSettings(
          ramadanPlans: {
            'a': RamadanPlan(year: 1449, custom: false),
          },
          ramadanTaraweehEnabled: true,
        ),
      )),
      adhanAlarmService: SilentAlarms(),
      deviceNow: () => start,
    );
    await c.initialize();
    addTearDown(c.dispose);

    final date = DateTime(start.year, start.month, start.day);
    expect(
      c
          .activePrayerScreen(DateTime(date.year, date.month, date.day, 19, 32))
          ?.phase,
      PrayerScreenPhase.postPrayerDhikr,
    );
    final taraweeh =
        c.activePrayerScreen(DateTime(date.year, date.month, date.day, 19, 33));
    expect(taraweeh?.phase, PrayerScreenPhase.ramadanTaraweeh);
    expect(taraweeh?.label, 'صلاة التراويح');
    expect(taraweeh?.endsAt, DateTime(date.year, date.month, date.day, 20, 8));
    expect(
      c.activePrayerScreen(DateTime(date.year, date.month, date.day, 20, 8)),
      isNull,
    );

    await c.updateSettings(c.settings.copyWith(ramadanTaraweehEnabled: false));
    expect(
      c
          .activePrayerScreen(DateTime(date.year, date.month, date.day, 19, 40))
          ?.phase,
      isNull,
    );
    final saved = AppSettings.fromJson(c.settings.toJson());
    expect(saved.ramadanTaraweehEnabled, isFalse);
    expect(saved.ramadanTaraweehMinutes, 35);
  });

  test('Qiyam is shown only during the configured hours in the last ten days',
      () async {
    final start = ramadanStart(1449);
    final c = PrayerController(
      repository: MemoryRepository(sampleRamadanData(
        settings: AppSettings(
          ramadanPlans: {
            'a': RamadanPlan(year: 1449, custom: false),
          },
          ramadanQiyamEnabled: true,
          ramadanQiyamStartMinutes: 150,
          ramadanQiyamEndMinutes: 210,
        ),
      )),
      adhanAlarmService: SilentAlarms(),
      deviceNow: () => start,
    );
    await c.initialize();
    addTearDown(c.dispose);

    DateTime day(int hijriDay) => start.add(Duration(days: hijriDay - 1));
    final qiyamDay = day(21);
    expect(
      c
          .activePrayerScreen(
              DateTime(qiyamDay.year, qiyamDay.month, qiyamDay.day, 2, 29))
          ?.phase,
      isNull,
    );
    expect(
      c
          .activePrayerScreen(
              DateTime(qiyamDay.year, qiyamDay.month, qiyamDay.day, 2, 30))
          ?.phase,
      PrayerScreenPhase.ramadanQiyam,
    );
    expect(
      c
          .activePrayerScreen(
              DateTime(qiyamDay.year, qiyamDay.month, qiyamDay.day, 3, 30))
          ?.phase,
      isNull,
    );
    final day20 = day(20);
    expect(
      c
          .activePrayerScreen(
              DateTime(day20.year, day20.month, day20.day, 2, 45))
          ?.phase,
      isNull,
    );

    await c.updateSettings(c.settings.copyWith(ramadanQiyamEnabled: false));
    final saved = AppSettings.fromJson(c.settings.toJson());
    expect(saved.ramadanQiyamEnabled, isFalse);
    expect(saved.ramadanQiyamStartMinutes, 150);
    expect(saved.ramadanQiyamEndMinutes, 210);
  });
}
