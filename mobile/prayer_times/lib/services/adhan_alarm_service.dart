import 'package:flutter/foundation.dart';
import 'web_adhan_player_stub.dart'
    if (dart.library.html) 'web_adhan_player.dart';
import 'package:flutter/services.dart';

import '../models/app_data.dart';
import '../models/prayer_schedule.dart';
import '../models/ramadan_schedule.dart';
import 'hijri_date.dart';

const adhanPrayerSlots = <PrayerSlot>[
  PrayerSlot('fajrSecond', 'الفجر', true),
  PrayerSlot('dhuhr', 'الظهر', true),
  PrayerSlot('asr', 'العصر', true),
  PrayerSlot('maghrib', 'المغرب', true),
  PrayerSlot('isha', 'العشاء', true),
];

const adhanScheduleHorizonDays = 400;

bool get supportsAdhanAlerts =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.android;

class AdhanAlarmSchedule {
  const AdhanAlarmSchedule._();

  static List<Map<String, Object>> build(
    AppData data, {
    required DateTime now,
    int horizonDays = adhanScheduleHorizonDays,
  }) {
    final settings = data.settings;
    if (!settings.adhanEnabled || data.selectedRegion == null) return const [];

    final enabledPrayerIds = adhanPrayerSlots
        .where((slot) => settings.adhanPrayerEnabled[slot.id] ?? true)
        .map((slot) => slot.id)
        .toSet();
    if (enabledPrayerIds.isEmpty) return const [];

    final region = regionWithRamadan(
        data.selectedRegion!,
        settings.ramadanPlans[data.selectedRegionId],
        (date) => adjustedHijriDate(date,
            manualDay: settings.hijriManualDay,
            manualMonth: settings.hijriManualMonth,
            anchorDate: settings.hijriAnchorDate,
            offsetDays: settings.hijriOffsetDays));
    final correction = Duration(seconds: settings.clockOffsetSeconds);
    final correctedNow = now.add(correction);
    final events = <Map<String, Object>>[];
    for (var offset = 0; offset < horizonDays; offset++) {
      final date = DateTime(
          correctedNow.year, correctedNow.month, correctedNow.day + offset);
      final times = region.timesFor(date);
      if (times == null) continue;

      for (final slot in adhanPrayerSlots) {
        if (!enabledPrayerIds.contains(slot.id)) continue;
        final value = times[slot.id];
        if (value == null) continue;
        final parts = value.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null ||
            hour < 0 ||
            hour > 23 ||
            minute == null ||
            minute < 0 ||
            minute > 59) {
          continue;
        }
        final alarmTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        ).subtract(correction);
        if (!alarmTime.isAfter(now)) continue;
        events.add({
          'prayerId': slot.id,
          'date': '${alarmTime.year.toString().padLeft(4, '0')}-'
              '${alarmTime.month.toString().padLeft(2, '0')}-'
              '${alarmTime.day.toString().padLeft(2, '0')}',
          'hour': alarmTime.hour,
          'minute': alarmTime.minute,
          if (alarmTime.second != 0) 'second': alarmTime.second,
        });
      }
    }
    events.sort((a, b) {
      final dateComparison = (a['date']! as String).compareTo(
        b['date']! as String,
      );
      if (dateComparison != 0) return dateComparison;
      final minuteA = (a['hour']! as int) * 60 + (a['minute']! as int);
      final minuteB = (b['hour']! as int) * 60 + (b['minute']! as int);
      return minuteA.compareTo(minuteB);
    });
    return List.unmodifiable(events);
  }
}

class AdhanAlarmService {
  AdhanAlarmService({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('com.example.prayertimes/device');

  final MethodChannel _channel;
  final _webPlayer = WebAdhanPlayer();
  ValueListenable<String?> get webStatus => _webPlayer.status;
  Future<void> previewWebAudio() => _webPlayer.preview();
  void stopWebAudio() => _webPlayer.stop();
  void disposeWebAudio() => _webPlayer.dispose();

  Future<void> synchronize(
    AppData data, {
    required bool requestPermissions,
    DateTime? now,
  }) async {
    if (!supportsAdhanAlerts) return;
    final currentTime = now ?? DateTime.now();
    if (kIsWeb) {
      _webPlayer.synchronize(
        AdhanAlarmSchedule.build(data, now: currentTime),
        enabled: data.settings.adhanEnabled,
      );
      return;
    }
    final activePrayerIds = data.settings.adhanEnabled
        ? adhanPrayerSlots
            .where((slot) => data.settings.adhanPrayerEnabled[slot.id] ?? true)
            .map((slot) => slot.id)
            .toList(growable: false)
        : const <String>[];
    final events = AdhanAlarmSchedule.build(data, now: currentTime);
    final hasActiveAlarms = data.settings.adhanEnabled &&
        activePrayerIds.isNotEmpty &&
        events.isNotEmpty;
    await _channel.invokeMethod<void>('syncAdhanSchedule', {
      'enabled': hasActiveAlarms,
      'requestPermissions': requestPermissions && hasActiveAlarms,
      'activePrayerIds': hasActiveAlarms ? activePrayerIds : const <String>[],
      'events': events,
    });
  }
}
