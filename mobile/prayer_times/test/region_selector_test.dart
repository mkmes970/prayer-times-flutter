import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/ui/region_selector.dart';

void main() {
  const options = {
    'a': 'مواقيت الصلاة لقرية حوض 6',
    'b': 'مواقيت الصلاة لقرية النميصة',
    'tal-ali': 'مواقيت الصلاة لقرية تل علي',
  };

  Widget app(ValueChanged<String> onChanged) => MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: RegionSelector(
              options: options,
              selectedId: 'b',
              onChanged: onChanged,
            ),
          ),
        ),
      );

  testWidgets('search exposes Tal Ali and returns its draft id',
      (tester) async {
    String? draft;
    await tester.pumpWidget(app((id) => draft = id));
    await tester.tap(find.byKey(const Key('region-selector')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('region-search')), 'تل علي');
    await tester.pumpAndSettle();
    expect(find.text(options['tal-ali']!), findsOneWidget);
    expect(find.byKey(const ValueKey('region-a')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('region-tal-ali')));
    await tester.pumpAndSettle();
    expect(draft, 'tal-ali');
  });

  testWidgets('cancel and empty search do not change the selected region',
      (tester) async {
    String? draft;
    await tester.pumpWidget(app((id) => draft = id));
    await tester.tap(find.byKey(const Key('region-selector')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('region-search')), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد منطقة مطابقة للاسم.'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(draft, isNull);
    expect(find.text(options['b']!), findsOneWidget);
  });

  testWidgets('fits the short landscape viewport used by a rotated phone',
      (tester) async {
    tester.view.physicalSize = const Size(877, 340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app((_) {}));
    await tester.tap(find.byKey(const Key('region-selector')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const Key('region-search')), 'تل');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('region-tal-ali')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
