import 'app_settings.dart';
import 'prayer_schedule.dart';
import 'hawd6_fajr_corrections.dart';

class AppData {
  AppData({
    required Map<String, PrayerRegion> regions,
    required this.selectedRegionId,
    required this.settings,
  }) : regions = Map.unmodifiable(regions);

  final Map<String, PrayerRegion> regions;
  final String selectedRegionId;
  final AppSettings settings;

  PrayerRegion? get selectedRegion => regions[selectedRegionId];

  AppData withAvailableRegions(Iterable<PrayerRegion> available) {
    final bundled = {for (final region in available) region.id: region};
    return AppData(
      regions: {
        ...bundled,
        for (final entry in regions.entries)
          entry.key: bundled.containsKey(entry.key)
              ? correctHawd6Fajr(entry.value, bundled[entry.key]!)
              : entry.value,
      },
      selectedRegionId: selectedRegionId,
      settings: settings,
    );
  }

  factory AppData.empty() {
    return AppData(
      regions: const {},
      selectedRegionId: '',
      settings: const AppSettings(),
    );
  }

  Map<String, Object?> toJson() => {
        'format': 'mwaqit-backup',
        'backupVersion': 1,
        'selectedRegionId': selectedRegionId,
        'settings': settings.toJson(),
        'regions': regions.values.map((region) => region.toJson()).toList(),
      };

  factory AppData.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'ملف النسخة الاحتياطية يجب أن يكون كائن JSON.',
      );
    }
    final map = Map<String, Object?>.from(value);
    if (map['format'] != 'mwaqit-backup' || map['backupVersion'] != 1) {
      throw const FormatException(
        'صيغة النسخة الاحتياطية أو رقم إصدارها غير مدعوم.',
      );
    }
    final rawRegions = map['regions'];
    if (rawRegions is! List) {
      throw const FormatException(
        'قائمة المناطق غير موجودة في النسخة الاحتياطية.',
      );
    }
    final regions = <String, PrayerRegion>{};
    for (final rawRegion in rawRegions) {
      final region = PrayerRegion.fromJson(rawRegion);
      if (regions.containsKey(region.id)) {
        throw FormatException('معرّف المنطقة "${region.id}" مكرر.');
      }
      regions[region.id] = region;
    }
    if (regions.isEmpty) {
      throw const FormatException(
        'يجب أن تحتوي النسخة الاحتياطية على منطقة واحدة على الأقل.',
      );
    }
    final selected = map['selectedRegionId'];
    final selectedId = selected == ''
        ? ''
        : selected is String && regions.containsKey(selected)
            ? selected
            : regions.keys.first;
    return AppData(
      regions: regions,
      selectedRegionId: selectedId,
      settings: AppSettings.fromJson(map['settings']),
    );
  }
}

PrayerRegion regionFromScheduleFile(Object? value) {
  if (value is! Map) {
    throw const FormatException('ملف المواقيت يجب أن يكون كائن JSON.');
  }
  final map = Map<String, Object?>.from(value);
  if (!map.containsKey('format') && map.containsKey('months')) {
    return PrayerRegion.fromAnnualJson(value);
  }
  if (map['format'] != 'mwaqit-prayer-times' || map['schemaVersion'] != 1) {
    throw const FormatException('صيغة ملف المواقيت أو إصدار المخطط غير مدعوم.');
  }
  if (map['template'] == true) {
    throw const FormatException(
      'هذا قالب توضيحي؛ استبدل القيم النموذجية بمواقيتك أولًا.',
    );
  }
  final region = map['region'];
  final years = map['years'];
  if (region is! Map || years is! List) {
    throw const FormatException('يجب أن يحتوي الملف على region و years.');
  }
  return PrayerRegion.fromJson({
    ...Map<String, Object?>.from(region),
    'years': years,
  });
}
