import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/prayer_schedule.dart';
import 'package:prayer_times/services/prayer_reminder_schedule.dart';

AppData _data({
  AppSettings settings = const AppSettings(),
  String fajr = '05:27',
  String asr = '14:40',
  bool selected = true,
}) {
  final region = PrayerRegion(id: 'test', name: 'الاختبار', days: {
    for (final day in [22, 23, 27])
      '2026-11-$day': PrayerTimes({
        'fajrFirst': '05:12',
        'fajrSecond': fajr,
        'sunrise': '06:47',
        'dhuhr': '11:55',
        'asr': asr,
        'maghrib': '16:58',
        'isha': '18:18',
      }),
  });
  return AppData(
    regions: {region.id: region},
    selectedRegionId: selected ? region.id : '',
    settings: settings,
  );
}

void main() {
  test('exactly five ten-minute reminders, even when all adhan audio is off',
      () {
    final data = _data(
        settings: const AppSettings(
      adhanEnabled: false,
      adhanPrayerEnabled: {
        'fajrSecond': false,
        'dhuhr': false,
        'asr': false,
        'maghrib': false,
        'isha': false,
      },
    ));
    final events = PrayerReminderSchedule.build(
      data,
      now: DateTime(2026, 11, 22),
      horizonDays: 1,
    );
    expect(events.map((event) => event['prayerId']),
        ['fajrSecond', 'dhuhr', 'asr', 'maghrib', 'isha']);
    expect(events.first['at'], '2026-11-22T05:17:00');
    expect(events.last['at'], '2026-11-22T18:08:00');
    for (final event in events) {
      expect(
        DateTime.parse(event['adhanAt']! as String)
            .difference(DateTime.parse(event['at']! as String)),
        const Duration(minutes: 10),
      );
    }
    expect(data.settings.adhanEnabled, isFalse);
    expect(data.settings.adhanPrayerEnabled.values, everyElement(isFalse));
    final restored = jsonDecode(jsonEncode({'reminders': events})) as Map;
    expect(restored['reminders'], events);
  });

  test('Friday Dhuhr is included, first Fajr and sunrise are excluded', () {
    final events = PrayerReminderSchedule.build(
      _data(),
      now: DateTime(2026, 11, 27),
      horizonDays: 1,
    );
    expect(DateTime(2026, 11, 27).weekday, DateTime.friday);
    expect(events.firstWhere((event) => event['prayerId'] == 'dhuhr')['at'],
        '2026-11-27T11:45:00');
    expect(events.any((e) => e['prayerId'] == 'fajrFirst'), isFalse);
    expect(events.any((e) => e['prayerId'] == 'sunrise'), isFalse);
  });

  test('no selection or missing dates produce no reminder', () {
    expect(
        PrayerReminderSchedule.build(
          _data(selected: false),
          now: DateTime(2026, 11, 22),
          horizonDays: 1,
        ),
        isEmpty);
    expect(
        PrayerReminderSchedule.build(
          _data(),
          now: DateTime(2026, 11, 24),
          horizonDays: 1,
        ),
        isEmpty);
  });

  test('missed reminders are not replayed after reopening', () {
    final events = PrayerReminderSchedule.build(
      _data(),
      now: DateTime(2026, 11, 22, 14, 31),
      horizonDays: 1,
    );
    expect(events.map((event) => event['prayerId']), ['maghrib', 'isha']);
    final boundary = PrayerReminderSchedule.build(
      _data(),
      now: DateTime(2026, 11, 22, 14, 30),
      horizonDays: 1,
    );
    expect(boundary.first['prayerId'], 'asr');
  });

  test('tomorrow early Fajr reminder is scheduled before midnight', () {
    final events = PrayerReminderSchedule.build(
      _data(fajr: '00:05'),
      now: DateTime(2026, 11, 22, 23, 50),
      horizonDays: 2,
    );
    expect(events.first['key'], '2026-11-23|fajrSecond');
    expect(events.first['at'], '2026-11-22T23:55:00');
    expect(events.first['adhanAt'], '2026-11-23T00:05:00');
  });

  test('both correction signs retain prayer identity and corrected deadline',
      () {
    for (final offset in [23, -90, 600, -600]) {
      final now = DateTime(2026, 11, 22, 14);
      final events = PrayerReminderSchedule.build(
        _data(settings: AppSettings(clockOffsetSeconds: offset)),
        now: now,
        horizonDays: 1,
      );
      final event = events.firstWhere((e) => e['prayerId'] == 'asr');
      expect(event['key'], '2026-11-22|asr');
      final correctedAt = DateTime.parse(event['at']! as String);
      expect(correctedAt, DateTime(2026, 11, 22, 14, 30));
      final deviceAt = correctedAt.subtract(Duration(seconds: offset));
      expect(deviceAt.add(Duration(seconds: offset)), correctedAt);
    }
  });

  test('changed timetable replaces the upcoming reminder time', () {
    final original = PrayerReminderSchedule.build(
      _data(),
      now: DateTime(2026, 11, 22),
      horizonDays: 1,
    ).firstWhere((event) => event['prayerId'] == 'asr');
    final edited = PrayerReminderSchedule.build(
      _data(asr: '14:47'),
      now: DateTime(2026, 11, 22),
      horizonDays: 1,
    ).firstWhere((event) => event['prayerId'] == 'asr');
    expect(original['key'], edited['key']);
    expect(original['at'], '2026-11-22T14:30:00');
    expect(edited['at'], '2026-11-22T14:37:00');
  });

  test(
      'Android wiring retains independent alarms and normal notification sound',
      () {
    const path =
        'android_template/app/src/main/kotlin/com/example/prayer_times';
    final scheduler =
        File('$path/PrayerReminderScheduler.kt').readAsStringSync();
    final notification =
        File('$path/PrayerReminderNotification.kt').readAsStringSync();
    final boot = File('$path/BootReceiver.kt').readAsStringSync();
    final manager =
        File('$path/PrayerSummaryNotificationManager.kt').readAsStringSync();
    final manifest = File('android_template/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final bootstrap = File('../../scripts/bootstrap-prayer-times-android.sh')
        .readAsStringSync();
    expect(scheduler, contains('manager.setAlarmClock('));
    expect(scheduler, contains('manager.canScheduleExactAlarms()'));
    expect(scheduler, contains('manager.setAndAllowWhileIdle('));
    expect(scheduler, contains('event.key in delivered'));
    expect(scheduler, contains('now < event.adhanAt'));
    expect(scheduler, contains('now - event.at < 60_000L'));
    expect(scheduler, contains('received.getLongExtra("version"'));
    expect(notification, contains('RingtoneManager.TYPE_NOTIFICATION'));
    expect(notification, contains('NotificationManager.IMPORTANCE_HIGH'));
    expect(notification, contains('Notification.CATEGORY_REMINDER'));
    expect(notification, isNot(contains('AdhanPlaybackService')));
    expect(notification, isNot(contains('موعد الأذان:')));
    expect(manager, contains('PrayerReminderScheduler.sync(context, config)'));
    expect(
        boot.split('PrayerReminderScheduler.scheduleNext(context)').length - 1,
        2);
    expect(manifest, contains('android:name=".PrayerReminderReceiver"'));
    for (final file in [
      'PrayerReminderScheduler',
      'PrayerReminderNotification',
      'PrayerReminderReceiver',
    ]) {
      expect(bootstrap, contains(file));
    }
  });
}
