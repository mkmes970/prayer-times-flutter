import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/ui/region_selection_notice.dart';

void main() {
  Widget app(bool hasRegion, {double width = 400}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: RegionSelectionNotice(visible: !hasRegion),
            ),
          ),
        ),
      );

  testWidgets('unset region has a larger red glowing notice', (tester) async {
    await tester.pumpWidget(app(false));
    final text = tester.widget<Text>(find.text('اختر المنطقة من الإعدادات'));
    expect(text.style!.fontSize, 24);
    expect(text.style!.color, const Color(0xFFD50000));
    expect(text.style!.fontWeight, FontWeight.bold);
    expect(text.style!.shadows, hasLength(2));
    expect(text.style!.shadows!.every((shadow) => shadow.blurRadius > 0), isTrue);
  });

  testWidgets('notice disappears after selection and returns if unset',
      (tester) async {
    await tester.pumpWidget(app(false));
    expect(find.text('اختر المنطقة من الإعدادات'), findsOneWidget);
    await tester.pumpWidget(app(true));
    expect(find.text('اختر المنطقة من الإعدادات'), findsNothing);
    await tester.pumpWidget(app(false));
    expect(find.text('اختر المنطقة من الإعدادات'), findsOneWidget);
  });

  testWidgets('notice scales down without clipping on narrow displays',
      (tester) async {
    await tester.pumpWidget(app(false, width: 190));
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsOneWidget);
  });
}
