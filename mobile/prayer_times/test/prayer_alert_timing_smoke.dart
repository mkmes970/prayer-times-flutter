import 'dart:io';
import 'package:prayer_times/models/prayer_alert_timing.dart';

void main() {
  final noon = DateTime(2026, 10, 13, 11, 50);
  final event = PrayerAlertEvent(
    prayerId: 'dhuhr',
    label: 'الظهر',
    adhanAt: noon,
    iqamaMinutes: 15,
  );
  PrayerAlert? at(DateTime now) => activePrayerAlert(now, [event]);
  void expect(bool value, String message) {
    if (!value) throw StateError(message);
  }

  expect(
      at(noon.subtract(const Duration(seconds: 31))) == null, 'Before window');
  final start = noon.subtract(const Duration(seconds: 30));
  expect(at(start)?.kind == PrayerAlertKind.adhanCountdown, 'Starts at -30');
  expect(at(start)?.secondsAt(start) == 30, 'Display 30');
  final partial = start.add(const Duration(milliseconds: 200));
  expect(at(partial)?.secondsAt(partial) == 30, 'Round partial seconds up');
  expect(at(start.subtract(const Duration(microseconds: 1))) == null,
      'Do not open even one microsecond before 30');
  for (var seconds = 30; seconds >= 0; seconds--) {
    final now = noon.subtract(Duration(seconds: seconds));
    expect(at(now)?.secondsAt(now) == seconds, 'Countdown $seconds');
  }
  expect(at(noon)?.kind == PrayerAlertKind.adhanCountdown, 'Zero at adhan');
  expect(at(noon.add(const Duration(milliseconds: 999)))?.secondsAt(noon) == 0,
      'Zero remains visible for one clock second');
  expect(
      at(noon.add(const Duration(seconds: 1)))?.label == 'حان موعد أذان الظهر',
      'Announcement label');
  expect(at(noon.add(const Duration(seconds: 15, milliseconds: 999))) != null,
      'Announcement lasts full 15 seconds');
  expect(
      at(noon.add(const Duration(seconds: 16))) == null, 'Restore dashboard');
  final iqama = noon.add(const Duration(minutes: 15));
  final fajr = PrayerAlertEvent(
    prayerId: 'fajrSecond',
    label: 'الفجر الثاني',
    adhanAt: DateTime(2026, 10, 14, 5),
    iqamaMinutes: 20,
  );
  expect(
      activePrayerAlert(DateTime(2026, 10, 14, 5, 19, 30), [fajr])?.label ==
          'الوقت المتبقي لإقامة الصلاة',
      'Iqama countdown omits prayer name');
  expect(iqamaPrayerLabel(fajr.prayerId, fajr.label) == 'الفجر',
      'Dashboard uses Fajr iqama name');
  expect(
      at(iqama.subtract(const Duration(seconds: 31))) == null, 'Normal wait');
  expect(
      at(iqama.subtract(const Duration(seconds: 30)))?.kind ==
          PrayerAlertKind.iqamaCountdown,
      'Final 30 seconds of wait');
  expect(
      at(iqama.subtract(const Duration(seconds: 1)))
              ?.secondsAt(iqama.subtract(const Duration(seconds: 1))) ==
          1,
      'Last iqama second');
  expect(at(iqama)?.kind == PrayerAlertKind.iqamaCountdown, 'Show iqama zero');
  expect(at(iqama.add(const Duration(seconds: 1))) == null,
      'Hand over after zero second');
  expect(at(iqama.subtract(const Duration(seconds: 1)))?.secondsAt(iqama) == 0,
      'Remaining time is zero at deadline');
  expect(at(noon)?.secondsAt(noon.add(const Duration(hours: 2))) == 0,
      'Background suspension cannot leave stale countdown');
  for (final minutes in [null, 0]) {
    final unset = PrayerAlertEvent(
      prayerId: 'dhuhr',
      label: 'الظهر',
      adhanAt: noon,
      iqamaMinutes: minutes,
    );
    expect(
        activePrayerAlert(noon.add(const Duration(seconds: 1)), [unset])
                ?.kind ==
            PrayerAlertKind.adhanAnnouncement,
        'Adhan works without iqama settings');
    expect(
        activePrayerAlert(
                iqama.subtract(const Duration(seconds: 20)), [unset]) ==
            null,
        'No invented iqama wait');
  }
  final fridayNoon = DateTime(2026, 10, 16, 11, 50);
  for (final id in ['fajrSecond', 'dhuhr', 'asr', 'maghrib', 'isha']) {
    final friday = PrayerAlertEvent(
      prayerId: id,
      label: id,
      adhanAt: fridayNoon,
      iqamaMinutes: 15,
    );
    expect(
        activePrayerAlert(
                    fridayNoon.subtract(const Duration(seconds: 30)), [friday])
                ?.kind ==
            PrayerAlertKind.adhanCountdown,
        'Friday $id keeps adhan countdown');
    final beforeIqama =
        fridayNoon.add(const Duration(minutes: 14, seconds: 30));
    expect(
        (activePrayerAlert(beforeIqama, [friday])?.kind ==
                PrayerAlertKind.iqamaCountdown) ==
            (id != 'dhuhr'),
        'Only Friday Dhuhr skips iqama');
  }
  final late = PrayerAlertEvent(
    prayerId: 'isha',
    label: 'العشاء',
    adhanAt: DateTime(2026, 10, 15, 23, 50),
    iqamaMinutes: 15,
  );
  expect(
      activePrayerAlert(DateTime(2026, 10, 16, 0, 4, 30), [late])?.kind ==
          PrayerAlertKind.iqamaCountdown,
      'Isha iqama crosses midnight');
  final early = PrayerAlertEvent(
    prayerId: 'fajrSecond',
    label: 'الفجر الثاني',
    adhanAt: DateTime(2026, 10, 14, 0, 0, 10),
  );
  expect(
      activePrayerAlert(DateTime(2026, 10, 13, 23, 59, 40), [early])
              ?.secondsAt(DateTime(2026, 10, 13, 23, 59, 40)) ==
          30,
      'Next-day adhan pre-alert');
  expect(activePrayerAlert(noon, []) == null,
      'No schedule means no invented event');
  stdout.writeln(
      'Prayer alert windows, 30→0, 15-second announcement, Friday exception, '
      'midnight boundaries and clock resumption passed.');
}
