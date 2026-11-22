import 'hadith_timing.dart';

DateTime? adhanWindowEnd(DateTime now, List<DateTime> adhanTimes) {
  final upcoming = adhanTimes.where((at) =>
      at.isAfter(now) &&
      at.difference(now) <= const Duration(minutes: 5)).toList()..sort();
  return upcoming.isEmpty ? null : upcoming.first;
}

Map<String, dynamic>? adhanHadithAt(
  List<Map<String, dynamic>> entries, DateTime now, DateTime? endsAt,
) {
  if (endsAt == null || entries.isEmpty ||
      now.isBefore(endsAt.subtract(const Duration(minutes: 5))) ||
      !now.isBefore(endsAt)) {
    return null;
  }
  const pause = 5 * 1000;
  final durations = entries.map((entry) =>
      pause + adhanDurationSeconds(entry.values.whereType<String>()) * 1000).toList();
  var elapsed = now.difference(endsAt.subtract(const Duration(minutes: 5))).inMilliseconds %
      durations.fold<int>(0, (sum, duration) => sum + duration);
  for (var index = 0; index < entries.length; index++) {
    if (elapsed < pause) return null;
    if (elapsed < durations[index]) return entries[index];
    elapsed -= durations[index];
  }
  return null;
}
