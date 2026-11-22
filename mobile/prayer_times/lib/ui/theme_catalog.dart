import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import 'prayer_period_theme.dart';

String periodLabel(PrayerPeriod period) => const [
      'الفجر',
      'الشروق',
      'الظهر',
      'العصر',
      'المغرب',
      'العشاء',
    ][period.index];

/// A visual design, independent of the time to which staff assign it.
class DashboardTheme {
  const DashboardTheme(this.sourcePeriod, this.variant);

  final PrayerPeriod sourcePeriod;
  final int variant;

  String get id => '${sourcePeriod.name}-$variant';
  String get label => '${periodLabel(sourcePeriod)} ${variant + 1}';
  String? get backgroundAsset => variant == 0
      ? null
      : 'assets/themes/${sourcePeriod.name}-${variant.toString().padLeft(2, '0')}.webp';

  PrayerPeriodPalette get palette {
    if (variant == 0) return PrayerPeriodPalette.forPeriod(sourcePeriod);
    final colors = _skies[sourcePeriod.index][variant - 1];
    final dark = {
      PrayerPeriod.fajr,
      PrayerPeriod.maghrib,
      PrayerPeriod.isha,
    }.contains(sourcePeriod);
    final card = sourcePeriod == PrayerPeriod.maghrib
        ? const Color(0xFF3C3549)
        : const Color(0xFF173E35);
    return PrayerPeriodPalette(
      period: sourcePeriod,
      skyTop: Color(0xFF000000 | colors[0]),
      skyMiddle: Color(0xFF000000 | colors[1]),
      skyBottom: Color(0xFF000000 | colors[2]),
      accent: Color(dark ? 0xFFD8BA77 : 0xFFA58242),
      ink: Color(dark ? 0xFFFFF5DE : 0xFF173B2B),
      card: card,
      rowSurface: Color(dark ? 0xFF244047 : 0xFFF1E1B8),
      ribbon: card,
      mosque: const Color(0xFF71877A),
      night: sourcePeriod == PrayerPeriod.fajr ||
          sourcePeriod == PrayerPeriod.isha,
    );
  }
}

final List<DashboardTheme> dashboardThemes = List.unmodifiable([
  for (final period in PrayerPeriod.values)
    for (var variant = 0; variant < 6; variant++)
      DashboardTheme(period, variant),
]);

DashboardTheme? themeForId(String? id) {
  for (final theme in dashboardThemes) {
    if (theme.id == id) return theme;
  }
  return null;
}

DashboardTheme themeForPeriod(PrayerPeriod period, AppSettings settings) =>
    (settings.customThemesEnabled
        ? themeForId(settings.periodThemes[period.name])
        : null) ??
    dashboardThemes[period.index * 6];

// Palettes of the approved landscape proposals. Text and data are live widgets,
// never part of a background image.
const _skies = [
  [
    [0x101A39, 0x625776, 0xD8B9B6],
    [0x102F44, 0x345E72, 0x92AAAE],
    [0x26234A, 0x736586, 0xC8B8CF],
    [0x142D39, 0x46676D, 0xA8B5AA],
    [0x182C4D, 0x496180, 0xA8B1BC],
  ],
  [
    [0x89BDCE, 0xE4DDD0, 0xF6C485],
    [0x93C9CC, 0xDAEADF, 0xF4DBA1],
    [0xF0C8BA, 0xFAE4CA, 0xF9D7A2],
    [0xA9C5D0, 0xF0E9D3, 0xF5D292],
    [0xA2C8C5, 0xE1E9DB, 0xE8C78B],
  ],
  [
    [0xB9DAE9, 0xE8F2EF, 0xFAF1D9],
    [0xC3DED6, 0xE8F2E8, 0xF6EDD7],
    [0xD7E9EC, 0xF7F6EC, 0xEAD9B9],
    [0xDBE5D4, 0xF0F1DF, 0xE8DFBD],
    [0xAED6DE, 0xE4F1EA, 0xF7EACA],
  ],
  [
    [0xC7D7CC, 0xF0E1B8, 0xEAC17A],
    [0xA8C4BF, 0xD4DDC7, 0xD9BD83],
    [0xD8C4AC, 0xF3E5CA, 0xDDB079],
    [0xC9D0B7, 0xEAE3C7, 0xD5BA7C],
    [0xBCD0C3, 0xE9DDB8, 0xD6AB6C],
  ],
  [
    [0x4B3C69, 0xAD7483, 0xF1BB8B],
    [0x233B51, 0x826D80, 0xD5A18A],
    [0x68496B, 0xC28A98, 0xE5B5A0],
    [0x3A3F57, 0x8A7681, 0xD9B08D],
    [0x4D3B63, 0xB47D83, 0xF0BC86],
  ],
  [
    [0x071A28, 0x14364B, 0x36586A],
    [0x071F23, 0x123D3A, 0x39615A],
    [0x14172E, 0x30334E, 0x575A72],
    [0x101F31, 0x243B4C, 0x485B68],
    [0x082B30, 0x16464C, 0x3D6664],
  ],
];
