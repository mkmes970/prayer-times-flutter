import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
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

  test('fresh installs have bundled schedules but no selected region',
      () async {
    final regions = await loadBundledSchedules();
    final fresh = AppData.empty().withAvailableRegions(regions);
    expect(fresh.regions.length, regions.length);
    expect(fresh.selectedRegionId, isEmpty);
    expect(fresh.selectedRegion, isNull);

    // Saving unrelated settings or reopening must not pick the first region.
    final restored = AppData.fromJson(jsonDecode(jsonEncode(fresh.toJson())))
        .withAvailableRegions(regions);
    expect(restored.selectedRegionId, isEmpty);
    expect(restored.selectedRegion, isNull);

    final repo = _MemoryRepository(restored);
    final controller = PrayerController(repository: repo);
    await controller.initialize();
    addTearDown(controller.dispose);
    final now = DateTime(2026, 10, 19, 12);
    expect(controller.nextPrayerStatus(now).target, isNull);
    expect(controller.currentIqamaStatus(now), isNull);
    expect(controller.activePrayerScreen(now), isNull);
    expect(controller.highlightedPrayerId(now), isNull);

    final chosen = regions.last;
    await controller.selectRegion(chosen.id);
    expect(controller.selectedRegionId, chosen.id);
    expect(controller.nextPrayerStatus(now).target, isNotNull);
    repo.data = AppData.fromJson(jsonDecode(jsonEncode(repo.data.toJson())));
    final reopened = PrayerController(repository: repo);
    await reopened.initialize();
    addTearDown(reopened.dispose);
    expect(reopened.selectedRegionId, chosen.id);
    expect(reopened.selectedRegion!.timesFor(now), isNotNull);
  });

  test('bundled asset is available with the exact regional name', () async {
    final regions = await loadBundledSchedules();
    expect(regions.map((region) => region.name), [
      'مواقيت الصلاة لقرية حوض 6',
      'مواقيت الصلاة لمنطقة العباسي',
      'مواقيت الصلاة لقرية ذويب',
      'مواقيت الصلاة لقضاء الحويجة وضواحيها',
      'مواقيت الصلاة لمدينة تكريت وضواحيها',
      'مواقيت الصلاة لقرية البگارة',
      'مواقيت الصلاة لقرية الشجرة',
      'مواقيت الصلاة في العلم',
      'مواقيت الصلاة لقرية النميصة',
      'مواقيت الصلاة لقرية تل علي',
      'مواقيت الصلاة لناحية الزاب وضواحيها',
      'مواقيت الصلاة لقرية تل الذهب',
    ]);
    expect(
        regions.map((region) => region.id).toSet(), hasLength(regions.length));
    for (final region in regions) {
      expect(region.annualDays.length, 366);
    }
  });

  test('Tal al-Dhahab is selectable with the approved annual schedule',
      () async {
    final regions = await loadBundledSchedules();
    final talAlDhahab = regions.singleWhere(
      (region) => region.name == 'مواقيت الصلاة لقرية تل الذهب',
    );
    expect(talAlDhahab.annualDays.length, 366);
    final january = talAlDhahab.timesFor(DateTime(2027, 1, 1))!;
    expect(january['fajrFirst'], '05:39');
    expect(january['fajrSecond'], '05:54');
    expect(january['sunrise'], '07:14');
    expect(january['dhuhr'], '12:16');
    expect(january['asr'], '14:49');
    expect(january['maghrib'], '17:10');
    expect(january['isha'], '18:30');
    expect(talAlDhahab.timesFor(DateTime(2028, 2, 29)), isNotNull);

    final repository = _MemoryRepository(
      AppData(
        regions: {for (final region in regions) region.id: region},
        selectedRegionId: regions.first.id,
        settings: AppData.empty().settings,
      ),
    );
    final controller = PrayerController(repository: repository);
    await controller.initialize();
    addTearDown(controller.dispose);
    await controller.selectRegion(talAlDhahab.id);
    expect(controller.selectedRegion?.name, 'مواقيت الصلاة لقرية تل الذهب');
    expect(controller.selectedRegionId, talAlDhahab.id);
    final reopened = PrayerController(repository: repository);
    await reopened.initialize();
    addTearDown(reopened.dispose);
    expect(reopened.selectedRegion?.name, 'مواقيت الصلاة لقرية تل الذهب');
    expect(
      reopened.selectedRegion!.timesFor(DateTime(2028, 2, 29))!['isha'],
      '19:21',
    );
  });

  test(
    'Abbasi is selectable and saved alongside the existing region',
    () async {
      final regions = await loadBundledSchedules();
      final hawd = regions.first;
      final abbasi = regions.firstWhere(
        (region) => region.name == 'مواقيت الصلاة لمنطقة العباسي',
      );
      final oldData = AppData(
        regions: {hawd.id: hawd},
        selectedRegionId: hawd.id,
        settings: AppData.empty().settings,
      );
      final repo = _MemoryRepository(oldData.withAvailableRegions(regions));
      final controller = PrayerController(repository: repo);
      await controller.initialize();
      addTearDown(controller.dispose);
      expect(controller.selectedRegionId, hawd.id);
      await controller.selectRegion(abbasi.id);
      expect(controller.selectedRegion?.name, 'مواقيت الصلاة لمنطقة العباسي');
      expect(
        controller.selectedRegion!.timesFor(
          DateTime(2026, 1, 1),
        )!['fajrSecond'],
        '05:54',
      );
      expect(
        controller.selectedRegion!.timesFor(DateTime(2026, 1, 1))!['asr'],
        '14:50',
      );
      repo.data = AppData.fromJson(jsonDecode(jsonEncode(repo.data.toJson())));
      final reopened = PrayerController(repository: repo);
      await reopened.initialize();
      addTearDown(reopened.dispose);
      expect(reopened.selectedRegionId, abbasi.id);
      expect(reopened.regions.containsKey(hawd.id), isTrue);
      expect(
        reopened.selectedRegion!.timesFor(DateTime(2028, 2, 29)),
        isNotNull,
      );
    },
  );

  test('Dhuwaib selection retains corrected times after reopening', () async {
    final regions = await loadBundledSchedules();
    final dhuwaib = regions.firstWhere(
      (region) => region.name == 'مواقيت الصلاة لقرية ذويب',
    );
    final repo = _MemoryRepository(
      AppData(
        regions: {for (final region in regions) region.id: region},
        selectedRegionId: regions.first.id,
        settings: AppData.empty().settings,
      ),
    );
    final controller = PrayerController(repository: repo);
    await controller.initialize();
    addTearDown(controller.dispose);
    await controller.selectRegion(dhuwaib.id);
    repo.data = AppData.fromJson(jsonDecode(jsonEncode(repo.data.toJson())));
    final reopened = PrayerController(repository: repo);
    await reopened.initialize();
    addTearDown(reopened.dispose);
    expect(reopened.selectedRegionId, dhuwaib.id);
    expect(reopened.selectedRegion?.name, 'مواقيت الصلاة لقرية ذويب');
    expect(reopened.regions.length, regions.length);
    expect(
      reopened.selectedRegion!.timesFor(DateTime(2026, 1, 9))!['asr'],
      '15:00',
    );
    final july = reopened.selectedRegion!.timesFor(DateTime(2026, 7, 16))!;
    expect(july['fajrFirst'], '03:28');
    expect(july['fajrSecond'], '03:43');
    expect(
      reopened.selectedRegion!.timesFor(DateTime(2026, 12, 16))!['asr'],
      '14:42',
    );
  });

  test('Numaysa is added without replacing selection or existing settings',
      () async {
    final regions = await loadBundledSchedules();
    final numaysa = regions.singleWhere(
      (region) => region.name == 'مواقيت الصلاة لقرية النميصة',
    );
    final oldRegion = regions.first;
    final oldSettings =
        AppData.empty().settings.copyWith(mosqueName: 'مسجد الاختبار');
    // Native and web repositories merge bundled regions during load.
    final repository = _MemoryRepository(
      AppData(
        regions: {oldRegion.id: oldRegion},
        selectedRegionId: oldRegion.id,
        settings: oldSettings,
      ).withAvailableRegions(regions),
    );
    final controller = PrayerController(repository: repository);
    await controller.initialize();
    addTearDown(controller.dispose);
    expect(controller.selectedRegionId, oldRegion.id);
    expect(controller.regions.containsKey(numaysa.id), isTrue);
    expect(controller.settings.mosqueName, 'مسجد الاختبار');
    await controller.selectRegion(numaysa.id);
    repository.data =
        AppData.fromJson(jsonDecode(jsonEncode(repository.data.toJson())));
    final reopened = PrayerController(repository: repository);
    await reopened.initialize();
    addTearDown(reopened.dispose);
    expect(reopened.selectedRegion?.name, 'مواقيت الصلاة لقرية النميصة');
    expect(reopened.regions.length, regions.length);
    expect(reopened.settings.mosqueName, 'مسجد الاختبار');
    final december = reopened.selectedRegion!.timesFor(DateTime(2027, 12, 13))!;
    expect(december['fajrFirst'], '05:32');
    expect(december['fajrSecond'], '05:47');
    final may = reopened.selectedRegion!.timesFor(DateTime(2027, 5, 3))!;
    expect(may['fajrFirst'], '03:38');
    expect(may['fajrSecond'], '03:53');
    expect(
      reopened.selectedRegion!.timesFor(DateTime(2028, 2, 29))!['maghrib'],
      '18:02',
    );
  });

  test(
    'selecting and saving the region changes and retains dashboard times',
    () async {
      final region = regionFromScheduleFile(
        jsonDecode(
          File('assets/data/hawd6-prayer-times.json').readAsStringSync(),
        ),
      );
      final repo = _MemoryRepository(
        AppData.empty().withAvailableRegions([region]),
      );
      final controller = PrayerController(repository: repo);
      await controller.initialize();
      addTearDown(controller.dispose);
      expect(controller.regions.containsKey(region.id), isTrue);
      await controller.selectRegion(region.id);
      expect(controller.selectedRegion?.name, 'مواقيت الصلاة لقرية حوض 6');
      expect(
        controller.selectedRegion!.timesFor(
          DateTime(2026, 1, 1),
        )!['fajrSecond'],
        '05:58',
      );
      final reopened = PrayerController(repository: repo);
      await reopened.initialize();
      addTearDown(reopened.dispose);
      expect(reopened.selectedRegionId, region.id);
      expect(
        reopened.selectedRegion!.timesFor(DateTime(2027, 1, 1))!['isha'],
        '18:25',
      );
    },
  );
}
