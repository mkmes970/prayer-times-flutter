import '../models/app_data.dart';
import '../models/app_settings.dart';
import 'adhan_alarm_service.dart';

/// Android reminders are independent of whether adhan audio is enabled/muted.
class PrayerReminderSchedule {
  const PrayerReminderSchedule._();

  static const leadTime = Duration(minutes: 10);

  static List<Map<String, Object>> build(
    AppData data, {
    required DateTime now,
    int horizonDays = adhanScheduleHorizonDays,
  }) {
    if (data.selectedRegion == null) return const [];
    final scheduleData = AppData(
      regions: data.regions,
      selectedRegionId: data.selectedRegionId,
      settings: data.settings.copyWith(
        adhanEnabled: true,
        adhanPrayerEnabled: defaultAdhanPrayerEnabled,
      ),
    );
    final correction = Duration(seconds: data.settings.clockOffsetSeconds);
    final events = <Map<String, Object>>[];
    for (final event in AdhanAlarmSchedule.build(
      scheduleData,
      now: now,
      horizonDays: horizonDays,
    )) {
      final date = DateTime.parse(event['date']! as String);
      final deviceAdhan = DateTime(
        date.year,
        date.month,
        date.day,
        event['hour']! as int,
        event['minute']! as int,
        (event['second'] as int?) ?? 0,
      );
      final deviceReminder = deviceAdhan.subtract(leadTime);
      if (deviceReminder.isBefore(now)) continue;
      final correctedAdhan = deviceAdhan.add(correction);
      events.add({
        // Identity is based on prayer date, not device clock correction.
        'key': '${_date(correctedAdhan)}|${event['prayerId']}',
        'prayerId': event['prayerId']!,
        'at': _dateTime(deviceReminder.add(correction)),
        'adhanAt': _dateTime(correctedAdhan),
      });
    }
    return List.unmodifiable(events);
  }

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _dateTime(DateTime date) => '${_date(date)}T'
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';
}
