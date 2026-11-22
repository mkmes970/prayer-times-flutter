import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/main.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/dua_ticker.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/services/bundled_schedules.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/ui/settings_screen.dart';

class _MemoryRepository extends LocalRepository {
  _MemoryRepository(this.data);
  AppData data;

  @override
  Future<AppData> load() async => data;

  @override
  Future<void> save(AppData value) async => data = value;
}

void main() {
  testWidgets('PrayerTimesApp renders the prayer dashboard', (tester) async {
    final regions = (await tester.runAsync(loadBundledSchedules))!;
    final controller = PrayerController(
      deviceNow: () => DateTime(2026, 10, 25, 10),
      repository:
          _MemoryRepository(AppData.empty().withAvailableRegions(regions)),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Use the bundled Arabic fonts rather than the test runner's Ahem font,
    // whose glyph metrics do not represent this Arabic-only dashboard.
    final amiri = FontLoader('Amiri')
      ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    await tester.runAsync(amiri.load);

    await tester.pumpWidget(PrayerTimesApp(controller: controller));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('اختر المنطقة من الإعدادات'), findsOneWidget);
    expect(find.text('--:--'), findsNWidgets(7));
    expect(find.text('--:--:--'), findsOneWidget,
        reason: 'The dashboard uses one shared adhan/iqama countdown card.');
    expect(find.text('الوقت المتبقي للإقامة'), findsNothing);
    expect(find.text('الوقت المتبقي لإقامة الصلاة'), findsNothing);
    final tickerBounds = tester.getRect(find.byType(DuaTicker));
    expect(tickerBounds.height, 0);
    expect(tickerBounds.width, 0);
    await tester.runAsync(() => controller.updateSettings(
          controller.settings.copyWith(tickerScrollingEnabled: true),
        ));
    await tester.pump();
    final enabledTicker = tester.getRect(find.byType(DuaTicker));
    expect(enabledTicker.left, closeTo(0, 0.1));
    expect(enabledTicker.right, closeTo(1280, 0.1));
    expect(enabledTicker.height, greaterThanOrEqualTo(46));
    await tester.runAsync(() => controller.updateSettings(
          controller.settings.copyWith(tickerScrollingEnabled: false),
        ));
    await tester.pump();
    expect(tester.getSize(find.byType(DuaTicker)).height, 0);
    expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}:\d{2}\s+[صم]$')),
        findsNothing,
        reason: 'The main clock must not show AM/PM letters.');
    expect(find.textContaining(RegExp(r'^\d{1,2}:\d{2}\s+[صم]$')), findsNothing,
        reason: 'Prayer times must not show AM/PM letters.');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(controller: controller),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'Settings must accept an initially unselected region.');

    // Persisting a region also synchronizes native Android alarm settings.
    // Let real platform messages complete outside the widget fake clock.
    await tester.runAsync(() => controller.selectRegion(regions.last.id));
    await tester.pumpWidget(PrayerTimesApp(controller: controller));
    await tester.pump();
    expect(find.text('اختر المنطقة من الإعدادات'), findsNothing);
    expect(find.text('--:--'), findsNothing);
    expect(find.text('باقي لأذان الظهر'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
