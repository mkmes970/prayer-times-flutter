import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/services/date_format.dart';
import 'package:prayer_times/services/hijri_date.dart';

void main() {
  test('formats Hijri date with day, named/numeric month, and year', () {
    final date = HijriDate.fromGregorian(DateTime(2026, 10, 11));

    expect(date.arabicLabel, '29/ربيع الثاني (4)/1448');
  });

  test('formats Gregorian date in numeric day/month/year order', () {
    expect(formatGregorianDate(DateTime(2026, 10, 11)), '11/10/2026');
  });

  test('manual day/month correction continues into the following day', () {
    final corrected = HijriDate.fromGregorianWithManualDate(
      gregorian: DateTime(2026, 10, 11),
      referenceDate: DateTime(2026, 10, 11),
      day: 1,
      month: 5,
    );
    final nextDay = HijriDate.fromGregorianWithManualDate(
      gregorian: DateTime(2026, 10, 12),
      referenceDate: DateTime(2026, 10, 11),
      day: 1,
      month: 5,
    );

    expect(corrected.day, 1);
    expect(corrected.month, 5);
    expect(nextDay.day, 2);
    expect(nextDay.month, 5);
  });
}
