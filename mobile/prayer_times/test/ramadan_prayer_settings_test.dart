import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/settings_screen.dart';

import 'ramadan_schedule_test.dart' as fixtures;

void main() {
  testWidgets('administrators can enable and save Ramadan night prayers',
      (tester) async {
    final start = fixtures.ramadanStart(1449);
    final repository = fixtures.MemoryRepository(fixtures.sampleRamadanData());
    final controller = PrayerController(
      repository: repository,
      adhanAlarmService: fixtures.SilentAlarms(),
      deviceNow: () => start,
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    final fonts = FontLoader('Amiri')
      ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    await tester.runAsync(fonts.load);
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
          theme: ThemeData(fontFamily: 'Amiri'),
          home: SettingsScreen(controller: controller)),
    );
    Future<void> reveal(String key) =>
        tester.scrollUntilVisible(find.byKey(ValueKey(key)), 150,
            maxScrolls: 60, scrollable: find.byType(Scrollable).first);
    await reveal('ramadan-taraweeh-toggle');
    await tester.tap(find.byKey(const ValueKey('ramadan-taraweeh-toggle')));
    await tester.pumpAndSettle();
    await reveal('ramadan-taraweeh-duration');
    expect(find.byKey(const ValueKey('ramadan-taraweeh-duration')),
        findsOneWidget);
    expect(
      tester
          .widget<TextField>(
              find.byKey(const ValueKey('ramadan-taraweeh-duration')))
          .controller!
          .text,
      '35',
    );

    await reveal('ramadan-qiyam-toggle');
    await tester.tap(find.byKey(const ValueKey('ramadan-qiyam-toggle')));
    await tester.pumpAndSettle();
    await reveal('ramadan-qiyam-start');
    await tester.tap(find.byKey(const ValueKey('ramadan-qiyam-start')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    await tester.tap(find.text('PM'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('تبدأ 2:30 مساءً'), findsOneWidget);

    await reveal('save-ramadan-prayer-settings');
    await tester
        .tap(find.byKey(const ValueKey('save-ramadan-prayer-settings')));
    await tester.pumpAndSettle();
    expect(repository.data.settings.ramadanTaraweehEnabled, isTrue);
    expect(repository.data.settings.ramadanTaraweehMinutes, 35);
    expect(repository.data.settings.ramadanQiyamEnabled, isTrue);
    expect(repository.data.settings.ramadanQiyamStartMinutes, 14 * 60 + 30);
    expect(repository.data.settings.ramadanQiyamEndMinutes, 210);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
