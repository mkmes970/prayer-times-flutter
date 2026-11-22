import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/ui/hadith_panel.dart';

Future<void> flushIo(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
}

void main() {
  for (final mode in [
    'general',
    'morning',
    'evening',
    'adhan',
    'friday',
    'ramadan',
  ]) {
    testWidgets('Master switch hides and resumes $mode content',
        (tester) async {
      // Each scenario represents an app that is open in the foreground.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Do not reuse asset-loading Futures from a previous test's fake clock.
      rootBundle.clear();
      final directory =
          Directory.systemTemp.createTempSync('hadith-master-switch-');
      addTearDown(() => directory.deleteSync(recursive: true));
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => directory.path,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final start = mode == 'morning'
          ? DateTime(2026, 10, 25, 6)
          : mode == 'evening'
              ? DateTime(2026, 10, 25, 17)
              : mode == 'adhan'
                  ? DateTime(2026, 10, 25, 11, 56)
                  : DateTime(2026, 10, 23, 10);
      var now = start;
      final visibility = <bool>[];
      Widget panel(bool enabled) => MaterialApp(
            home: Scaffold(
              body: HadithPanel(
                enabled: enabled,
                now: now,
                fridayMode: mode == 'friday',
                ramadanMode: mode == 'ramadan',
                morningStartsAt:
                    mode == 'morning' ? DateTime(2026, 10, 25, 5, 30) : null,
                morningEndsAt:
                    mode == 'morning' ? DateTime(2026, 10, 25, 6, 30) : null,
                eveningMaghribAt:
                    mode == 'evening' ? DateTime(2026, 10, 25, 18) : null,
                eveningEndsAt:
                    mode == 'evening' ? DateTime(2026, 10, 25, 17, 55) : null,
                adhanTimes:
                    mode == 'adhan' ? [DateTime(2026, 10, 25, 12)] : const [],
                onVisibilityChanged: visibility.add,
                child: const Text('dashboard'),
              ),
            ),
          );
      Future<void> tick(bool enabled) async {
        for (var second = 0; second < 11; second++) {
          now = now.add(const Duration(seconds: 1));
          await tester.pumpWidget(panel(enabled));
          await tester.pump(const Duration(seconds: 1));
          await flushIo(tester);
        }
      }

      // Dedicated windows must not bypass an initially disabled setting.
      await tester.pumpWidget(panel(false));
      await flushIo(tester);
      await tick(false);
      expect(find.text('dashboard'), findsOneWidget);
      expect(visibility, everyElement(isFalse));
      expect(
          File('${directory.path}/hadith-progress.json').existsSync(), isFalse);
      expect(
          File('${directory.path}/adhan-progress.json').existsSync(), isFalse);

      // Enabling restores the currently applicable content after its usual pause.
      await tester.pumpWidget(panel(true));
      await tick(true);
      expect(find.text('dashboard'), findsNothing);
      expect(visibility.last, isTrue);

      // Disable while content is visible: hide immediately, not at its end.
      await tester.pumpWidget(panel(false));
      expect(find.text('dashboard'), findsOneWidget);
      expect(visibility.last, isFalse);
      final progressFiles = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList();
      final saved = {
        for (final file in progressFiles) file.path: file.readAsStringSync(),
      };
      await tester.pump(const Duration(seconds: 90));
      await tick(false);
      expect(find.text('dashboard'), findsOneWidget);
      for (final entry in saved.entries) {
        expect(File(entry.key).readAsStringSync(), entry.value);
      }
      await tester.pumpWidget(panel(true));
      await tick(true);
      expect(find.text('dashboard'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await flushIo(tester);
    });
  }
}
