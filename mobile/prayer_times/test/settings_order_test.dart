import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/services/bundled_schedules.dart';
import 'package:prayer_times/services/local_repository.dart';
import 'package:prayer_times/state/prayer_controller.dart';
import 'package:prayer_times/ui/settings_screen.dart';

class _MemoryRepository extends LocalRepository {
  _MemoryRepository(this.data);

  AppData data;

  @override
  Future<AppData> load() async => data;

  @override
  Future<void> save(AppData value) async => data = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings sections follow the requested order and list region',
      (tester) async {
    final regions = (await tester.runAsync(loadBundledSchedules))!;
    final repository = _MemoryRepository(
      AppData.empty().withAvailableRegions(regions),
    );
    final controller = PrayerController(repository: repository);
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(controller: controller)),
    );
    final list = tester.widget<ListView>(find.byType(ListView).first);
    final children =
        (list.childrenDelegate as SliverChildListDelegate).children;
    final markers = <String>[];
    for (final child in children) {
      final key = child.key;
      if (key is ValueKey<String> &&
          key.value.startsWith('settings-section:')) {
        markers.add(key.value.substring('settings-section:'.length));
      }
    }
    expect(markers.take(13), [
      'مواقيت الصلاة حسب المنطقة',
      'السمات',
      'اسم المسجد',
      'تنبيهات الأذان',
      'عرض الأحاديث',
      'الشريط السفلي',
      'الوقت المتبقي لإقامة الصلاة',
      'وقت الصلاة',
      'أذكار بعد الصلاة وخطبة الجمعة',
      'صلاة التراويح والقيام في رمضان',
      'تعديل التاريخ الهجري يدويًا',
      'شهر رمضان المبارك',
      'حجم خط اسم المسجد والساعة',
    ]);
    expect(
      markers.indexOf('إدارة المناطق والمواقيت'),
      greaterThan(markers.indexOf('حجم خط اسم المسجد والساعة')),
    );

    expect(
      controller.regions.values.map((region) => region.name),
      contains('مواقيت الصلاة لقرية تل الذهب'),
    );
  });
}
