import '../services/hijri_date.dart';
import 'prayer_schedule.dart';

class RamadanDay {
  const RamadanDay({
    required this.fajrSecondMinutes,
    required this.maghribMinutes,
  });
  final int fajrSecondMinutes;
  final int maghribMinutes;

  void validate() {
    if (fajrSecondMinutes < 30 ||
        fajrSecondMinutes >= 720 ||
        maghribMinutes < 720 ||
        maghribMinutes + 80 >= 1440) {
      throw const FormatException(
          'أدخل فجرًا صباحيًا ومغربًا مسائيًا صحيحين؛ لا تقبل الحقول الصفرية.');
    }
  }

  Map<String, Object?> toJson() => {
        'fajrSecondMinutes': fajrSecondMinutes,
        'maghribMinutes': maghribMinutes,
      };

  factory RamadanDay.fromJson(Object? value) {
    if (value is! Map ||
        value['fajrSecondMinutes'] is! int ||
        value['maghribMinutes'] is! int) {
      throw const FormatException('وقت غير صالح في الإمساكية.');
    }
    final day = RamadanDay(
      fajrSecondMinutes: value['fajrSecondMinutes'] as int,
      maghribMinutes: value['maghribMinutes'] as int,
    );
    day.validate();
    return day;
  }
}

class RamadanPlan {
  RamadanPlan(
      {required this.year,
      required this.custom,
      Map<int, RamadanDay> days = const {}})
      : days = Map.unmodifiable(days) {
    if (year < 1 ||
        (custom &&
            (days.length != 30 ||
                List.generate(30, (i) => i + 1)
                    .any((day) => !days.containsKey(day))))) {
      throw const FormatException(
          'أكمل الفجر الثاني والمغرب لجميع الأيام الثلاثين.');
    }
    for (final day in days.values) {
      day.validate();
    }
  }
  final int year;
  final bool custom;
  final Map<int, RamadanDay> days;

  bool expiredAt(HijriDate date) =>
      date.year > year || (date.year == year && date.month > 9);
  bool appliesAt(HijriDate date) => date.year == year && date.month == 9;

  Map<String, Object?> toJson() => {
        'year': year,
        'custom': custom,
        'days': {for (final e in days.entries) '${e.key}': e.value.toJson()},
      };
  factory RamadanPlan.fromJson(Object? value) {
    if (value is! Map ||
        value['year'] is! int ||
        value['custom'] is! bool ||
        value['days'] is! Map) {
      throw const FormatException('بيانات الإمساكية غير صالحة.');
    }
    return RamadanPlan(
        year: value['year'] as int,
        custom: value['custom'] as bool,
        days: {
          for (final e in (value['days'] as Map).entries)
            int.parse(e.key.toString()): RamadanDay.fromJson(e.value)
        });
  }
}

/// A read-time overlay: original region data is never rewritten or exported
/// with temporary Ramadan times. Annual schedules still resolve by civil date.
PrayerRegion regionWithRamadan(PrayerRegion source, RamadanPlan? plan,
        HijriDate Function(DateTime) hijriAt) =>
    plan == null || !plan.custom
        ? source
        : _RamadanRegion(source, plan, hijriAt);

class _RamadanRegion extends PrayerRegion {
  _RamadanRegion(this.source, this.plan, this.hijriAt)
      : super(
            id: source.id,
            name: source.name,
            days: source.days,
            annualDays: source.annualDays);
  final PrayerRegion source;
  final RamadanPlan plan;
  final HijriDate Function(DateTime) hijriAt;

  @override
  PrayerTimes? timesFor(DateTime date) {
    final original = source.timesFor(date);
    final hijri = hijriAt(date);
    if (original == null || !plan.appliesAt(hijri)) return original;
    final day = plan.days[hijri.day]!;
    return PrayerTimes({
      ...original.values,
      'fajrFirst': PrayerTimes.formatTime24(day.fajrSecondMinutes - 30),
      'fajrSecond': PrayerTimes.formatTime24(day.fajrSecondMinutes),
      'maghrib': PrayerTimes.formatTime24(day.maghribMinutes),
      'isha': PrayerTimes.formatTime24(day.maghribMinutes + 80),
    });
  }
}
