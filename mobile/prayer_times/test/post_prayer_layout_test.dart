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
          expect(tester.takeException(), isNull,
              reason: '$screen, text scale $scale, prayer $prayer');
          final texts = tester.renderObjectList<RenderBox>(find.byType(RichText));
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
}
