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
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/mosque_heading.dart';
import 'package:prayer_times/ui/settings_screen.dart';

class _Repository extends LocalRepository {
  _Repository(this.data);
  AppData data;

  @override
  Future<AppData> load() async =>
      AppData.fromJson(jsonDecode(jsonEncode(data.toJson())));

  @override
  Future<void> save(AppData value) async =>
      data = AppData.fromJson(jsonDecode(jsonEncode(value.toJson())));
}

const _lines = ['مسجد الصحابي', 'خالد بن الوليد', 'رضي الله عنه'];

AppSettings _settings(int mask) => AppSettings(
      mosqueName: mask & 1 != 0 ? _lines[0] : '',
      mosqueNameLine2: mask & 2 != 0 ? _lines[1] : '',
      mosqueNameLine3: mask & 4 != 0 ? _lines[2] : '',
    );

AppData _data(AppSettings settings) {
  final region = PrayerRegion(id: 'test', name: 'منطقة الاختبار', days: {
    '2026-11-22': PrayerTimes({
      'fajrFirst': '05:12',
      'fajrSecond': '05:27',
      'sunrise': '06:47',
      'dhuhr': '11:55',
      'asr': '14:40',
      'maghrib': '16:58',
      'isha': '18:18',
    }),
  });
  return AppData(
    regions: {region.id: region},
    selectedRegionId: region.id,
    settings: settings,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('old names migrate unchanged; all optional combinations round trip', () {
    final legacy = AppSettings.fromJson({'mosqueName': 'الاسم المحفوظ سابقًا'});
    expect(legacy.mosqueNameLines, ['الاسم المحفوظ سابقًا']);
    expect(legacy.mosqueNameLine2, isEmpty);
    expect(legacy.mosqueNameLine3, isEmpty);
    for (var mask = 0; mask < 8; mask++) {
      final settings = _settings(mask);
      final restored = AppSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())),
      );
      expect(restored.mosqueNameLines, settings.mosqueNameLines);
      expect(restored.copyWith(fontScale: 1.2).mosqueNameLines,
          settings.mosqueNameLines);
      expect(
        restored.copyWith(mosqueNameLine2: '').mosqueNameLine2,
        isEmpty,
      );
    }
    expect(
      const AppSettings(mosqueName: '  ', mosqueNameLine3: ' الثالث ')
          .mosqueNameLines,
      ['الثالث'],
    );
  });

  testWidgets('three fixed slots retain empty fields without truncation',
      (tester) async {
    List<Rect>? originalSlots;
    for (var mask = 0; mask < 8; mask++) {
      final settings = _settings(mask);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: MosqueHeading(
              settings: settings,
              style: const TextStyle(fontSize: 42),
            ),
          ),
        ),
      ));
      final expected = settings.mosqueNameLines;
      final shown = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(MosqueHeading),
            matching: find.byType(Text),
          ))
          .toList();
      expect(shown.map((text) => text.data),
          expected.isEmpty ? [settings.appName] : expected);
      expect(shown.every((text) => text.overflow != TextOverflow.ellipsis),
          isTrue);
      final slots = [
        for (var index = 1; index <= 3; index++)
          tester.getRect(find.byKey(ValueKey('mosque-heading-slot-$index'))),
      ];
      originalSlots ??= slots;
      expect(slots, originalSlots);
      for (var index = 0; index < 3; index++) {
        final text = find.text(_lines[index]);
        if (mask & (1 << index) != 0) {
          // A line must occupy its own row, including when earlier rows are
          // empty. Its baseline must not migrate to the first available row.
          expect(
              tester.getCenter(text).dy, closeTo(slots[index].center.dy, 0.01));
        }
      }
      for (var index = 1; index < shown.length; index++) {
        expect(
          tester.getTopLeft(find.text(shown[index].data!)).dy,
          greaterThan(tester.getTopLeft(find.text(shown[index - 1].data!)).dy),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('three fields save, reopen and can be independently cleared',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository(
      _data(const AppSettings(mosqueName: 'قديم')),
    );
    final controller = PrayerController(repository: repository);
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(controller: controller),
    ));
    Future<void> fill(int index, String value) async {
      tester.testTextInput.hide();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      final field = find.byKey(ValueKey('mosque-name-line-$index'));
      await tester.scrollUntilVisible(field, 400,
          scrollable: find.byType(Scrollable).first);
      final input = tester.widget<TextField>(field);
      expect(input.decoration?.hintText, isNull);
      expect(input.decoration?.labelText,
          ['السطر الأول', 'السطر الثاني', 'السطر الثالث'][index - 1]);
      await tester.enterText(field, value);
    }

    Future<void> save() async {
      tester.testTextInput.hide();
      final button = find.text('حفظ الاسم');
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(button);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }

    for (var index = 0; index < 3; index++) {
      await fill(index + 1, _lines[index]);
    }
    await save();
    expect(repository.data.settings.mosqueNameLines, _lines);
    final reopened = PrayerController(repository: repository);
    await tester.runAsync(reopened.initialize);
    addTearDown(reopened.dispose);
    expect(reopened.settings.mosqueNameLines, _lines);
    await fill(1, '');
    await fill(2, '');
    await save();
    expect(repository.data.settings.mosqueNameLines, [_lines[2]]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('three-line dashboard fits phone and television landscapes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await (FontLoader('Amiri')
            ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Amiri-Bold.ttf')))
          .load();
    });
    final repository = _Repository(
      _data(_settings(7).copyWith(tickerScrollingEnabled: true)),
    );
    final controller = PrayerController(
      repository: repository,
      deviceNow: () => DateTime(2026, 11, 22, 13, 27, 58),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    final capture = GlobalKey();
    for (final size in [
      const Size(1024, 465),
      const Size(720, 360),
      const Size(1920, 1080),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(RepaintBoundary(
        key: capture,
        child: PrayerTimesApp(controller: controller),
      ));
      await tester.pump();
      for (final line in _lines) {
        expect(find.text(line), findsOneWidget);
        final rect = tester.getRect(find.text(line));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThan(size.height));
      }
      expect(tester.takeException(), isNull);
      if (size.width == 1024) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file =
              File('../../generated-artifacts/mosque-name-three-lines.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('long headings cannot shrink the clock, weekday or calendars',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Rect visibleRect(Finder finder) {
      final box = tester.renderObject<RenderBox>(finder);
      return Rect.fromPoints(
        box.localToGlobal(Offset.zero),
        box.localToGlobal(box.size.bottomRight(Offset.zero)),
      );
    }

    for (final size in [
      const Size(1024, 465),
      const Size(720, 360),
      const Size(1920, 1080),
    ]) {
      tester.view.physicalSize = size;
      List<Rect>? reference;
      for (final settings in [
        const AppSettings(mosqueName: 'مسجد'),
        _settings(7),
        const AppSettings(
          mosqueName: 'مسجد الصحابي الجليل خالد بن الوليد رضي الله عنه الكبير',
          mosqueNameLine2: 'خالد بن الوليد',
          mosqueNameLine3: 'رضي الله عنه',
        ),
        const AppSettings(mosqueNameLine3: 'رضي الله عنه'),
      ]) {
        final controller = PrayerController(
          repository: _Repository(
              _data(settings.copyWith(tickerScrollingEnabled: true))),
          deviceNow: () => DateTime(2026, 11, 22, 13, 27, 58),
        );
        await tester.runAsync(controller.initialize);
        await tester.pumpWidget(PrayerTimesApp(controller: controller));
        await tester.pump();
        final readout = find.byKey(const ValueKey('dashboard-clock-calendars'));
        final texts = find.descendant(of: readout, matching: find.byType(Text));
        final rects = texts.evaluate().map((element) {
          return visibleRect(find.byWidget(element.widget));
        }).toList();
        if (reference == null) {
          reference = rects;
          // At the reference phone size the clock is genuinely large on
          // screen, not merely a large font inside a shrunken parent.
          if (size.width == 1024) {
            expect(rects.first.height, greaterThan(38));
          }
        } else {
          expect(rects.length, reference.length);
          for (var i = 0; i < rects.length; i++) {
            expect(rects[i].top, closeTo(reference[i].top, 0.01));
            expect(rects[i].height, closeTo(reference[i].height, 0.01));
          }
        }
        final heading = visibleRect(find.byType(MosqueHeading));
        expect(heading.top, greaterThanOrEqualTo(0));
        expect(heading.bottom, lessThanOrEqualTo(rects.first.top));
        if (settings.mosqueName == _lines[0] && size.width == 1024) {
          final firstLine = visibleRect(find.text(_lines[0]));
          expect(firstLine.height, greaterThan(30));
          expect(firstLine.top, lessThan(30));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    }
  });
}
