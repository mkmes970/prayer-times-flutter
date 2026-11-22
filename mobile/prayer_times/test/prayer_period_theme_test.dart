import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/ui/prayer_period_theme.dart';

void main() {
  final times = PrayerTimes.fromJson({
    'fajrFirst': '04:20',
    'fajrSecond': '04:50',
    'sunrise': '06:10',
    'dhuhr': '11:56',
    'asr': '15:13',
    'maghrib': '17:39',
    'isha': '18:59',
  });

  test('selects six period palettes at inclusive schedule boundaries', () {
    expect(
      prayerPeriodAt(DateTime(2026, 1, 1, 4, 49), times),
      PrayerPeriod.isha,
    );
    expect(
      prayerPeriodAt(DateTime(2026, 1, 1, 4, 50), times),
      PrayerPeriod.fajr,
    );
    expect(
      prayerPeriodAt(DateTime(2026, 1, 1, 6, 10), times),
      PrayerPeriod.sunrise,
    );
    expect(
      prayerPeriodAt(DateTime(2026, 1, 1, 11, 56), times),
      PrayerPeriod.dhuhr,
    );
    expect(
      prayerPeriodAt(DateTime(2026, 1, 1, 15, 13), times),
      PrayerPeriod.asr,
    );
    expect(
      prayerPeriodAt(DateTime(2026, 1, 1, 17, 39), times),
      PrayerPeriod.maghrib,
    );
    expect(
      prayerPeriodAt(DateTime(2026, 1, 1, 18, 59), times),
      PrayerPeriod.isha,
    );
  });

  test('uses a stable daytime palette without a selected-day schedule', () {
    expect(prayerPeriodAt(DateTime(2026, 1, 1, 2), null), PrayerPeriod.dhuhr);
  });
}
