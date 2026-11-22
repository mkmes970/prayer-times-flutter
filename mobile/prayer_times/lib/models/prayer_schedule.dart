const prayerSlots = <PrayerSlot>[
  PrayerSlot('fajrFirst', 'الفجر الأول', false),
  PrayerSlot('fajrSecond', 'الفجر الثاني', true),
  PrayerSlot('sunrise', 'الشروق', false),
  PrayerSlot('dhuhr', 'الظهر', true),
  PrayerSlot('asr', 'العصر', true),
  PrayerSlot('maghrib', 'المغرب', true),
  PrayerSlot('isha', 'العشاء', true),
];

class PrayerSlot {
  const PrayerSlot(this.id, this.label, this.hasIqama);

  final String id;
  final String label;
  final bool hasIqama;
}

class PrayerTimes {
  PrayerTimes(Map<String, String> values) : values = Map.unmodifiable(values);

  final Map<String, String> values;

  String? operator [](String id) => values[id];

  Map<String, Object?> toJson() => {
    for (final entry in values.entries) entry.key: formatTime12(entry.value),
  };

  static PrayerTimes fromJson(Object? value, {String path = 'prayers'}) {
    if (value is! Map) {
      throw FormatException('$path يجب أن يكون كائنًا يحتوي أوقات الصلاة.');
    }
    final raw = Map<String, Object?>.from(value);
    final parsed = <String, String>{};
    var lastMinutes = -1;
    for (final slot in prayerSlots) {
      final time = raw[slot.id];
      if (time is! String) {
        throw FormatException(
          '$path.${slot.id}: أدخل الوقت بصيغة 12 ساعة مثل 4:35 AM أو 4:35 م.',
        );
      }
      final minutes = parseTimeMinutes(time, afterMinutes: lastMinutes);
      if (minutes <= lastMinutes) {
        throw FormatException(
          'ترتيب المواقيت غير صحيح عند ${slot.label}؛ راجع تسلسل اليوم من الفجر إلى العشاء.',
        );
      }
      parsed[slot.id] = formatTime24(minutes);
      lastMinutes = minutes;
    }
    return PrayerTimes(parsed);
  }

  static int parseTimeMinutes(String input, {int? afterMinutes}) {
    final match = RegExp(
      r'^(\d{1,2}):([0-5]\d)\s*(AM|PM|صباحاً|صباحا|مساءً|مساءا|ص|م)?$',
      caseSensitive: false,
    ).firstMatch(input.trim());
    if (match == null) {
      throw FormatException(
        'الوقت غير صحيح: $input. استخدم 4:35 AM أو 4:35 م.',
      );
    }
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final suffix = match.group(3)?.toLowerCase();
    if (hour > 23) {
      throw FormatException('الساعة غير صالحة: $input.');
    }
    if (suffix != null) {
      if (hour < 1 || hour > 12) {
        throw FormatException('ساعة 12 يجب أن تكون بين 1 و12: $input.');
      }
      final isPm = const {'pm', 'م', 'مساءً', 'مساءا'}.contains(suffix);
      final normalizedHour = hour % 12 + (isPm ? 12 : 0);
      return normalizedHour * 60 + minute;
    }

    if (hour == 0 || hour > 12) return hour * 60 + minute;

    final morning = (hour % 12) * 60 + minute;
    final evening = morning + 12 * 60;
    final candidates = [morning, evening];
    if (afterMinutes == null) return candidates.first;
    for (final candidate in candidates) {
      if (candidate > afterMinutes) return candidate;
    }
    throw FormatException(
      'ترتيب الوقت غير صحيح بعد ${formatTime24(afterMinutes)}: $input.',
    );
  }

  static String normalizeTime(String input) {
    final canonical = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
    if (canonical.hasMatch(input.trim())) return input.trim();
    return formatTime24(parseTimeMinutes(input));
  }

