import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/services/bundled_schedules.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/state/prayer_controller.dart';

class _MemoryRepository extends LocalRepository {
  _MemoryRepository(this.data);
  AppData data;

  @override
  Future<AppData> load() async => data;

  @override
  Future<void> save(AppData value) async => data = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Tal Ali has all source days and approved prayer intervals', () async {
    final regions = await loadBundledSchedules();
    final talAli = regions.singleWhere(
      (region) => region.name == 'مواقيت الصلاة لقرية تل علي',
    );
    expect(talAli.annualDays.length, 366);
    for (final times in talAli.annualDays.values) {
      int at(String slot) {
        final parts = times[slot]!.split(':').map(int.parse).toList();
        return parts[0] * 60 + parts[1];
      }
      expect(at('fajrSecond') - at('fajrFirst'), 20);
      expect(at('isha') - at('maghrib'), 80);
      final values = prayerSlots.map((slot) => at(slot.id)).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    }
    // Independent photographic checkpoints: first day of each month,
    // including noon vs. 11 AM and the afternoon 12-hour conversions.
    const checkpoints = [
      ['05:54', '07:14', '12:13', '14:50', '17:06'],
      ['05:46', '07:06', '12:23', '15:19', '17:36'],
      ['05:18', '06:38', '12:22', '15:38', '18:02'],
      ['04:36', '05:56', '12:14', '15:51', '18:30'],
      ['03:59', '05:19', '12:06', '15:55', '18:55'],
      ['03:36', '04:56', '12:07', '16:00', '19:19'],
      ['03:38', '04:58', '12:13', '16:06', '19:29'],
      ['03:56', '05:16', '12:15', '16:04', '19:12'],
      ['04:21', '05:41', '12:10', '15:48', '18:35'],
      ['04:44', '06:04', '11:59', '15:22', '17:53'],
      ['05:07', '06:27', '11:53', '14:53', '17:16'],
      ['05:36', '06:56', '11:59', '14:39', '16:56'],
    ];
    const slots = ['fajrSecond', 'sunrise', 'dhuhr', 'asr', 'maghrib'];
    for (var month = 1; month <= 12; month++) {
      for (final year in [2026, 2027, 2028]) {
        final times = talAli.timesFor(DateTime(year, month, 1))!;
        expect(
            slots.map((slot) => times[slot]).toList(), checkpoints[month - 1]);
      }
    }
    final leapDay = talAli.timesFor(DateTime(2028, 2, 29))!;
    expect(leapDay['fajrFirst'], '04:59');
    expect(leapDay['fajrSecond'], '05:19');
    expect(leapDay['maghrib'], '18:02');
    expect(leapDay['isha'], '19:22');
    // Preserve printed sunrise independently; do not impose a fixed interval.
    final july = talAli.timesFor(DateTime(2026, 7, 11))!;
    expect(july['fajrSecond'], '03:41');
    expect(july['sunrise'], '05:02');
  });

  test('Tal Ali can be selected and retained without losing existing regions',
      () async {
    final regions = await loadBundledSchedules();
    final talAli = regions.singleWhere(
      (region) => region.name == 'مواقيت الصلاة لقرية تل علي',
    );
    final old = AppData(
      regions: {regions.first.id: regions.first},
      selectedRegionId: regions.first.id,
      settings: AppData.empty().settings.copyWith(mosqueName: 'مسجد الاختبار'),
    );
    final merged = old.withAvailableRegions(regions);
    expect(merged.selectedRegionId, old.selectedRegionId);
    expect(merged.settings.mosqueName, 'مسجد الاختبار');
    expect(merged.regions.containsKey(talAli.id), isTrue);
    final repository = _MemoryRepository(merged);
    final controller = PrayerController(repository: repository);
    await controller.initialize();
    addTearDown(controller.dispose);
    await controller.selectRegion(talAli.id);
    repository.data =
        AppData.fromJson(jsonDecode(jsonEncode(repository.data.toJson())));
    final reopened = PrayerController(repository: repository);
    await reopened.initialize();
    addTearDown(reopened.dispose);
    expect(reopened.selectedRegionId, talAli.id);
    expect(reopened.regions.length, regions.length);
    expect(reopened.selectedRegion!.timesFor(DateTime(2028, 2, 29))!['isha'],
        '19:22');
    expect(reopened.settings.mosqueName, 'مسجد الاختبار');
  });
}
