import 'dart:convert';
import 'dart:io';

import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/prayer_schedule.dart';

void main() {
  final source = jsonDecode(File.fromUri(
    Platform.script.resolve('../assets/data/baggara-prayer-times.json'),
  ).readAsStringSync());
  final region = regionFromScheduleFile(source);
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  check(region.name == 'مواقيت الصلاة لقرية البگارة', 'Region name');
  check(region.annualDays.length == 366, 'All source days');
  for (var index = 0; index < 366; index++) {
    final day = DateTime(2028, 1, 1).add(Duration(days: index));
    final times = region.timesFor(day)!;
    final first = PrayerTimes.parseTimeMinutes(times['fajrFirst']!);
    final second = PrayerTimes.parseTimeMinutes(times['fajrSecond']!);
    check(second - first == 15, 'Fajr interval on $day');
  }
  check(region.timesFor(DateTime(2028, 10, 18))!['fajrSecond'] == '04:59',
      'User-confirmed Fajr');
  check(region.timesFor(DateTime(2028, 8, 31))!['isha'] == '19:55',
      'User-confirmed Isha');
  final selected = AppData(
    regions: {region.id: region},
    selectedRegionId: region.id,
    settings: const AppSettings(),
  );
  final restored = AppData.fromJson(jsonDecode(jsonEncode(selected.toJson())));
  check(restored.selectedRegion?.name == region.name, 'Selection persists');
  stdout.writeln('Baggara native schedule: 366 dates, Fajr interval and saved selection OK');
}
