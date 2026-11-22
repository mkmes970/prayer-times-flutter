import 'dart:convert';
import 'dart:io';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/prayer_schedule.dart';

void main() {
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }
  final root = Platform.script.resolve('../');
  // Read the committed 12-hour source table, not the ignored download export.
  // Comparing it with the parsed region still checks every conversion to 24h.
  final source = jsonDecode(File.fromUri(root.resolve(
    'assets/data/shajara-prayer-times.json')).readAsStringSync());
  final region = regionFromScheduleFile(source);
  check(region.name == 'مواقيت الصلاة لقرية الشجرة', 'Exact region name');
  check(region.annualDays.length == 366, 'Complete annual table');
  final keys = {'fajr_second': 'fajrSecond', 'sunrise': 'sunrise', 'dhuhr': 'dhuhr',
    'asr': 'asr', 'maghrib': 'maghrib', 'isha': 'isha'};
  var comparisons = 0;
  for (final month in source['months']) {
    for (final day in month['days']) {
      final date = DateTime(2028, month['month'], day['day']);
      final times = region.timesFor(date)!;
      for (final entry in keys.entries) {
        final parts = (day[entry.key] as String).split(':').map(int.parse).toList();
        var expected = parts[0] * 60 + parts[1];
        if (['asr', 'maghrib', 'isha'].contains(entry.key)) expected += 720;
        // Region values are already normalized 24-hour strings; 12:xx is noon.
        final actualParts = times[entry.value]!.split(':').map(int.parse).toList();
        check(actualParts[0] * 60 + actualParts[1] == expected,
            '$date ${entry.key} source mismatch');
        comparisons++;
      }
      check(PrayerTimes.parseTimeMinutes(times['fajrSecond']!) -
          PrayerTimes.parseTimeMinutes(times['fajrFirst']!) == 15,
          '$date first Fajr gap');
    }
  }
  final existing = AppData.empty();
  final merged = existing.withAvailableRegions([region]);
  check(merged.selectedRegionId == existing.selectedRegionId, 'Existing selection changed');
  final selected = AppData(regions: merged.regions, selectedRegionId: region.id,
      settings: merged.settings);
  final restored = AppData.fromJson(jsonDecode(jsonEncode(selected.toJson())));
  check(restored.selectedRegion?.name == region.name, 'Saved selection lost');
  for (final year in [2026, 2027, 2028]) {
    check(restored.selectedRegion!.timesFor(DateTime(year, 3, 21))!['fajrSecond'] == '04:50',
        'Confirmed Fajr correction lost');
    check(restored.selectedRegion!.timesFor(DateTime(year, 3, 21))!['sunrise'] == '06:10',
        'Confirmed sunrise correction lost');
    check(restored.selectedRegion!.timesFor(DateTime(year, 4, 29))!['isha'] == '20:12',
        'Confirmed April 29 Isha lost');
    check(restored.selectedRegion!.timesFor(DateTime(year, 4, 30))!['isha'] == '20:13',
        'Confirmed April 30 Isha lost');
  }
  stdout.writeln('Shajara: $comparisons source cells, 366 first-Fajr intervals, corrections and saved selection passed.');
}
