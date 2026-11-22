// Run without Flutter: dart mobile/prayer_times/test/bundled_schedule_smoke.dart
import 'dart:convert';
import 'dart:io';

import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/prayer_schedule.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final file = File.fromUri(
    Platform.script.resolve('../assets/data/hawd6-prayer-times.json'),
  );
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final region = regionFromScheduleFile(raw);
  check(region.name == 'مواقيت الصلاة لقرية حوض 6', 'Exact region name');
  check(region.annualDays.length == 366, 'All 366 source days are present');
  const sourceKeys = {
    'fajrFirst': 'fajr_first',
    'fajrSecond': 'fajr_second',
    'sunrise': 'sunrise',
    'dhuhr': 'dhuhr',
    'asr': 'asr',
    'maghrib': 'maghrib',
    'isha': 'isha',
  };
  var checks = 0;
  for (final month in raw['months'] as List) {
    for (final day in month['days'] as List) {
      for (final year in [2026, 2027, 2028]) {
        final date = DateTime(year, month['month'] as int, day['day'] as int);
        if (date.month != month['month']) continue; // Non-leap February.
        final times = region.timesFor(date);
        check(times != null, 'Missing schedule on $date');
        for (final field in sourceKeys.entries) {
          final source = (day[field.value] as String).split(':');
          final actual = times![field.key]!.split(':');
          check(
            int.parse(source[0]) % 12 == int.parse(actual[0]) % 12 &&
                source[1] == actual[1],
            '$date ${field.key} must preserve the uploaded 12-hour time',
          );
          checks++;
        }
        final first = PrayerTimes.parseTimeMinutes(times!['fajrFirst']!);
        final second = PrayerTimes.parseTimeMinutes(times['fajrSecond']!);
        check(second > first, 'First Fajr precedes second Fajr');
        if (date.month > 6) {
          check(second - first == 15, 'Uncorrected months keep the original Fajr interval');
        }
      }
    }
  }
  check(region.timesFor(DateTime(2026, 1, 1))!['asr'] == '14:47', 'Asr is PM');
  check(
    region.timesFor(DateTime(2026, 1, 1))!['dhuhr'] == '12:13',
    'Dhuhr noon',
  );
  check(region.timesFor(DateTime(2028, 2, 29)) != null, 'Leap-day schedule');
  check(region.timesFor(DateTime(2026, 12, 31)) != null, 'Year-end schedule');
  check(region.timesFor(DateTime(2027, 1, 1)) != null, 'Next-year schedule');

  final other = PrayerRegion(
    id: 'another-region',
    name: 'منطقة أخرى',
    days: {},
  );
  final saved = AppData(
    regions: {other.id: other},
    selectedRegionId: other.id,
    settings: const AppSettings(mosqueName: 'اسم المسجد المحفوظ'),
  ).withAvailableRegions([region]);
  check(saved.selectedRegionId == other.id, 'Do not change saved selection');
  check(saved.settings.mosqueName == 'اسم المسجد المحفوظ', 'Preserve settings');
  check(saved.regions.length == 2, 'Retain another region');

  final selected = AppData(
    regions: saved.regions,
    selectedRegionId: region.id,
    settings: saved.settings,
  );
  final restored = AppData.fromJson(jsonDecode(jsonEncode(selected.toJson())));
  check(
    restored.selectedRegion?.name == region.name,
    'Saved selection survives',
  );
  check(
    restored.selectedRegion!.annualDays.length == 366,
    'Backup keeps annual data',
  );
  check(
    restored.selectedRegion!.timesFor(DateTime(2027, 1, 1))!['isha'] == '18:25',
    'Restored table keeps PM interpretation',
  );
  final editDate = DateTime(2026, 10, 12);
  final override = PrayerTimes({
    ...region.timesFor(editDate)!.values,
    'asr': '15:30',
  });
  final edited = region.withDay(editDate, override).renamed('اسم جديد');
  check(
    edited.annualDays.length == 366,
    'Editing and renaming preserve annual table',
  );
  check(
    edited.timesFor(editDate)!['asr'] == '15:30',
    'Dated edit takes precedence',
  );
  check(
    edited.timesFor(DateTime(2027, 10, 12))!['asr'] ==
        region.timesFor(DateTime(2027, 10, 12))!['asr'],
    'Dated edit does not change the next year',
  );
  final editedRestored = PrayerRegion.fromJson(
    jsonDecode(jsonEncode(edited.toJson())),
  );
  check(
    editedRestored.timesFor(editDate)!['asr'] == '15:30',
    'Backup keeps edits',
  );
  check(
    editedRestored.annualDays.length == 366,
    'Backup keeps annual fallback',
  );
  stdout.writeln(
    'PASS: $checks time comparisons, annual lookup, region selection, '
    'settings preservation, backup/restore and dated overrides.',
  );
}
