import 'dart:convert';
import 'dart:io';

import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/prayer_schedule.dart';

void check(bool result, String message) {
  if (!result) throw StateError(message);
}

String clock(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

int sourceMinutes(String value) {
  final parts = value.split(':').map(int.parse).toList();
  check(parts[0] >= 1 && parts[0] <= 12, 'Invalid source hour: $value');
  check(parts[1] >= 0 && parts[1] <= 59, 'Invalid source minute: $value');
  return parts[0] * 60 + parts[1];
}

void main() {
  final root = Platform.script.resolve('../');
  final raw = jsonDecode(
    File.fromUri(
      root.resolve('assets/data/numaysa-prayer-times.json'),
    ).readAsStringSync(),
  );
  final region = regionFromScheduleFile(raw);
  check(
      region.name == 'مواقيت الصلاة لقرية النميصة', 'Incorrect region title.');
  check(region.days.isEmpty, 'Do not invent a calendar year.');
  check(region.annualDays.length == 366, 'Incomplete annual schedule.');
  check((raw['months'] as List).length == 12, 'Expected twelve months.');

  final rows = File.fromUri(
    root.resolve('test/fixtures/numaysa-source.csv'),
  ).readAsLinesSync().skip(1).where((line) => line.trim().isNotEmpty);
  const columns = [
    'fajrSecond',
    'sunrise',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];
  final seen = <String>{};
  var comparisons = 0;
  for (final line in rows) {
    final cells = line.split(',');
    check(cells.length == 8, 'Invalid source row: $line');
    final month = int.parse(cells[0]);
    final day = int.parse(cells[1]);
    final key = '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
    check(seen.add(key), 'Duplicate source date: $key');
    final actual = region.timesFor(DateTime(2028, month, day));
    check(actual != null, 'Missing date: $key');
    final expected = <String, int>{};
    for (var index = 0; index < columns.length; index++) {
      final field = columns[index];
      final approved = field == 'fajrSecond' && key == '12-13'
          ? '5:47'
          : field == 'fajrSecond' && key == '05-03'
              ? '3:53'
              : cells[index + 2];
      final value = sourceMinutes(approved) + (index >= 3 ? 720 : 0);
      expected[field] = value;
      check(
        actual![field] == clock(value),
        '$key $field: expected ${clock(value)}, got ${actual[field]}',
      );
      comparisons++;
    }
    check(
      actual!['fajrFirst'] == clock(expected['fajrSecond']! - 15),
      '$key first Fajr must precede second Fajr by exactly 15 minutes.',
    );
    final values = [
      expected['fajrSecond']! - 15,
      for (final slot in columns) expected[slot]!,
    ];
    for (var index = 1; index < values.length; index++) {
      check(values[index] > values[index - 1], 'Invalid daily order at $key');
    }
  }
  check(seen.length == 366 && comparisons == 2196, 'Missing source cells.');
  check(
      region.annualDays['05-03']!['fajrSecond'] == '03:53', 'May correction.');
  check(region.annualDays['12-13']!['fajrSecond'] == '05:47',
      'December correction.');
  check(region.annualDays['02-29']!['maghrib'] == '18:02',
      'Leap-day source lost.');
  for (final year in [2026, 2027, 2028, 2030]) {
    check(
      region.timesFor(DateTime(year, 12, 13))!['fajrSecond'] == '05:47',
      'The annual schedule must recur in $year.',
    );
  }
  final restored = PrayerRegion.fromJson(
    jsonDecode(jsonEncode(region.toJson())),
  );
  check(
      restored.annualDays.length == 366, 'Backup round-trip lost annual data.');
  check(restored.annualDays['12-13']!['fajrFirst'] == '05:32',
      'Backup correction.');
  final fresh = AppData.empty().withAvailableRegions([region]);
  check(fresh.selectedRegion == null, 'Do not auto-select a region.');
  stdout.writeln(
    'Numaysa: 2196 source cells, 366 first-Fajr offsets, approved corrections, '
    'annual/leap-day lookup and backup round-trip passed.',
  );
}
