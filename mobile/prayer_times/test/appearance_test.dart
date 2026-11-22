import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/main.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/services/bundled_schedules.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/appearance_screen.dart';
import 'package:prayer_times/ui/dashboard_screen.dart';
import 'package:prayer_times/ui/dua_ticker.dart';
import 'package:prayer_times/ui/hadith_panel.dart';
import 'package:prayer_times/ui/prayer_activity_screen.dart';
import 'package:prayer_times/ui/prayer_period_theme.dart';
import 'package:prayer_times/ui/settings_screen.dart';
import 'package:prayer_times/ui/theme_catalog.dart';

class _MemoryRepository extends LocalRepository {
  _MemoryRepository(this.data);
  AppData data;

  @override
  Future<AppData> load() async =>
      AppData.fromJson(jsonDecode(jsonEncode(data.toJson())));

  @override
  Future<void> save(AppData value) async =>
      data = AppData.fromJson(jsonDecode(jsonEncode(value.toJson())));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('36 distinct themes; any of them can be assigned to all six periods',
      () {
    expect(dashboardThemes.length, 36);
    expect(dashboardThemes.map((t) => t.id).toSet().length, 36);
    for (final period in PrayerPeriod.values) {
      final group = dashboardThemes.where((t) => t.sourcePeriod == period);
      expect(group.length, 6);
      expect(group.first.label, '${periodLabel(period)} 1');
      expect(group.last.label, '${periodLabel(period)} 6');
      for (final choice in dashboardThemes) {
        final settings = AppSettings.fromJson(const AppSettings().copyWith(
          customThemesEnabled: true,
          periodThemes: {period.name: choice.id},
        ).toJson());
        expect(themeForPeriod(period, settings).id, choice.id);
        final disabled = settings.copyWith(customThemesEnabled: false);
        expect(themeForPeriod(period, disabled).id, '${period.name}-0');
        expect(disabled.periodThemes[period.name], choice.id);
      }
    }
    expect(
      themeForPeriod(
        PrayerPeriod.fajr,
        const AppSettings(
            customThemesEnabled: true, periodThemes: {'fajr': 'invalid'}),
      ).id,
      'fajr-0',
    );
    expect(AppSettings.fromJson({}).customThemesEnabled, isFalse);
  });

  test('Every new background is bundled and originals remain code-rendered',
      () async {
    for (final theme in dashboardThemes) {
      final path = theme.backgroundAsset;
      if (path == null) {
        expect(theme.variant, 0);
      } else {
        final bytes = await rootBundle.load(path);
        expect(bytes.lengthInBytes, greaterThan(1000));
        // A compressed WebP image, not a screenshot or a network resource.
        expect(ascii.decode(bytes.buffer.asUint8List(0, 4)), 'RIFF');
      }
    }
  });

  testWidgets('Settings, draft preview, explicit save and reopened preferences',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = FontLoader('Amiri')
        ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
      await font.load();
    });
    final regions = (await tester.runAsync(loadBundledSchedules))!;
    final repository =
        _MemoryRepository(AppData.empty().withAvailableRegions(regions));
    final controller = PrayerController(repository: repository);
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await tester.runAsync(() async {
      await controller.selectRegion(regions.first.id);
      await controller.updateSettings(controller.settings.copyWith(
        mosqueName: 'مسجد التجربة',
        hadithEnabled: true,
      ));
    });
    final capture = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: capture,
      child: PrayerTimesApp(controller: controller),
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('إعدادات التطبيق').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(find.text('واجهة التطبيق'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(AppearanceScreen), findsOneWidget);
    expect(controller.settings.customThemesEnabled, isFalse);
    await tester.tap(find.byType(SwitchListTile));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(controller.settings.customThemesEnabled, isTrue);

    await tester.ensureVisible(find.text('العشاء'));
    await tester.tap(find.text('العشاء'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(ThemePickerScreen), findsOneWidget);
    await tester.tap(find.text('الفجر 5'));
    await tester.pump();
    expect(controller.settings.periodThemes.containsKey('isha'), isFalse);

    controller.clock.value = DateTime(2026, 10, 25, 6);
    await tester.tap(find.text('معاينة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    // The controller's periodic clock may have ticked during route animation.
    controller.clock.value = DateTime(2026, 10, 25, 6);
    await tester.pump();
    final preview =
        tester.widget<DashboardScreen>(find.byType(DashboardScreen));
    expect(preview.previewTheme?.id, 'fajr-4');
    expect(find.text('مسجد التجربة'), findsOneWidget);
    expect(find.text('6:00:00'), findsOneWidget);
    expect(find.byType(DuaTicker), findsOneWidget);
    expect(find.byType(HadithPanel), findsNothing);
    expect(find.byType(PrayerActivityScreen), findsNothing);
    expect(find.text('--:--'), findsNothing);
    expect(find.byTooltip('إعدادات التطبيق'), findsNothing);
    expect(controller.settings.periodThemes.containsKey('isha'), isFalse);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../../generated-artifacts/theme-live-preview.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    controller.clock.value = DateTime(2026, 10, 25, 6, 0, 1);
    await tester.pump();
    expect(find.text('6:00:01'), findsOneWidget);

    await tester.tap(find.byTooltip('الرجوع من المعاينة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('حفظ'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(repository.data.settings.periodThemes['isha'], 'fajr-4');
    expect(repository.data.selectedRegionId, regions.first.id);
    expect(repository.data.settings.mosqueName, 'مسجد التجربة');
    expect(repository.data.settings.hadithEnabled, isTrue);

    final reopened = PrayerController(repository: repository);
    await tester.runAsync(reopened.initialize);
    addTearDown(reopened.dispose);
    expect(reopened.settings.customThemesEnabled, isTrue);
    expect(reopened.settings.periodThemes['isha'], 'fajr-4');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Discarding a draft does not alter the saved theme',
      (tester) async {
    final regions = (await tester.runAsync(loadBundledSchedules))!;
    final repository = _MemoryRepository(AppData(
      regions: {for (final region in regions) region.id: region},
      selectedRegionId: '',
      settings: const AppSettings(
        customThemesEnabled: true,
        periodThemes: {'fajr': 'maghrib-3'},
      ),
    ));
    final controller = PrayerController(repository: repository);
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ThemePickerScreen(controller, PrayerPeriod.fajr),
    ));
    await tester.tap(find.text('الفجر 2'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.settings.periodThemes['fajr'], 'maghrib-3');
    expect(repository.data.settings.periodThemes['fajr'], 'maghrib-3');
  });
}
