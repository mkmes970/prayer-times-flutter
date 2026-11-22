import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/hadith_timing.dart';
import 'package:prayer_times/ui/hadith_panel.dart';

void main() {
  testWidgets(
      'ten-second dashboard, complete reading, interruption and disk resume',
      (tester) async {
    final directory = Directory.systemTemp.createTempSync('hadith-panel-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    tester.view.physicalSize = const Size(1024, 465);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fonts = FontLoader('Amiri')
      ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    await tester.runAsync(fonts.load);
    final capture = GlobalKey();
    final now = DateTime(2026, 10, 18, 10);
    Widget panel({bool blocked = false}) => RepaintBoundary(
          key: capture,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Amiri'),
              home: Scaffold(
                  body: HadithPanel(
                enabled: true,
                now: now,
                adhanBlocked: blocked,
                child: const Center(child: Text('dashboard')),
              ))),
        );
    Future<void> flushIo() async {
      // Asset and file awaits resume in the fake test zone between real IO turns.
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump();
      }
    }

    final progress = File('${directory.path}/hadith-progress.json');
    Map<String, dynamic> readProgress() =>
        jsonDecode(progress.readAsStringSync()) as Map<String, dynamic>;

    await tester.pumpWidget(panel());
    await flushIo();
    expect(find.text('dashboard'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('dashboard'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await flushIo();
    expect(progress.existsSync(), isTrue);
    expect(find.text('dashboard'), findsNothing);
    expect(readProgress()['decks'].containsKey('general'), isFalse);
    expect(tester.takeException(), isNull);

    // Keep a native-rendered image for visual review; never a fake web preview.
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('../../generated-artifacts/prayer-hadith-native.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(panel(blocked: true));
    expect(find.text('dashboard'), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(readProgress()['decks'].containsKey('general'), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(panel());
    await flushIo();
    expect(find.text('dashboard'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await flushIo();
    expect(readProgress()['decks'].containsKey('general'), isFalse,
        reason: 'Random readings must not be saved or resumed');
    // Every ordinary reading is at most 60 seconds; only a full reading advances.
    await tester.pump(const Duration(seconds: 60));
    await flushIo();
    expect(readProgress()['decks'].containsKey('general'), isFalse);
    expect(find.text('dashboard'), findsOneWidget);
    expect(normalInformationSeconds, 10);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
