import 'dart:convert';
import 'dart:io';

import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/prayer_schedule.dart';

void check(bool result, String message) {
  if (!result) throw StateError(message);
}

void main() {
  final root = Platform.script.resolve('../');
  final catalogue = File.fromUri(
    root.resolve('lib/services/bundled_schedules.dart'),
  ).readAsStringSync();
  final manifest = File.fromUri(
    root.resolve('pubspec.yaml'),
  ).readAsStringSync();
  final paths = RegExp(
    r"'(assets/data/[^']+\.json)'",
  ).allMatches(catalogue).map((match) => match.group(1)!).toList();
  check(paths.length == 12, 'All twelve approved regions must be registered.');
  final regions = paths.map((path) {
    check(manifest.contains('    - $path'), 'Missing Flutter asset: $path');
    return regionFromScheduleFile(
      jsonDecode(File.fromUri(root.resolve(path)).readAsStringSync()),
    );
  }).toList();
  check(
    regions.map((region) => region.id).toSet().length == paths.length,
    'Duplicate IDs.',
  );
  final talAlDhahab = regions.singleWhere(
    (region) => region.name == 'مواقيت الصلاة لقرية تل الذهب',
  );
  check(
      talAlDhahab.annualDays.length == 366, 'Incomplete Tal al-Dhahab table.');
  final talAlDhahabRestored = AppData.fromJson(jsonDecode(jsonEncode(AppData(
    regions: {for (final region in regions) region.id: region},
    selectedRegionId: talAlDhahab.id,
    settings: AppData.empty().settings,
  ).toJson())));
  check(talAlDhahabRestored.selectedRegionId == talAlDhahab.id,
      'Tal al-Dhahab selection lost after reload.');
  for (final year in [2026, 2027, 2028]) {
    final region = talAlDhahabRestored.selectedRegion!;
    final january = region.timesFor(DateTime(year, 1, 1))!;
    check(january['fajrFirst'] == '05:39', 'Tal al-Dhahab first Fajr changed.');
    check(january['asr'] == '14:49', 'Tal al-Dhahab afternoon time changed.');
    check(region.timesFor(DateTime(year, 12, 31)) != null,
        'Tal al-Dhahab year-end lookup missing.');
  }
  check(
    talAlDhahabRestored.selectedRegion!
            .timesFor(DateTime(2028, 2, 29))!['isha'] ==
        '19:21',
    'Tal al-Dhahab leap day changed.',
  );
  final hawd = regions.first;
  final abbasi = regions[1];
  final dhuwaib = regions[2];
  final hawija = regions[3];
  check(hawija.name == 'مواقيت الصلاة لقضاء الحويجة وضواحيها',
      'Wrong Hawija name.');
  check(hawija.annualDays.length == 366, 'Incomplete Hawija table.');
  check(hawd.name == 'مواقيت الصلاة لقرية حوض 6', 'Existing name changed.');
  check(
    abbasi.name == 'مواقيت الصلاة لمنطقة العباسي',
    'Wrong new region name.',
  );
  check(abbasi.annualDays.length == 366, 'Incomplete Abbasi table.');
  check(dhuwaib.name == 'مواقيت الصلاة لقرية ذويب', 'Wrong Dhuwaib name.');
  check(dhuwaib.annualDays.length == 366, 'Incomplete Dhuwaib table.');
  final oldData = AppData(
    regions: {hawd.id: hawd, abbasi.id: abbasi},
    selectedRegionId: abbasi.id,
    settings: AppData.empty().settings,
  );
  final merged = oldData.withAvailableRegions(regions);
  check(merged.selectedRegionId == abbasi.id, 'Saved selection was replaced.');
  check(
    identical(merged.settings, oldData.settings),
    'Saved settings changed.',
  );
  final selected = AppData(
    regions: merged.regions,
    selectedRegionId: abbasi.id,
    settings: merged.settings,
  );
  final restored = AppData.fromJson(jsonDecode(jsonEncode(selected.toJson())));
  check(restored.selectedRegionId == abbasi.id, 'Selection was not retained.');
  check(restored.regions.containsKey(hawd.id), 'Existing region was lost.');
  for (final year in [2026, 2027, 2028]) {
    final times = restored.selectedRegion!.timesFor(DateTime(year, 1, 1))!;
    check(times['fajrSecond'] == '05:54', 'Incorrect Abbasi morning time.');
    check(times['asr'] == '14:50', 'Incorrect Abbasi afternoon time.');
  }
  check(
    restored.selectedRegion!.timesFor(DateTime(2028, 2, 29)) != null,
    'Leap day was lost.',
  );
  final dhuwaibSelected = AppData(
    regions: merged.regions,
    selectedRegionId: dhuwaib.id,
    settings: merged.settings,
  );
  final reopened = AppData.fromJson(
    jsonDecode(jsonEncode(dhuwaibSelected.toJson())),
  );
  check(reopened.selectedRegionId == dhuwaib.id, 'Dhuwaib selection lost.');
  check(reopened.regions.length == regions.length,
      'An existing region was lost.');
  for (final year in [2026, 2027, 2028]) {
    final region = reopened.selectedRegion!;
    check(
      region.timesFor(DateTime(year, 1, 9))!['asr'] == '15:00',
      'January Asr correction lost.',
    );
    final july = region.timesFor(DateTime(year, 7, 16))!;
    check(july['fajrFirst'] == '03:28', 'First Fajr correction lost.');
    check(july['fajrSecond'] == '03:43', 'Second Fajr correction lost.');
    check(
      PrayerTimes.formatTime12(july['fajrSecond']!) == '3:43 AM',
      'Incorrect 12-hour display.',
    );
    check(
      region.timesFor(DateTime(year, 12, 16))!['asr'] == '14:42',
      'December Asr correction lost.',
    );
    check(region.timesFor(DateTime(year, 12, 31)) != null, 'Year end lost.');
    check(region.timesFor(DateTime(year + 1, 1, 1)) != null, 'Next year lost.');
  }
  check(
    reopened.selectedRegion!.timesFor(DateTime(2028, 2, 29)) != null,
    'Dhuwaib leap day was lost.',
  );
  final hawijaRestored = AppData.fromJson(jsonDecode(jsonEncode(AppData(
    regions: merged.regions,
    selectedRegionId: hawija.id,
    settings: merged.settings,
  ).toJson())));
  check(hawijaRestored.selectedRegionId == hawija.id, 'Hawija selection lost.');
  for (final year in [2026, 2027, 2028]) {
    final region = hawijaRestored.selectedRegion!;
    check(region.timesFor(DateTime(year, 6, 28))!['dhuhr'] == '12:13',
        'Hawija June correction lost.');
    check(region.timesFor(DateTime(year, 8, 18))!['isha'] == '20:15',
        'Hawija August correction lost.');
    check(region.timesFor(DateTime(year, 11, 24))!['fajrSecond'] == '05:30',
        'Hawija November 24 changed.');
    check(region.timesFor(DateTime(year, 11, 25))!['fajrSecond'] == '05:31',
        'Hawija November 25 changed.');
    check(region.timesFor(DateTime(year, 2, 19))!['sunrise'] == '06:52',
        'Approved February time changed.');
    check(region.timesFor(DateTime(year, 4, 4))!['maghrib'] == '18:32',
        'Approved April time changed.');
  }
  check(hawijaRestored.selectedRegion!.timesFor(DateTime(2028, 2, 29)) != null,
      'Hawija leap day lost.');
  stdout.writeln(
    'PASS: ${regions.length} packaged regions, preserved settings/selection, '
    'Abbasi and Dhuwaib selection backup roundtrips, corrected times, '
    '12-hour display, annual and leap-day lookup.',
  );
  final tikrit = regions[4];
  check(tikrit.name == 'مواقيت الصلاة لمدينة تكريت وضواحيها',
      'Incorrect Tikrit name.');
  check(tikrit.annualDays.length == 366, 'Incomplete Tikrit schedule.');
  final tikritRestored = AppData.fromJson(jsonDecode(jsonEncode(AppData(
    regions: merged.regions,
    selectedRegionId: tikrit.id,
    settings: merged.settings,
  ).toJson())));
  check(tikritRestored.selectedRegionId == tikrit.id,
      'Tikrit selection lost after reload.');
  final leapDay =
      tikritRestored.selectedRegion!.timesFor(DateTime(2028, 2, 29))!;
  final previousDay =
      tikritRestored.selectedRegion!.timesFor(DateTime(2028, 2, 28))!;
  for (final key in previousDay.values.keys) {
    check(leapDay[key] == previousDay[key],
        'Tikrit February 29 must match February 28.');
  }
  check(leapDay['fajrFirst'] == '04:57', 'Incorrect Tikrit first Fajr.');
  check(leapDay['fajrSecond'] == '05:12', 'Incorrect Tikrit second Fajr.');
  check(leapDay['asr'] == '15:35', 'Incorrect Tikrit afternoon conversion.');
  for (final year in [2026, 2027, 2028]) {
    final region = tikritRestored.selectedRegion!;
    check(region.timesFor(DateTime(year, 10, 14))!['dhuhr'] == '11:56',
        'Tikrit annual lookup changed.');
    check(region.timesFor(DateTime(year, 12, 31)) != null,
        'Tikrit year-end lookup missing.');
    check(region.timesFor(DateTime(year + 1, 1, 1)) != null,
        'Tikrit next-year lookup missing.');
  }
  stdout.writeln(
      'PASS: Tikrit exact name, saved selection, annual times, and copied leap day.');
}
