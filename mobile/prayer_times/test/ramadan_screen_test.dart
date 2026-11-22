import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/ramadan_schedule.dart';
import 'package:prayer_times/services/prayer_summary_notification_service.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/ramadan_screen.dart';
import 'package:prayer_times/ui/dashboard_screen.dart';
import 'ramadan_schedule_test.dart' as fixtures;

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../../generated-artifacts/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _UnsupportedSummaryNotifications extends PrayerSummaryNotificationService {
  @override
  bool get isSupported => false;
}

void main() {
  testWidgets('welcome, 30 editable days and existing choice fit phone and TV',
      (tester) async {
    final repo = fixtures.MemoryRepository(fixtures.sampleRamadanData());
    final c = PrayerController(
        repository: repo,
        adhanAlarmService: fixtures.SilentAlarms(),
        prayerSummaryNotificationService: _UnsupportedSummaryNotifications(),
        deviceNow: () => fixtures.ramadanStart(1449));
    await tester.runAsync(c.initialize);
    addTearDown(c.dispose);
    final fonts = FontLoader('Amiri')
      ..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    await tester.runAsync(fonts.load);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    Widget app() => RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            theme: ThemeData(fontFamily: 'Amiri'),
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                                builder: (_) => RamadanScreen(controller: c))),
                        child: const Text('open'))))));
    for (final size in [
      const Size(360, 800),
      const Size(800, 360),
      const Size(1920, 1080),
      const Size(1024, 600)
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(app());
      await tester.tap(find.text('open'));
      await pumpUi(tester);
      expect(find.text('مبارك عليكم شهر رمضان المبارك'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size.width == 1024) {
        await capture(tester, boundary, 'ramadan-welcome');
      }
      await tester.ensureVisible(find.text('عندي إمساكية خاصة'));
      await tester.tap(find.text('عندي إمساكية خاصة'));
      await pumpUi(tester);
      expect(find.byKey(const ValueKey('ramadan-fajr-30')), findsOneWidget);
      expect(find.textContaining('00:00 — غير مضبوط'), findsNWidgets(60));
      expect(tester.takeException(), isNull);
      if (size.width == 1024) {
        await capture(tester, boundary, 'ramadan-editor');
      }
      await tester.pageBack();
      await pumpUi(tester);
    }
    await tester.tap(find.text('open'));
    await pumpUi(tester);
    await tester.ensureVisible(find.text('اعتماد أوقات الصلاة الموجودة'));
    await tester.tap(find.text('اعتماد أوقات الصلاة الموجودة'));
    await pumpUi(tester);
    expect(find.text('open'), findsOneWidget);
    expect(c.needsRamadanChoice, isFalse);
    expect(repo.data.settings.ramadanPlans['a']!.custom, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('editor picker, save, reopen, failure draft and incomplete input',
      (tester) async {
    final repo = fixtures.MemoryRepository(fixtures.sampleRamadanData(
        settings: AppSettings(ramadanPlans: {
      'a': RamadanPlan(year: 1449, custom: true, days: fixtures.ramadanDays())
    })));
    final c = PrayerController(
        repository: repo,
        adhanAlarmService: fixtures.SilentAlarms(),
        prayerSummaryNotificationService: _UnsupportedSummaryNotifications(),
        deviceNow: () => fixtures.ramadanStart(1449));
    await tester.runAsync(c.initialize);
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) =>
                                RamadanScreen(controller: c, greeting: false))),
                    child: const Text('open'))))));
    Future<void> editTime(String minute,
        {bool maghrib = false, String hour = '05'}) async {
      final field =
          find.byKey(ValueKey('ramadan-${maghrib ? 'maghrib' : 'fajr'}-1'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await pumpUi(tester);
      expect(find.byType(EditableText), findsNWidgets(2));
      expect(
          int.parse(tester
              .widget<EditableText>(find.byType(EditableText).first)
              .controller
              .text),
          inInclusiveRange(1, 12));
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
      await tester.tap(find.text(maghrib ? 'PM' : 'AM'));
      await tester.enterText(find.byType(EditableText).first, hour);
      await tester.enterText(find.byType(EditableText).last, minute);
      await tester.tap(find.text('OK'));
      await pumpUi(tester);
    }

    Future<void> save() async {
      final button = find.text('حفظ');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await pumpUi(tester);
    }

    await tester.tap(find.text('open'));
    await pumpUi(tester);
    await editTime('20');
    await editTime('10', maghrib: true, hour: '06');
    await save();
    expect(find.text('open'), findsOneWidget);
    expect(
        repo.data.settings.ramadanPlans['a']!.days[1]!.fajrSecondMinutes, 320);
    expect(repo.data.settings.ramadanPlans['a']!.days[1]!.maghribMinutes,
        18 * 60 + 10);
    expect(
        repo.data.settings.ramadanPlans['a']!.days[30]!.fajrSecondMinutes, 325);
    await tester.tap(find.text('open'));
    await pumpUi(tester);
    expect(find.textContaining('5:20 صباحًا'), findsOneWidget);
    expect(find.text('المغرب: 6:10 مساءً'), findsOneWidget);
    repo.failSave = true;
    await editTime('18');
    await save();
    expect(find.byType(RamadanScreen), findsOneWidget);
    expect(find.textContaining('تعذر الحفظ'), findsOneWidget);
    expect(find.textContaining('5:18 صباحًا'), findsOneWidget);
    expect(c.currentRamadanPlan!.days[1]!.fajrSecondMinutes, 320);
    repo.failSave = false;
    await save();
    expect(find.text('open'), findsOneWidget);
    expect(
        repo.data.settings.ramadanPlans['a']!.days[1]!.fajrSecondMinutes, 318);
    await c.useExistingRamadanTimes();
    await tester.tap(find.text('open'));
    await pumpUi(tester);
    await save();
    expect(
        find.textContaining('اليوم 1: أدخل وقت الفجر الثاني'), findsOneWidget);
    expect(c.currentRamadanPlan!.custom, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'dashboard opens Ramadan choice automatically only when undecided',
      (tester) async {
    rootBundle.clear();
    final repo = fixtures.MemoryRepository(fixtures.sampleRamadanData());
    final c = PrayerController(
        repository: repo,
        adhanAlarmService: fixtures.SilentAlarms(),
        prayerSummaryNotificationService: _UnsupportedSummaryNotifications(),
        deviceNow: () => fixtures.ramadanStart(1449));
    await tester.runAsync(c.initialize);
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: c)));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byType(RamadanScreen), findsNothing);
    final start = fixtures.ramadanStart(1449);
    c.clock.value = DateTime(start.year, start.month, start.day, 6);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byType(RamadanScreen), findsOneWidget);
    await tester.tap(find.text('اعتماد أوقات الصلاة الموجودة'));
    await pumpUi(tester);
    expect(find.byType(RamadanScreen), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(RamadanScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
