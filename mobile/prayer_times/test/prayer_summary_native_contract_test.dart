import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'android_template/app/src/main/kotlin/com/example/prayer_times/'
    'PrayerSummaryNotificationManager.kt',
  ).readAsStringSync();

  test('native summary arms phase refresh before posting its countdown', () {
    expect(
      source.indexOf('scheduleRefresh(context, nextStateAt)'),
      lessThan(source.indexOf('notificationManager(context).notify(')),
    );
    expect(source, contains('alarmManager.setAlarmClock('));
    // Android 6–11 must also use an exact alarm, not the inexact fallback.
    expect(source, contains('Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||'));
    expect(source, contains('alarmManager.canScheduleExactAlarms()'));
    expect(source, contains('alarmManager.setAndAllowWhileIdle('));
  });

  test('notification instance expires at its earliest phase boundary', () {
    expect(source, contains('builder.setTimeoutAfter('));
    expect(
      source,
      contains('listOfNotNull(targetMillis, refreshAtMillis).minOrNull()'),
    );
    expect(source, contains('.coerceAtLeast(1L)'));
    expect(source, contains('if (at <= correctedNow)'));
    expect(source, contains('correctedTarget > correctedNow'));
  });
}
