import 'package:flutter/material.dart';

import '../models/prayer_schedule.dart';

enum PrayerPeriod { fajr, sunrise, dhuhr, asr, maghrib, isha }

PrayerPeriod prayerPeriodAt(DateTime now, PrayerTimes? schedule) {
  if (schedule == null) return PrayerPeriod.dhuhr;

  final minute = now.hour * 60 + now.minute;
  int minutes(String id) {
    final parts = schedule[id]!.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  if (minute >= minutes('fajrSecond') && minute < minutes('sunrise')) {
    return PrayerPeriod.fajr;
  }
  if (minute >= minutes('sunrise') && minute < minutes('dhuhr')) {
    return PrayerPeriod.sunrise;
  }
  if (minute >= minutes('dhuhr') && minute < minutes('asr')) {
    return PrayerPeriod.dhuhr;
  }
  if (minute >= minutes('asr') && minute < minutes('maghrib')) {
    return PrayerPeriod.asr;
  }
  if (minute >= minutes('maghrib') && minute < minutes('isha')) {
    return PrayerPeriod.maghrib;
  }
  return PrayerPeriod.isha;
}

class PrayerPeriodPalette {
  const PrayerPeriodPalette({
    required this.period,
    required this.skyTop,
    required this.skyMiddle,
    required this.skyBottom,
    required this.accent,
    required this.ink,
    required this.card,
    required this.rowSurface,
    required this.ribbon,
    required this.mosque,
    required this.night,
  });

  final PrayerPeriod period;
  final Color skyTop;
  final Color skyMiddle;
  final Color skyBottom;
  final Color accent;
  final Color ink;
  final Color card;
  final Color rowSurface;
  final Color ribbon;
  final Color mosque;
  final bool night;

  PrayerPeriodPalette copyWith({Color? ink}) => PrayerPeriodPalette(
        period: period,
        skyTop: skyTop,
        skyMiddle: skyMiddle,
        skyBottom: skyBottom,
        accent: accent,
        ink: ink ?? this.ink,
        card: card,
        rowSurface: rowSurface,
        ribbon: ribbon,
        mosque: mosque,
        night: night,
      );

  Color get gold => const Color(0xFFE2BC58);
  Color get softGold => const Color(0xFFF4D98B);

  static PrayerPeriodPalette forPeriod(PrayerPeriod period) {
    return switch (period) {
      PrayerPeriod.fajr => const PrayerPeriodPalette(
          period: PrayerPeriod.fajr,
          skyTop: Color(0xFF101A38),
          skyMiddle: Color(0xFF25345B),
          skyBottom: Color(0xFF9C8890),
          accent: Color(0xFFE1BD54),
          ink: Color(0xFFFFE078),
          card: Color(0xFF192A49),
          rowSurface: Color(0xFF1C2A47),
          ribbon: Color(0xFF172B48),
          mosque: Color(0xFFD3D1C3),
          night: true,
        ),
      PrayerPeriod.sunrise => const PrayerPeriodPalette(
          period: PrayerPeriod.sunrise,
          skyTop: Color(0xFFA5CBD9),
          skyMiddle: Color(0xFFDCE9E0),
          skyBottom: Color(0xFFF3E1B1),
          accent: Color(0xFFC6A454),
          ink: Color(0xFF173B2B),
          card: Color(0xFFFFF5E3),
          rowSurface: Color(0xFFFFE4AD),
          ribbon: Color(0xFF16472F),
          mosque: Color(0xFF6E714E),
          night: false,
        ),
      PrayerPeriod.dhuhr => const PrayerPeriodPalette(
          period: PrayerPeriod.dhuhr,
          skyTop: Color(0xFFF2F0DF),
          skyMiddle: Color(0xFFF2EEDB),
          skyBottom: Color(0xFFE8D9AF),
          accent: Color(0xFFBDA450),
          ink: Color(0xFF163A2B),
          card: Color(0xFFFFFAEE),
          rowSurface: Color(0xFFF1E1B8),
          ribbon: Color(0xFF184832),
          mosque: Color(0xFF71877A),
          night: false,
        ),
      PrayerPeriod.asr => const PrayerPeriodPalette(
          period: PrayerPeriod.asr,
          skyTop: Color(0xFFFFE6A2),
          skyMiddle: Color(0xFFFFCA70),
          skyBottom: Color(0xFFE6A45C),
          accent: Color(0xFFB58735),
          ink: Color(0xFF173B2B),
          card: Color(0xFFFFF2D8),
          rowSurface: Color(0xFFFFD987),
          ribbon: Color(0xFF17452F),
          mosque: Color(0xFF6F8270),
          night: false,
        ),
      PrayerPeriod.maghrib => const PrayerPeriodPalette(
          period: PrayerPeriod.maghrib,
          skyTop: Color(0xFF70436E),
          skyMiddle: Color(0xFFE77A58),
          skyBottom: Color(0xFFFFC16B),
          accent: Color(0xFFD3A64D),
          ink: Color(0xFFFFFFFF),
          card: Color(0xFFFFF3DB),
          rowSurface: Color(0xFFFFD48A),
          ribbon: Color(0xFF41214B),
          mosque: Color(0xFFCDD1B8),
          night: false,
        ),
      PrayerPeriod.isha => const PrayerPeriodPalette(
          period: PrayerPeriod.isha,
          skyTop: Color(0xFF061C19),
          skyMiddle: Color(0xFF0A3029),
          skyBottom: Color(0xFF28564B),
          accent: Color(0xFFD4AE4D),
          ink: Color(0xFFFFFFFF),
          card: Color(0xFF12372D),
          rowSurface: Color(0xFF164135),
          ribbon: Color(0xFF071C18),
          mosque: Color(0xFFBBC4B2),
          night: true,
        ),
    };
  }
}
