import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/post_prayer_adhkar.dart';

void main() {
  testWidgets('All post-prayer entries fit phones and TVs with enlarged text',
      (tester) async {
    await tester.runAsync(() async {
      final font = FontLoader('AdhkarNaskh')
        ..addFont(rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf'));
      await font.load();
      await rootBundle.loadString('assets/data/post-prayer-adhkar.json');
    });
    final now = DateTime(2026, 10, 19, 6);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    for (final screen in const [
      Size(960, 540),
      Size(1280, 720),
      Size(1920, 1080),
      Size(640, 360),
      Size(390, 844),
    ]) {
      tester.view.physicalSize = screen;
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final prayer in ['fajr', 'dhuhr', 'maghrib']) {
          await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                  size: screen, textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: PostPrayerAdhkar(
                  now: now,
                  status: PrayerScreenStatus(
                    phase: PrayerScreenPhase.postPrayerDhikr,
                    label: '',
                    prayerId: prayer,
                    startsAt: now,
                    endsAt: now.add(const Duration(minutes: 4)),
                  ),
                ),
              ),
            ),
          ));
          await tester.runAsync(() async {
            await rootBundle.loadString('assets/data/post-prayer-adhkar.json');
          });
          await tester.pumpAndSettle();
          final clockFinder = find.byKey(const ValueKey('post-prayer-clock'));
          final clock = tester.widget<Text>(clockFinder);
          expect(clock.data, '6:00:00');
          expect(clock.style!.color, const Color(0xFFC62828));
          final titleBottom =
              tester.getBottomLeft(find.text('اذكار بعد الصلاة')).dy;
          expect(tester.getTopLeft(clockFinder).dy, greaterThan(titleBottom));
          for (final entry in tester.widgetList<Text>(find.byType(Text))) {
            if (entry.textSpan == null) continue;
            expect(tester.getBottomLeft(find.byWidget(entry)).dy,
                lessThanOrEqualTo(tester.getTopLeft(clockFinder).dy));
          }
          expect(tester.takeException(), isNull,
              reason: '$screen, text scale $scale, prayer $prayer');
          final texts =
              tester.renderObjectList<RenderBox>(find.byType(RichText));
          for (final text in texts) {
            final bounds = text.localToGlobal(Offset.zero) & text.size;
            expect(bounds.bottom, lessThanOrEqualTo(screen.height + 1));
            expect(bounds.right, lessThanOrEqualTo(screen.width + 1));
            expect(bounds.top, greaterThanOrEqualTo(-1));
            expect(bounds.left, greaterThanOrEqualTo(-1));
          }
        }
      }
    }
  });

  testWidgets('post-prayer clock follows live time in 12-hour format',
      (tester) async {
    final start = DateTime(2026, 11, 22, 23, 59, 59);
    final status = PrayerScreenStatus(
      phase: PrayerScreenPhase.postPrayerDhikr,
      label: '',
      prayerId: 'isha',
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 4)),
    );
    for (final time in [
      start,
      start.add(const Duration(seconds: 1)),
      start.add(const Duration(seconds: 1, milliseconds: 600)),
      DateTime(2026, 11, 23, 12, 1, 2),
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PostPrayerAdhkar(status: status, now: time)),
      ));
      await tester.runAsync(() async {
        await rootBundle.loadString('assets/data/post-prayer-adhkar.json');
      });
      await tester.pumpAndSettle();
      final clock =
          tester.widget<Text>(find.byKey(const ValueKey('post-prayer-clock')));
      expect(
          clock.data,
          {
            start: '11:59:59',
            start.add(const Duration(seconds: 1)): '12:00:00',
            start.add(const Duration(seconds: 1, milliseconds: 600)):
                '12:00:00',
            DateTime(2026, 11, 23, 12, 1, 2): '12:01:02',
          }[time]);
      if (time == start.add(const Duration(seconds: 1)) ||
          time == start.add(const Duration(seconds: 1, milliseconds: 600))) {
        expect(find.text('العودة للواجهة بعد 3:59'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
