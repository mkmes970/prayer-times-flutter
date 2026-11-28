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
import 'package:prayer_times/models/dashboard_font_levels.dart';
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

class _SettingsController extends PrayerController {
  _SettingsController({required super.repository});
  Future<void>? pendingSave;

  @override
  Future<void> updateSettings(AppSettings value) =>
      pendingSave = super.updateSettings(value);
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
            expect(visibleRect(find.text('1:27:58')).height, greaterThan(20));
          }
        } else {
          expect(rects.length, reference.length);
          for (var i = 0; i < rects.length; i++) {
            expect(rects[i].top, closeTo(reference[i].top, 0.01));
            expect(rects[i].height, closeTo(reference[i].height, 0.01));
          }
        }
        final heading =
            visibleRect(find.byKey(const ValueKey('dashboard-mosque-area')));
        expect(heading.top, greaterThanOrEqualTo(0));
        expect(heading.bottom, lessThanOrEqualTo(rects.first.top));
        if (settings.mosqueName == _lines[0] && size.width == 1024) {
          final firstLine = visibleRect(find.text(_lines[0]));
          expect(firstLine.height, greaterThan(20));
          expect(firstLine.top, lessThan(45));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    }
  });

  testWidgets('ten independent font levels keep calendars bottom anchored',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 465);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, double>? baseline;
    double? previousClockHeight;
    double? previousNameHeight;
    for (var level = 1; level <= 10; level++) {
      final nameScale = DashboardFontLevels.nameScale(level);
      final clockScale = DashboardFontLevels.clockScale(level);
      final controller = PrayerController(
        repository: _Repository(_data(_settings(7).copyWith(
          fontScale: nameScale,
          clockScale: clockScale,
          mainClockLevel: level,
          tickerScrollingEnabled: true,
        ))),
        deviceNow: () => DateTime(2026, 11, 22, 13, 27, 58),
      );
      await tester.runAsync(controller.initialize);
      await tester.pumpWidget(PrayerTimesApp(controller: controller));
      await tester.pump();
      final heading = find.byKey(const ValueKey('dashboard-mosque-area'));
      final readout = find.byKey(const ValueKey('dashboard-clock-calendars'));
      final headingRect = tester.getRect(heading);
      final readoutRect = tester.getRect(readout);
      expect(headingRect.bottom, closeTo(readoutRect.top, 0.01));
      double font(String text) =>
          tester.widget<Text>(find.text(text)).style!.fontSize!;
      double renderedHeight(String text) =>
          tester.getRect(find.text(text)).height;
      final values = {
        'name': font(_lines.first),
        'nameHeight': renderedHeight(_lines.first),
        'clock': font('1:27:58'),
        'clockHeight': renderedHeight('1:27:58'),
        'weekday': font('الأحد'),
        'weekdayHeight': renderedHeight('الأحد'),
        'prayer': font('العصر'),
        'time': font('2:40'),
        'timeHeight': renderedHeight('2:40'),
        'countdown': font('باقي لأذان العصر'),
        'readoutBottom': readoutRect.bottom,
        'readoutTop': readoutRect.top,
      };
      expect(
          values['name'],
          closeTo(values['prayer']! * DashboardFontLevels.nameRatio(nameScale),
              .01));
      expect(
          values['clock'],
          closeTo(values['prayer']! * DashboardFontLevels.mainClockRatio(level),
              .01));
      expect(
        values['weekday'],
        closeTo(
          values['prayer']! * DashboardFontLevels.clockRatio(clockScale),
          .01,
        ),
      );
      final dates = tester
          .widgetList<Text>(find.descendant(
            of: readout,
            matching: find.byType(Text),
          ))
          .where((text) => text.data == '2026' || text.data == '1448');
      expect(dates.length, 2);
      for (final date in dates) {
        expect(date.style!.fontSize, closeTo(values['weekday']!, .01));
        expect(tester.getRect(find.byWidget(date)).bottom,
            lessThanOrEqualTo(readoutRect.bottom + .01));
      }
      if (previousClockHeight != null) {
        expect(values['clockHeight'], greaterThan(previousClockHeight));
        expect(values['nameHeight'], greaterThan(previousNameHeight!));
      }
      previousClockHeight = values['clockHeight'];
      previousNameHeight = values['nameHeight'];
      if (baseline == null) {
        baseline = values;
      } else {
        expect(
            values['readoutBottom'], closeTo(baseline['readoutBottom']!, .01));
        expect(values['readoutTop'], lessThan(baseline['readoutTop']!));
        for (final key in ['prayer', 'time', 'countdown']) {
          expect(values[key], baseline[key]);
        }
      }
      expect(values['prayer'], greaterThan(26));
      expect(values['time'], greaterThan(24));
      expect(values['timeHeight'], greaterThan(24));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  test('all ten font levels survive save and restore', () {
    for (var level = 1; level <= 10; level++) {
      final settings = AppSettings(
        fontScale: DashboardFontLevels.nameScale(level),
        clockScale: DashboardFontLevels.clockScale(11 - level),
        mainClockLevel: level,
      );
      final restored = AppSettings.fromJson(settings.toJson());
      expect(DashboardFontLevels.nameLevel(restored.fontScale), level);
      expect(DashboardFontLevels.clockLevel(restored.clockScale), 11 - level);
      expect(restored.mainClockLevel, level);
    }
    expect(DashboardFontLevels.nameRatio(1.4), 2);
    expect(DashboardFontLevels.clockRatio(1.3), 1.25);
    expect(DashboardFontLevels.mainClockRatio(1), 1);
    expect(DashboardFontLevels.mainClockRatio(10), 3);
  });

  testWidgets('settings sliders expose ten choices and save independently',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository(_data(_settings(7)));
    final controller = _SettingsController(repository: repository);
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(MaterialApp(home: SettingsScreen(controller: controller)));
    final originalClockScale = controller.settings.clockScale;
    for (final key in [
      'mosque-font-level',
      'clock-font-level',
      'main-clock-font-level',
    ]) {
      final finder = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(finder, 350,
          scrollable: find.byType(Scrollable).first);
      final slider = tester.widget<Slider>(finder);
      final clockScaleBeforeChange = controller.settings.clockScale;
      expect(slider.min, 1);
      expect(slider.max, 10);
      expect(slider.divisions, 9);
      await tester.runAsync(() async {
        slider.onChanged!(10);
        await controller.pendingSave;
      });
      await tester.pump();
      expect(DashboardFontLevels.nameLevel(repository.data.settings.fontScale),
          10);
      if (key == 'mosque-font-level') {
        expect(controller.settings.clockScale, originalClockScale);
      } else if (key == 'clock-font-level') {
        expect(
            DashboardFontLevels.clockLevel(repository.data.settings.clockScale),
            10);
        expect(repository.data.settings.mainClockLevel, 1);
      } else {
        expect(repository.data.settings.mainClockLevel, 10);
        expect(controller.settings.clockScale, clockScaleBeforeChange);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('maximum fonts remain unscaled on phone and television',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PrayerController(
      repository: _Repository(_data(const AppSettings(
        mosqueName: 'مسجد الرحمن',
        fontScale: 1.4,
        clockScale: 1.3,
        mainClockLevel: 10,
        tickerScrollingEnabled: true,
      ))),
      deviceNow: () => DateTime(2026, 11, 22, 13, 27, 58),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    final capture = GlobalKey();
    for (final size in [
      const Size(720, 360),
      const Size(1024, 465),
      const Size(1920, 1080),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(RepaintBoundary(
        key: capture,
        child: PrayerTimesApp(controller: controller),
      ));
      await tester.pump();
      double font(String text) =>
          tester.widget<Text>(find.text(text)).style!.fontSize!;
      expect(font('مسجد الرحمن'), closeTo(font('العصر') * 2, .01));
      expect(font('1:27:58'), closeTo(font('العصر') * 3, .01));
      expect(font('الأحد'), closeTo(font('العصر') * 1.25, .01));
      final clockGroup = tester
          .getRect(find.byKey(const ValueKey('dashboard-clock-calendars')));
      final heading =
          tester.getRect(find.byKey(const ValueKey('dashboard-mosque-area')));
      expect(heading.height, greaterThan(0));
      expect(heading.bottom, closeTo(clockGroup.top, .01));
      expect(clockGroup.bottom,
          lessThan(tester.getTopLeft(find.text('باقي لأذان العصر')).dy));
      expect(tester.takeException(), isNull);
      if (size.width == 1024) {
        await tester.runAsync(() async {
          final image = await (capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('../../generated-artifacts/dashboard-max-fonts.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Amiri dots and strokes are not clipped in any mosque line',
      (tester) async {
    tester.view.physicalSize = const Size(700, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await (FontLoader('Amiri')
            ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Amiri-Bold.ttf')))
          .load();
    });
    const name = 'مسجد الصحابي الجليل';
    final capture = GlobalKey();
    Future<(int, int)> ink(Widget child) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: RepaintBoundary(
            key: capture,
            child: SizedBox(
              width: 650,
              height: 350,
              child: ClipRect(child: child),
            ),
          ),
        ),
      ));
      await tester.pump();
      return (await tester.runAsync(() async {
        final image = await (capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        var alpha = 0;
        var firstRow = image.height;
        var lastRow = -1;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final value = bytes!.getUint8((y * image.width + x) * 4 + 3);
            alpha += value;
            if (value > 0) {
              if (y < firstRow) firstRow = y;
              if (y > lastRow) lastRow = y;
            }
          }
        }
        image.dispose();
        return (alpha, lastRow - firstRow + 1);
      }))!;
    }

    for (final size in [28.0, 61.0]) {
      final style = TextStyle(
        fontFamily: 'Amiri',
        fontWeight: FontWeight.bold,
        fontSize: size,
        height: 1.05,
        color: Colors.black,
      );
      // An unconstrained reference with ample paint space around the glyphs.
      final reference = await ink(Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(name, style: style, overflow: TextOverflow.visible),
        ),
      ));
      for (var line = 1; line <= 3; line++) {
        final actual = await ink(OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: SizedBox(
            width: 650,
            child: MosqueHeading(
              settings: AppSettings(
                mosqueName: line == 1 ? name : '',
                mosqueNameLine2: line == 2 ? name : '',
                mosqueNameLine3: line == 3 ? name : '',
              ),
              style: style,
              fitLines: false,
            ),
          ),
        ));
        expect(actual.$1, closeTo(reference.$1, reference.$1 * .01),
            reason: 'Line $line at $size must retain all glyph ink');
        expect(actual.$2, closeTo(reference.$2, 1),
            reason: 'Ascenders, dots and descenders must retain their height');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('three large mosque lines keep their glyphs in the dashboard',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 465);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel = MethodChannel('com.example.prayertimes/device');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'getDeviceTimeZoneId' ? 'Asia/Baghdad' : null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final controller = PrayerController(
      repository: _Repository(_data(const AppSettings(
        mosqueName: 'مسجد الصحابي الجليل',
        mosqueNameLine2: 'خالد بن الوليد',
        mosqueNameLine3: 'رضي الله عنه',
        fontScale: 1.4,
        clockScale: .8,
        tickerScrollingEnabled: true,
      ))),
      deviceNow: () => DateTime(2026, 11, 22, 13, 27, 58),
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    final capture = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: capture, child: PrayerTimesApp(controller: controller)));
    await tester.pump();
    final area =
        tester.getRect(find.byKey(const ValueKey('dashboard-mosque-area')));
    final thirdLine = tester.getRect(find.text('رضي الله عنه'));
    expect(thirdLine.bottom, lessThan(area.bottom));
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('../../generated-artifacts/mosque-name-unclipped.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
