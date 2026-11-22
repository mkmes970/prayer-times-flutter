import 'dart:io';
import 'package:prayer_times/models/evening_adhkar.dart';
import 'package:prayer_times/models/hadith_rotation.dart';
import 'package:prayer_times/models/hadith_timing.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final entries = parseEveningAdhkar(
    File('mobile/prayer_times/assets/data/evening-adhkar.txt').readAsStringSync());
  check(entries.length == 26, 'All supplied evening texts');
  for (final day in [14, 16]) {
    final maghrib = DateTime(2026, 10, day, 18);
    final start = DateTime(2026, 10, day, 16, 40);
    final end = DateTime(2026, 10, day, 17, 55);
    check(end.difference(start).inMinutes == 75, 'Full 75-minute window');
    check(!eveningWindowActive(start.subtract(const Duration(milliseconds: 1)), maghrib, end), 'Not before 16:40');
    check(eveningWindowActive(start, maghrib, end), 'Start at Maghrib minus 80 minutes');
    check(eveningWindowActive(end.subtract(const Duration(milliseconds: 1)), maghrib, end), 'Remain until 17:55');
    check(!eveningWindowActive(end, maghrib, end), 'Final five minutes reserved for adhan');
    check(!eveningWindowActive(maghrib, maghrib, end), 'Do not extend past Maghrib');
    check(!eveningWindowActive(start, null, end), 'No invented schedule');
  }
  final rotation = HadithRotation(ordered: [], randomHadiths: [
    for (var i = 0; i < 100; i++) {'text': 'حديث $i'},
  ], eveningAdhkar: entries)..setRecitationMode('evening', session: '2026-10-16');
  var count = 0;
  var special = 0;
  var general = 0;
  for (var i = 0; i < 400; i++) {
    final seconds = hadithDurationSeconds(rotation.current.values.whereType<String>());
    if (rotation.currentIsRecitation) {
      check(identical(rotation.current, entries[count++ % 26]), 'Preserve all recitations in order');
      special += seconds;
    } else {
      general += seconds;
    }
    rotation.advance();
  }
  check((special - (special + general) * .75).abs() <= 60, '75%/25% reading seconds');
  check(normalInformationSeconds == 10, 'Ten-second dashboard');
  stdout.writeln('Evening: ordered 26 texts, 16:40–17:55 for 18:00 Maghrib, 75/25 reading-time mix passed.');
}
