import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/services/adhan_alarm_service.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/dashboard_screen.dart';
import 'package:prayer_times/ui/settings_screen.dart';

class _MemoryRepository extends LocalRepository {
  AppData data = AppData.empty();

  @override
  Future<AppData> load() async => data;

  @override
  Future<void> save(AppData value) async => data = value;
}

class _QuietAlarms extends AdhanAlarmService {
  @override
  Future<void> synchronize(
    AppData data, {
    required bool requestPermissions,
    DateTime? now,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preview shows draft and save persists dashboard line color',
      (tester) async {
    final controller = PrayerController(
      repository: _MemoryRepository(),
      adhanAlarmService: _QuietAlarms(),
      deviceNow: () => DateTime(2026, 6, 10, 10),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ar')],
        home: SettingsScreen(controller: controller),
      ),
    );
    final toggle = find.byKey(const ValueKey('dashboard-line-color-toggle'));
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(toggle, 350, scrollable: scrollable);
    await tester.pump();
    expect(find.text('ألوان الخط'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();

    final yellow = find.byKey(const ValueKey('line-color-swatch-أصفر'));
    await tester.scrollUntilVisible(yellow, 250, scrollable: scrollable);
    await tester.pump();
    await tester.tap(yellow);
    await tester.pump();
    expect(controller.dashboardTextColor, isNull);

    final previewButton =
        find.byKey(const ValueKey('dashboard-line-color-preview'));
    await tester.scrollUntilVisible(previewButton, 250, scrollable: scrollable);
    await tester.pump();
    await tester.tap(previewButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(controller.dashboardTextColor, 0xFFFFEB3B);
    expect(controller.settings.dashboardTextColorEnabled, isFalse);
    Navigator.of(tester.element(find.byType(DashboardScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final saveButton = find.byKey(const ValueKey('dashboard-line-color-save'));
    await tester.scrollUntilVisible(saveButton, 250, scrollable: scrollable);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(controller.settings.dashboardTextColorEnabled, isTrue);
    expect(controller.settings.dashboardTextColor, 0xFFFFEB3B);
    expect(controller.dashboardTextColor, 0xFFFFEB3B);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
