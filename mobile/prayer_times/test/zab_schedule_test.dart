import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/services/bundled_schedules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Zab contains 366 days and all approved intervals and corrections',
      () async {
    final regions = await loadBundledSchedules();
    final zab = regions.singleWhere(
      (region) => region.name == 'مواقيت الصلاة لناحية الزاب وضواحيها',
    );
    expect(zab.annualDays.length, 366);
    for (final times in zab.annualDays.values) {
      int at(String slot) {
        final parts = times[slot]!.split(':').map(int.parse).toList();
        return parts[0] * 60 + parts[1];
      }

      expect(at('fajrSecond') - at('fajrFirst'), 15);
      expect(at('sunrise') - at('fajrSecond'), 80);
      expect(at('isha') - at('maghrib'), 80);
      final values = prayerSlots.map((slot) => at(slot.id)).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    }
    // Independent photographic checkpoints, ordered by month:
    // second Fajr, Dhuhr, Asr and Maghrib.
    const checkpoints = [
      ['05:59', '12:15', '14:49', '17:05'],
      ['05:49', '12:24', '15:15', '17:35'],
      ['05:21', '12:24', '15:37', '18:02'],
      ['04:38', '12:15', '15:49', '18:27'],
      ['04:00', '12:08', '15:54', '18:53'],
      ['03:39', '12:09', '15:59', '19:16'],
      ['03:41', '12:15', '16:05', '19:25'],
      ['04:00', '12:17', '16:05', '19:10'],
      ['04:23', '12:11', '15:50', '18:34'],
      ['04:45', '12:01', '15:22', '17:51'],
      ['05:11', '11:54', '14:52', '17:12'],
      ['05:40', '12:00', '14:38', '16:55'],
    ];
    const slots = ['fajrSecond', 'dhuhr', 'asr', 'maghrib'];
    for (var month = 1; month <= 12; month++) {
      for (final year in [2026, 2027, 2028]) {
        final times = zab.timesFor(DateTime(year, month, 1))!;
        expect(
            slots.map((slot) => times[slot]).toList(), checkpoints[month - 1]);
      }
    }
    expect(zab.timesFor(DateTime(2028, 2, 29))!['fajrSecond'], '05:22');
    expect(zab.timesFor(DateTime(2026, 1, 3))!['dhuhr'], '12:16');
    expect(zab.timesFor(DateTime(2026, 1, 29))!['asr'], '15:13');
    expect(zab.timesFor(DateTime(2026, 7, 19))!['fajrSecond'], '03:51');
    expect(zab.timesFor(DateTime(2026, 7, 19))!['sunrise'], '05:11');
    expect(zab.timesFor(DateTime(2026, 12, 5))!['maghrib'], '16:54');
    expect(zab.timesFor(DateTime(2026, 12, 5))!['isha'], '18:14');
    expect(zab.timesFor(DateTime(2026, 12, 7))!['asr'], '14:28');
    expect(zab.timesFor(DateTime(2026, 3, 31))!['fajrFirst'], '04:24');
    expect(zab.timesFor(DateTime(2026, 3, 31))!['sunrise'], '05:59');
    const correctedIsha = {
      '03-08': '19:28',
      '03-10': '19:29',
      '03-11': '19:31',
      '03-12': '19:32',
      '03-13': '19:33',
      '03-14': '19:33',
      '03-15': '19:34',
      '03-16': '19:35',
      '03-17': '19:36',
      '03-18': '19:37',
      '03-20': '19:38',
      '07-06': '20:44',
      '08-31': '19:56',
      '11-06': '18:28',
    };
    for (final entry in correctedIsha.entries) {
      final date = DateTime.parse('2026-${entry.key}');
      expect(zab.timesFor(date)!['isha'], entry.value);
    }
  });

  test('Adding Zab preserves saved regions, edits and selection', () async {
    final regions = await loadBundledSchedules();
    final zab = regions.singleWhere(
      (region) => region.name == 'مواقيت الصلاة لناحية الزاب وضواحيها',
    );
    final previous = AppData(
      regions: {
        for (final region in regions.where((r) => r.id != zab.id))
          region.id: region,
      },
      selectedRegionId: regions.first.id,
      settings: AppData.empty().settings.copyWith(mosqueName: 'مسجد الاختبار'),
    );
    final merged = previous.withAvailableRegions(regions);
    expect(merged.regions.length, previous.regions.length + 1);
    expect(merged.selectedRegionId, previous.selectedRegionId);
    expect(merged.settings.mosqueName, previous.settings.mosqueName);
    for (final old in previous.regions.entries) {
      expect(merged.regions[old.key]!.toJson(), old.value.toJson());
    }
    final selected = AppData(
      regions: merged.regions,
      selectedRegionId: zab.id,
      settings: merged.settings,
    );
    final reopened = AppData.fromJson(jsonDecode(jsonEncode(selected.toJson())))
        .withAvailableRegions(regions);
    expect(reopened.selectedRegionId, zab.id);
    expect(reopened.regions[zab.id]!.timesFor(DateTime(2026, 12, 7))!['asr'],
        '14:28');
  });
}
