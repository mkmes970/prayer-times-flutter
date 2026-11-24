import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/app_data.dart';
import '../models/prayer_schedule.dart';

// Add future user-approved regional files here without changing the dashboard.
const bundledScheduleAssets = [
  'assets/data/hawd6-prayer-times.json',
  'assets/data/al-abbasi-prayer-times.json',
  'assets/data/dhuwaib-prayer-times.json',
  'assets/data/hawija-prayer-times.json',
  'assets/data/tikrit-prayer-times.json',
  'assets/data/baggara-prayer-times.json',
  'assets/data/shajara-prayer-times.json',
  'assets/data/alam-prayer-times.json',
  'assets/data/numaysa-prayer-times.json',
  'assets/data/tal-ali-prayer-times.json',
  'assets/data/zab-prayer-times.json',
  'assets/data/tal-al-dhahab-prayer-times.json',
];

Future<List<PrayerRegion>> loadBundledSchedules() async {
  final regions = <PrayerRegion>[];
  final ids = <String>{};
  for (final path in bundledScheduleAssets) {
    final region = regionFromScheduleFile(
      jsonDecode(await rootBundle.loadString(path)),
    );
    if (!ids.add(region.id)) {
      throw FormatException('جدول المنطقة "${region.name}" مكرر.');
    }
    regions.add(region);
  }
  return regions;
}
