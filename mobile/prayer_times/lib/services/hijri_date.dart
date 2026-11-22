HijriDate adjustedHijriDate(
  DateTime date, {
  int? manualDay,
  int? manualMonth,
  String? anchorDate,
  int offsetDays = 0,
}) {
  if (manualDay != null && manualMonth != null && anchorDate != null) {
    try {
      return HijriDate.fromGregorianWithManualDate(
          gregorian: date,
          referenceDate: DateTime.parse(anchorDate),
          day: manualDay,
          month: manualMonth);
    } on FormatException {
      // Fall back for an invalid legacy manual anchor.
    }
  }
  return HijriDate.fromGregorian(date.add(Duration(days: offsetDays)));
}

const hijriMonthNames = <String>[
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الثاني',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

class HijriDate {
  const HijriDate(this.day, this.month, this.year);

  final int day;
  final int month;
  final int year;

  String get arabicLabel => '$day/${hijriMonthNames[month - 1]} ($month)/$year';

  static int daysInMonth(int year, int month) {
    if (month < 1 || month > 12) {
      throw RangeError.range(month, 1, 12, 'month');
    }
    final nextMonth = month == 12
        ? _islamicToJulianDay(year + 1, 1)
        : _islamicToJulianDay(year, month + 1);
    return nextMonth - _islamicToJulianDay(year, month);
  }

  /// Local tabular Islamic calendar; local moon sighting can differ by a day.
  static HijriDate fromGregorian(DateTime gregorian) {
    final date = DateTime.utc(gregorian.year, gregorian.month, gregorian.day);
    final julianDay =
        date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay + 2440588;
    const epoch = 1948440;
    final year = ((30 * (julianDay - epoch) + 10646) / 10631).floor();
    var month = ((julianDay - 29 - _islamicToJulianDay(year, 1)) / 29.5)
        .ceil()
        .clamp(1, 12)
        .toInt();
    while (month > 1 && _islamicToJulianDay(year, month) > julianDay) {
      month--;
    }
    while (month < 12 && _islamicToJulianDay(year, month + 1) <= julianDay) {
      month++;
    }
    final day = julianDay - _islamicToJulianDay(year, month) + 1;
    return HijriDate(day, month, year);
  }

  /// Applies a day/month correction from one Gregorian date onward.
  ///
  /// The selected Hijri date is anchored to [referenceDate]. Later dates
  /// continue naturally through month and year boundaries.
  static HijriDate fromGregorianWithManualDate({
    required DateTime gregorian,
    required DateTime referenceDate,
    required int day,
    required int month,
  }) {
    final calculatedAtReference = fromGregorian(referenceDate);
    final baseSerial = _islamicToJulianDay(
          calculatedAtReference.year,
          calculatedAtReference.month,
        ) +
        calculatedAtReference.day -
        1;

    int? selectedSerial;
    var closestDifference = 1 << 30;
    for (final year in [
      calculatedAtReference.year - 1,
      calculatedAtReference.year,
      calculatedAtReference.year + 1,
    ]) {
      if (year < 1 || day < 1 || day > daysInMonth(year, month)) continue;
      final serial = _islamicToJulianDay(year, month) + day - 1;
      final difference = (serial - baseSerial).abs();
      if (difference < closestDifference) {
        closestDifference = difference;
        selectedSerial = serial;
      }
    }
    if (selectedSerial == null) {
      throw FormatException('اليوم $day غير صالح في الشهر الهجري المحدد.');
    }
    final correctionDays = selectedSerial - baseSerial;
    return fromGregorian(gregorian.add(Duration(days: correctionDays)));
  }

  static int _islamicToJulianDay(int year, int month) {
    final elapsedMonths = (month - 1);
    final elapsedDays = ((59 * elapsedMonths + 1) ~/ 2);
    final leapDays = ((3 + 11 * year) ~/ 30);
    return 1948440 + elapsedDays + 354 * (year - 1) + leapDays - 1;
  }
}
