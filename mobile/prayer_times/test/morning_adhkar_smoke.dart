import 'dart:io';
import 'package:prayer_times/models/morning_adhkar.dart';
import 'package:prayer_times/models/hadith_rotation.dart';
import 'package:prayer_times/models/hadith_timing.dart';
import 'package:prayer_times/models/english_digits.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final entries = parseMorningAdhkar(
      File('assets/data/morning-adhkar.txt').readAsStringSync());
  check(entries.length == 30, 'All supplied morning texts');
  final start = DateTime(2026, 10, 16, 5, 30);
  final sunrise = DateTime(2026, 10, 16, 6, 10);
  check(
      morningStartsAt(start, 20, 10, 8) ==
          start.add(const Duration(minutes: 38)),
      'Post-prayer settings');
  check(
      morningStartsAt(start, 15, 12, 4) ==
          start.add(const Duration(minutes: 31)),
      'Custom settings');
  check(
      morningStartsAt(start, 20, 0, 8) ==
          start.add(const Duration(minutes: 20)),
      'Unset prayer duration adds no announcement delay');
  check(morningStartsAt(start, null, 10, 8) == null, 'Missing iqama');
  check(
      !morningWindowActive(
          start.subtract(const Duration(milliseconds: 1)), start, sunrise),
      'Not before post-prayer adhkar end');
  check(morningWindowActive(start, start, sunrise), 'Inclusive start');
  check(
      morningWindowActive(
          sunrise.subtract(const Duration(milliseconds: 1)), start, sunrise),
      'Until sunrise');
  check(!morningWindowActive(sunrise, start, sunrise),
      'Stop at sunrise, not ten minutes later');
  final rotation = HadithRotation(ordered: [], randomHadiths: [
    for (var i = 0; i < 100; i++) {'text': 'حديث $i'},
  ], morningAdhkar: entries)
    ..setRecitationMode('morning', session: '2026-10-16');
  var recitations = 0;
  var special = 0;
  var general = 0;
  for (var i = 0; i < 400; i++) {
    final seconds =
        hadithDurationSeconds(rotation.current.values.whereType<String>());
    if (rotation.currentIsRecitation) {
      check(identical(rotation.current, entries[recitations++ % 30]),
          'Preserve full ordered recitation sequence');
      special += seconds;
    } else {
      general += seconds;
    }
    rotation.advance();
  }
  check((special - (special + general) * .75).abs() <= 60,
      '75%/25% reading seconds, not card counts');
  check(englishDigits('١٢٣ ۴۵۶') == '123 456', 'English digits');
  check(normalInformationSeconds == 10, 'Ten-second dashboard');
  stdout.writeln(
      'Morning: 30 ordered texts, post-prayer start, sunrise end, 75/25 reading-time mix passed.');
}
