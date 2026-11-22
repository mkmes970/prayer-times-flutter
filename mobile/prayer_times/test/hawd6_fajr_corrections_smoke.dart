import 'dart:convert';
import 'dart:io';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/models/hawd6_fajr_corrections.dart';

void main() {
  void check(bool value) {
    if (!value) throw StateError('Hawd 6 Fajr correction regression');
  }
  final source = regionFromScheduleFile(jsonDecode(
    File('assets/data/hawd6-prayer-times.json').readAsStringSync()));
  final oldAnnual = {
    for (final entry in source.annualDays.entries)
      entry.key: int.parse(entry.key.substring(0, 2)) > 6 ? entry.value :
        PrayerTimes({...entry.value.values,
          'fajrSecond': PrayerTimes.formatTime24(
            PrayerTimes.parseTimeMinutes(entry.value['fajrFirst']!) + 15),
        }),
  };
  final dated = {'2026-03-01': PrayerTimes({
    ...source.annualDays['03-01']!.values, 'fajrSecond': '05:17',
  })};
  final saved = PrayerRegion(id: source.id, name: 'اسم المسجد المحفوظ',
    days: dated, annualDays: oldAnnual);
  final data = AppData(regions: {saved.id: saved}, selectedRegionId: saved.id,
    settings: AppData.empty().settings);
  final merged = data.withAvailableRegions([source]);
  final corrected = merged.selectedRegion!;
  check(corrected.name == saved.name && identical(merged.settings, data.settings));
  check(identical(corrected.days, saved.days) ||
    jsonEncode(corrected.days.map((k, v) => MapEntry(k, v.values))) ==
      jsonEncode(saved.days.map((k, v) => MapEntry(k, v.values))));
  var count = 0;
  for (final entry in source.annualDays.entries) {
    check(jsonEncode(corrected.annualDays[entry.key]!.values) == jsonEncode(entry.value.values));
    if (saved.annualDays[entry.key]!['fajrSecond'] != entry.value['fajrSecond']) count++;
  }
  check(count == 143);
  check(corrected.timesFor(DateTime(2026, 3, 1))!['fajrSecond'] == '05:17');
  final custom = PrayerRegion(id: saved.id, name: saved.name, days: saved.days,
    annualDays: {...saved.annualDays, '03-01': dated.values.first});
  check(correctHawd6Fajr(custom, source).annualDays['03-01']!['fajrSecond'] == '05:17');
  check(identical(correctHawd6Fajr(corrected, source), corrected));
  final restored = AppData.fromJson(jsonDecode(jsonEncode(merged.toJson())));
  check(restored.selectedRegion!.annualDays['03-01']!['fajrSecond'] == '05:16');
  stdout.writeln('Native: 143 targeted corrections, all other times/settings retained, dated and custom edits preserved, backup round-trip passed.');
}
