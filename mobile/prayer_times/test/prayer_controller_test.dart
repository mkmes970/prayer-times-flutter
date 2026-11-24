import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/state/prayer_controller.dart';

class MemoryRepository extends LocalRepository {
  MemoryRepository(this.data);

  AppData data;

  @override
  Future<AppData> load() async => data;

  @override
  Future<void> save(AppData value) async {
    data = value;
  }
}

PrayerTimes _times({
  String fajrFirst = '04:30',
  String fajrSecond = '04:50',
  String sunrise = '06:10',
  String dhuhr = '12:00',
  String asr = '15:30',
  String maghrib = '18:00',
  String isha = '20:00',
}) =>
    PrayerTimes({
      'fajrFirst': fajrFirst,
      'fajrSecond': fajrSecond,
      'sunrise': sunrise,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
    });

PrayerController _controller(
  Map<String, PrayerTimes> days, {
  AppSettings settings = const AppSettings(),
}) {
  final region = PrayerRegion(id: 'test-region', name: 'المنطقة', days: days);
  return PrayerController(
    repository: MemoryRepository(
      AppData(
        regions: {region.id: region},
        selectedRegionId: region.id,
        settings: settings,
      ),
    ),
  );
}

void main() {
  test('single countdown skips first Fajr iqama and excludes sunrise',
      () async {
    final controller = _controller({
      '2026-06-10': _times(),
      '2026-06-11': _times(),
    }, settings: const AppSettings(iqamaMinutes: {'fajrSecond': 20}));
    await controller.initialize();
    addTearDown(controller.dispose);

    DashboardStatus at(int hour, int minute, [int second = 0]) =>
        controller.countdownStatus(DateTime(2026, 6, 10, hour, minute, second));
    expect(at(4, 29, 59).prayerId, 'fajrFirst');
    expect(at(4, 30).prayerId, 'fajrSecond');
    expect(at(4, 30).kind, DashboardStatusKind.nextEvent);
    expect(controller.currentIqamaStatus(DateTime(2026, 6, 10, 4, 30)), isNull);
    expect(at(4, 49, 59).remainingAt(DateTime(2026, 6, 10, 4, 49, 59)),
        const Duration(seconds: 1));
    expect(at(4, 50).kind, DashboardStatusKind.iqama);
    expect(at(4, 50).target, DateTime(2026, 6, 10, 5, 10));
    expect(at(5, 10).prayerId, 'dhuhr');
    expect(at(23, 59).prayerId, 'fajrFirst');
    expect(at(23, 59).target, DateTime(2026, 6, 11, 4, 30));
    // Existing dashboard/highlight callers retain their original behavior.
    expect(controller.nextPrayerStatus(DateTime(2026, 6, 10, 4)).prayerId,
        'fajrSecond');
  });

  test(
      'single countdown returns after prayer and adhkar without changing phases',
      () async {
    final controller = _controller({
      '2026-06-10': _times(),
    },
        settings: const AppSettings(
          iqamaMinutes: {'dhuhr': 15},
          prayerDurationMinutes: {'dhuhr': 8},
          postPrayerDhikrMinutes: 5,
        ));
    await controller.initialize();
    addTearDown(controller.dispose);
    expect(controller.countdownStatus(DateTime(2026, 6, 10, 11, 59)).prayerId,
        'dhuhr');
    expect(controller.countdownStatus(DateTime(2026, 6, 10, 12)).kind,
        DashboardStatusKind.iqama);
    expect(controller.activePrayerScreen(DateTime(2026, 6, 10, 12, 16))!.phase,
        PrayerScreenPhase.prayerBlackout);
    expect(controller.activePrayerScreen(DateTime(2026, 6, 10, 12, 24))!.phase,
        PrayerScreenPhase.postPrayerDhikr);
    expect(
        controller.activePrayerScreen(DateTime(2026, 6, 10, 12, 28)), isNull);
    final next = controller.countdownStatus(DateTime(2026, 6, 10, 12, 28));
    expect(next.kind, DashboardStatusKind.nextEvent);
    expect(next.prayerId, 'asr');
  });

  test('dashboard line-color preview is temporary, persists, and resets',
      () async {
    final controller = _controller({'2026-06-10': _times()});
    await controller.initialize();
    addTearDown(controller.dispose);

    controller.previewDashboardLineColor(0xFFFFEB3B);
    expect(controller.dashboardTextColor, 0xFFFFEB3B);
    expect(controller.settings.dashboardTextColorEnabled, isFalse);

    await controller.updateSettings(controller.settings.copyWith(
      dashboardTextColorEnabled: true,
      dashboardTextColor: 0xFFFFEB3B,
    ));
    controller.previewDashboardLineColor(null);
    expect(controller.dashboardTextColor, 0xFFFFEB3B);

    await controller.updateSettings(controller.settings.copyWith(
      dashboardTextColorEnabled: false,
      dashboardTextColor: 0xFF17432E,
    ));
    expect(controller.dashboardTextColor, isNull);
    expect(controller.settings.dashboardTextColorEnabled, isFalse);
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prayer and iqama countdown', () {
    test(
      'next prayer countdown skips sunrise and continues during current iqama',
      () async {
        final controller = _controller({
          '2026-06-10': _times(),
          '2026-06-11': _times(),
        }, settings: const AppSettings(iqamaMinutes: {'dhuhr': 15}));
        await controller.initialize();
        addTearDown(controller.dispose);

        final afterFajr = controller.nextPrayerStatus(DateTime(2026, 6, 10, 5));
        expect(afterFajr.prayerId, 'dhuhr');
        expect(afterFajr.target, DateTime(2026, 6, 10, 12));

        final duringDhuhrIqama = DateTime(2026, 6, 10, 12, 5);
        expect(
          controller.currentIqamaStatus(duringDhuhrIqama)?.prayerId,
          'dhuhr',
        );
        final nextAfterDhuhr = controller.nextPrayerStatus(duringDhuhrIqama);
        expect(nextAfterDhuhr.prayerId, 'asr');
        expect(nextAfterDhuhr.target, DateTime(2026, 6, 10, 15, 30));
      },
    );

    test(
      'starts iqama countdown at the adhan and moves to the next prayer after it',
      () async {
        final controller = _controller({
          '2026-06-10': _times(),
        }, settings: const AppSettings(iqamaMinutes: {'dhuhr': 15}));
        await controller.initialize();
        addTearDown(controller.dispose);

        final duringIqama = controller.dashboardStatus(
          DateTime(2026, 6, 10, 12, 5),
        );
        expect(duringIqama.kind, DashboardStatusKind.iqama);
        expect(duringIqama.prayerId, 'dhuhr');
        expect(
          duringIqama.remainingAt(DateTime(2026, 6, 10, 12, 5)),
          const Duration(minutes: 10),
        );

        final afterIqama = controller.dashboardStatus(
          DateTime(2026, 6, 10, 12, 15),
        );
        expect(afterIqama.kind, DashboardStatusKind.nextEvent);
        expect(afterIqama.prayerId, 'asr');
        expect(afterIqama.target, DateTime(2026, 6, 10, 15, 30));
      },
    );

    test('continues from isha to the next day fajr prayer', () async {
      final controller = _controller({
        '2026-06-10': _times(),
        '2026-06-11': _times(
          fajrFirst: '04:42',
          fajrSecond: '05:01',
          sunrise: '06:18',
        ),
      });
      await controller.initialize();
      addTearDown(controller.dispose);

      final status = controller.dashboardStatus(DateTime(2026, 6, 10, 23, 40));
      expect(status.kind, DashboardStatusKind.nextEvent);
      expect(status.prayerId, 'fajrSecond');
      expect(status.target, DateTime(2026, 6, 11, 5, 1));
    });

    test(
      'reports the missing next day instead of guessing its times',
      () async {
        final controller = _controller({'2026-06-10': _times()});
        await controller.initialize();
        addTearDown(controller.dispose);

        final status = controller.dashboardStatus(
          DateTime(2026, 6, 10, 23, 40),
        );
        expect(status.kind, DashboardStatusKind.missingNextDay);
        expect(status.target, isNull);
      },
    );

    test(
      'does not show a fabricated countdown if today has no imported timetable',
      () async {
        final controller = _controller(const {});
        await controller.initialize();
        addTearDown(controller.dispose);

        final status = controller.dashboardStatus(DateTime(2026, 6, 10, 8));
        expect(status.kind, DashboardStatusKind.noTodaySchedule);
        expect(status.target, isNull);
      },
    );
  });

  group('Prayer and Friday screen timing', () {
    test('adhan and iqama alerts use exact boundaries and configured wait',
        () async {
      final controller = _controller(
        {'2026-06-10': _times()},
        settings: const AppSettings(
          iqamaMinutes: {'dhuhr': 15},
          prayerDurationMinutes: {},
          postPrayerDhikrMinutes: null,
        ),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      final adhan = DateTime(2026, 6, 10, 12);
      expect(
          controller
              .activePrayerScreen(adhan.subtract(const Duration(seconds: 31))),
          isNull);
      expect(
          controller
              .activePrayerScreen(adhan.subtract(const Duration(seconds: 30)))
              ?.phase,
          PrayerScreenPhase.adhanCountdown);
      expect(controller.activePrayerScreen(adhan)?.phase,
          PrayerScreenPhase.adhanCountdown);
      expect(controller.activePrayerScreen(adhan)?.remainingAt(adhan),
          Duration.zero);
      expect(
          controller
              .activePrayerScreen(adhan.add(const Duration(seconds: 1)))
              ?.phase,
          PrayerScreenPhase.adhanAnnouncement);
      expect(
          controller.activePrayerScreen(adhan.add(const Duration(seconds: 16))),
          isNull);
      expect(
          controller
              .activePrayerScreen(
                  adhan.add(const Duration(minutes: 14, seconds: 30)))
              ?.phase,
          PrayerScreenPhase.iqamaCountdown);
      expect(
          controller
              .activePrayerScreen(
                  adhan.add(const Duration(minutes: 15, seconds: 1)))
              ?.phase,
          isNull);
      expect(
          controller.activePrayerScreen(adhan.add(const Duration(minutes: 16))),
          isNull);
    });

    test('shows the prayer, blackout, then post-prayer sequence', () async {
      final controller = _controller(
        {'2026-06-10': _times()},
        settings: const AppSettings(
          iqamaMinutes: {'dhuhr': 20},
          prayerDurationMinutes: {'dhuhr': 10},
          postPrayerDhikrMinutes: 7,
        ),
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      expect(
        controller.activePrayerScreen(DateTime(2026, 6, 10, 12, 19)),
        isNull,
      );
      expect(
        controller.activePrayerScreen(DateTime(2026, 6, 10, 12, 20, 1))?.phase,
        PrayerScreenPhase.prayerBlackout,
      );
      expect(
        controller
            .activePrayerScreen(DateTime(2026, 6, 10, 12, 20, 44, 999))
            ?.phase,
        PrayerScreenPhase.prayerBlackout,
      );
      expect(
        controller.activePrayerScreen(DateTime(2026, 6, 10, 12, 20, 45))?.phase,
        PrayerScreenPhase.prayerBlackout,
      );
      expect(
        controller.activePrayerScreen(DateTime(2026, 6, 10, 12, 21))?.phase,
        PrayerScreenPhase.prayerBlackout,
      );
      expect(
        controller.activePrayerScreen(DateTime(2026, 6, 10, 12, 30))?.phase,
        PrayerScreenPhase.postPrayerDhikr,
      );
      expect(
        controller.activePrayerScreen(DateTime(2026, 6, 10, 12, 37)),
        isNull,
      );
    });

    test(
      'Friday khutbah replaces Dhuhr iqama and uses its own duration',
      () async {
        final controller = _controller(
          {'2026-06-12': _times()},
          settings: const AppSettings(
            iqamaMinutes: {'dhuhr': 15},
            fridayKhutbahMinutes: 20,
            postPrayerDhikrMinutes: 7,
          ),
        );
        await controller.initialize();
        addTearDown(controller.dispose);

        final adhan = DateTime(2026, 6, 12, 12);
        expect(adhan.weekday, DateTime.friday);
        expect(controller.currentIqamaStatus(adhan), isNull);
        expect(
          controller
              .activePrayerScreen(adhan.add(const Duration(seconds: 1)))
              ?.phase,
          PrayerScreenPhase.fridayKhutbah,
        );
        expect(
          controller
              .activePrayerScreen(
                adhan.add(const Duration(seconds: 59)),
              )
              ?.phase,
          PrayerScreenPhase.fridayKhutbah,
        );
        expect(
          controller
              .activePrayerScreen(
                adhan.add(const Duration(minutes: 1)),
              )
              ?.phase,
          PrayerScreenPhase.fridayBlackout,
        );
        expect(
          controller
              .activePrayerScreen(adhan.add(const Duration(minutes: 3)))
              ?.phase,
          PrayerScreenPhase.fridayBlackout,
        );
        expect(
          controller
              .activePrayerScreen(adhan.add(const Duration(minutes: 20)))
              ?.phase,
          PrayerScreenPhase.postPrayerDhikr,
        );
        expect(
          controller
              .activePrayerScreen(adhan.add(const Duration(minutes: 26)))
              ?.phase,
          PrayerScreenPhase.postPrayerDhikr,
        );
        expect(
            controller
                .activePrayerScreen(adhan.add(const Duration(minutes: 27))),
            isNull);
      },
    );
  });
}
