import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/dua_rotation.dart';
import 'package:prayer_times/ui/continuous_ticker.dart';
import 'package:prayer_times/ui/dua_ticker.dart';
import 'package:prayer_times/ui/prayer_period_theme.dart';

void main() {
  testWidgets('disabled ticker is completely hidden and does not rotate texts',
      (tester) async {
    final rotation = DuaRotation(DuaCatalogue(
      interval: const Duration(seconds: 10),
      groups: [
        DuaGroup(['الذكر الأول']),
        DuaGroup(['الذكر الثاني'])
      ],
    ));
    final first = rotation.current;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SizedBox(
          width: 600,
          child: DuaTicker(
            palette: PrayerPeriodPalette.forPeriod(PrayerPeriod.dhuhr),
            rotation: Future.value(rotation),
          )),
    )));
    await tester.pump();
    expect(find.text(first), findsNothing);
    expect(tester.getSize(find.byType(DuaTicker)).height, 0);
    await tester.pump(const Duration(seconds: 9));
    expect(find.text(first), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(first), findsNothing);
    expect(rotation.current, first);
    expect(find.byType(ContinuousTicker), findsNothing);
  });

  testWidgets('enabled scrolling uses the selected speed', (tester) async {
    final rotation = DuaRotation(DuaCatalogue(
      interval: const Duration(seconds: 10),
      groups: [
        DuaGroup(['الذكر الأول']),
        DuaGroup(['الذكر الثاني'])
      ],
    ));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SizedBox(
          width: 600,
          child: DuaTicker(
            palette: PrayerPeriodPalette.forPeriod(PrayerPeriod.dhuhr),
            rotation: Future.value(rotation),
            scrollingEnabled: true,
            speed: 64,
          )),
    )));
    await tester.pump();
    final ticker =
        tester.widget<ContinuousTicker>(find.byType(ContinuousTicker));
    expect(ticker.pixelsPerSecond, 64);
  });

  testWidgets(
      'slower left-to-right motion, adjacent texts and smooth cycle wrap',
      (tester) async {
    final font = FontLoader('Amiri')
      ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    await tester.runAsync(font.load);
    final capture = GlobalKey();
    final rotation = DuaRotation(DuaCatalogue(
      interval: const Duration(seconds: 20),
      groups: [
        DuaGroup(['اللهم بارك لنا في أعمارنا وأعمالنا.']),
        DuaGroup([
          'عن أبي هريرة رضي الله عنه عن النبي صلى الله عليه وسلم قال: «العين حق» متفق عليه'
        ]),
      ],
    ));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      backgroundColor: const Color(0xff073a2b),
      body: Center(
          child: RepaintBoundary(
        key: capture,
        child: SizedBox(
            width: 800,
            height: 48,
            child: ContinuousTicker(
              rotation: rotation,
              fontSize: 26,
              accent: const Color(0xffe4c66c),
            )),
      )),
    )));
    ContinuousTickerPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<ContinuousTickerPainter>()
        .single;
    await tester.pump(const Duration(milliseconds: 100));
    final start = painter().offset();
    await tester.pump(const Duration(seconds: 1));
    expect(painter().offset(), closeTo(start + 32, .01));
    expect(painter().items.first.text!.toPlainText(), contains('﴿ ۞ ﴾'));

    // Advance over many complete messages and several complete catalogue cycles.
    // Every painted frame remains covered by contiguous full-length text boxes.
    for (var i = 0; i < 180; i++) {
      await tester.pump(const Duration(seconds: 1));
      final current = painter();
      expect(current.offset(), greaterThanOrEqualTo(0));
      expect(current.items.first.width - current.offset(), greaterThan(0));
      expect(
          current.items.fold<double>(0, (n, p) => n + p.width) -
              current.offset(),
          greaterThanOrEqualTo(800));
      expect(current.items.length, lessThan(8));
    }
    final beforePause = painter().offset();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 5));
    expect(painter().offset(), beforePause);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 10));
    expect(painter().offset(), beforePause);
    await tester.pump(const Duration(seconds: 1));
    expect(painter().offset(), closeTo(beforePause + 32, .01));
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../../generated-artifacts/native-news-ticker.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