  static String formatTime12(String value) {
    final canonical = RegExp(
      r'^([01]\d|2[0-3]):([0-5]\d)$',
    ).firstMatch(value.trim());
    final minutes = canonical == null
        ? parseTimeMinutes(value)
        : int.parse(canonical.group(1)!) * 60 + int.parse(canonical.group(2)!);
    final hour24 = minutes ~/ 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour12:$minute ${hour24 < 12 ? 'AM' : 'PM'}';
  }

  static String formatTime24(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class PrayerRegion {
  PrayerRegion({
    required this.id,
    required this.name,
    required Map<String, PrayerTimes> days,
    Map<String, PrayerTimes> annualDays = const {},
  }) : days = Map.unmodifiable(days),
       annualDays = Map.unmodifiable(annualDays);

  final String id;
  final String name;
  final Map<String, PrayerTimes> days;
  final Map<String, PrayerTimes> annualDays;

  PrayerTimes? timesFor(DateTime date) =>
      days[dateKey(date)] ?? annualDays[dateKey(date).substring(5)];

  PrayerRegion withDay(DateTime date, PrayerTimes times) {
    return PrayerRegion(
      id: id,
      name: name,
      days: {...days, dateKey(date): times},
      annualDays: annualDays,
    );
  }

  PrayerRegion renamed(String value) =>
      PrayerRegion(id: id, name: value, days: days, annualDays: annualDays);

  Map<String, Object?> toJson() {
    final byYear = <int, Map<int, List<Map<String, Object?>>>>{};
    for (final entry in days.entries) {
      final date = DateTime.parse(entry.key);
      final months = byYear.putIfAbsent(date.year, () => {});
      final monthDays = months.putIfAbsent(date.month, () => []);
      monthDays.add({'day': date.day, 'prayers': entry.value.toJson()});
    }
    final years = byYear.keys.toList()..sort();
    return {
      'id': id,
      'name': name,
      if (annualDays.isNotEmpty)
        'annualMonths': [
          for (var month = 1; month <= 12; month++)
            {
              'month': month,
              'days': [
                for (
                  var day = 1;
                  day <= DateTime(2000, month + 1, 0).day;
                  day++
                )
                  if (annualDays.containsKey(
                    dateKey(DateTime(2000, month, day)).substring(5),
                  ))
                    {
                      'day': day,
                      'prayers':
                          annualDays[dateKey(
                                DateTime(2000, month, day),
                              ).substring(5)]!
                              .toJson(),
                    },
              ],
            },
        ],
      'years': years.map((year) {
        final monthMap = byYear[year]!;
        final months = monthMap.keys.toList()..sort();
        return {
          'year': year,
          'months': months.map((month) {
            final monthEntries = monthMap[month]!
              ..sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
            return {'month': month, 'days': monthEntries};
          }).toList(),
        };
      }).toList(),
    };
  }

  static PrayerRegion fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('بيانات المنطقة يجب أن تكون كائنًا.');
    }
    final map = Map<String, Object?>.from(value);
    final id = map['id'];
    final name = map['name'];
    final years = map['years'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('معرّف المنطقة غير موجود.');
    }
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('اسم المنطقة غير موجود.');
    }
    if (years is! List) {
      throw FormatException('years للمنطقة "$name" يجب أن تكون قائمة.');
    }
    final days = <String, PrayerTimes>{};
    for (final yearValue in years) {
      if (yearValue is! Map) {
        throw const FormatException('بيانات السنة يجب أن تكون كائنًا.');
      }
      final yearMap = Map<String, Object?>.from(yearValue);
      final year = yearMap['year'];
      final months = yearMap['months'];
      if (year is! int || year < 1 || year > 9999 || months is! List) {
        throw FormatException('بنية السنة غير صحيحة في المنطقة "$name".');
      }
      for (final monthValue in months) {
        if (monthValue is! Map) {
          throw const FormatException('بيانات الشهر يجب أن تكون كائنًا.');
        }
        final monthMap = Map<String, Object?>.from(monthValue);
        final month = monthMap['month'];
        final monthDays = monthMap['days'];
        if (month is! int || month < 1 || month > 12 || monthDays is! List) {
          throw FormatException('بنية الشهر غير صحيحة لسنة $year.');
        }
        for (final dayValue in monthDays) {
          if (dayValue is! Map) {
            throw const FormatException('بيانات اليوم يجب أن تكون كائنًا.');
          }
          final dayMap = Map<String, Object?>.from(dayValue);
          final day = dayMap['day'];
          if (day is! int) {
            throw FormatException('رقم اليوم غير صحيح في $year-$month.');
          }
          final date = DateTime(year, month, day);
          if (date.year != year || date.month != month || date.day != day) {
            throw FormatException('التاريخ غير صالح: $year-$month-$day.');
          }
          final key = dateKey(date);
          if (days.containsKey(key)) {
            throw FormatException('التاريخ $key مكرر في ملف المواقيت.');
          }
          days[key] = PrayerTimes.fromJson(
            dayMap['prayers'],
            path: 'regions/$id/$year/$month/$day/prayers',
          );
        }
      }
    }
    return PrayerRegion(
      id: id,
      name: name.trim(),
      days: days,
      annualDays: map.containsKey('annualMonths')
          ? _parseAnnualMonths(map['annualMonths'], sourceFields: false)
          : const {},
    );
  }

  /// A yearless table recurs by month/day; dated edits take precedence.
  static PrayerRegion fromAnnualJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('جدول المواقيت السنوي يجب أن يكون كائنًا.');
    }
    final name = value['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('اسم جدول المواقيت غير موجود.');
    }
    return PrayerRegion(
      id: createRegionId(name),
      name: name.trim(),
      days: const {},
      annualDays: _parseAnnualMonths(value['months'], sourceFields: true),
    );
  }

  static Map<String, PrayerTimes> _parseAnnualMonths(
    Object? value, {
    required bool sourceFields,
  }) {
    if (value is! List) {
      throw const FormatException('قائمة الأشهر السنوية غير صحيحة.');
    }
    const sourceKeys = {
      'fajrFirst': 'fajr_first',
      'fajrSecond': 'fajr_second',
      'sunrise': 'sunrise',
      'dhuhr': 'dhuhr',
      'asr': 'asr',
      'maghrib': 'maghrib',
      'isha': 'isha',
    };
    final days = <String, PrayerTimes>{};
    final seenMonths = <int>{};
    for (final rawMonth in value) {
      if (rawMonth is! Map ||
          rawMonth['month'] is! int ||
          rawMonth['days'] is! List) {
        throw const FormatException('بنية الشهر السنوي غير صحيحة.');
      }
      final month = rawMonth['month'] as int;
      if (month < 1 || month > 12 || !seenMonths.add(month)) {
        throw FormatException('الشهر $month غير صالح أو مكرر.');
      }
      for (final rawDay in rawMonth['days'] as List) {
        if (rawDay is! Map || rawDay['day'] is! int) {
          throw const FormatException('بنية اليوم السنوي غير صحيحة.');
        }
        final day = rawDay['day'] as int;
        final date = DateTime(2000, month, day);
        if (date.month != month || date.day != day) {
          throw FormatException('اليوم $day غير صالح في الشهر $month.');
        }
        final key = dateKey(date).substring(5);
        if (days.containsKey(key)) {
          throw FormatException('اليوم $key مكرر في الجدول السنوي.');
        }
        days[key] = PrayerTimes.fromJson(
          sourceFields
              ? {
                  for (final entry in sourceKeys.entries)
                    entry.key: rawDay[entry.value],
                }
              : rawDay['prayers'],
          path: 'annual/$key/prayers',
        );
      }
    }
    return days;
  }
}

String dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String createRegionId(String name) {
  final normalized = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty
      ? 'region-${DateTime.now().microsecondsSinceEpoch}'
      : normalized;
}
