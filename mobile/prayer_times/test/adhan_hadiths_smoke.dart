import 'dart:convert';
import 'dart:io';
import 'package:prayer_times/models/adhan_hadiths.dart';
import 'package:prayer_times/models/hadith_timing.dart';
import 'package:prayer_times/models/hadith_rotation.dart';

void main() {
  final data =
      jsonDecode(File('assets/data/adhan-hadiths.json').readAsStringSync());
  final entries = (data['entries'] as List).cast<Map<String, dynamic>>();
  void check(bool value) {
    if (!value) throw StateError('Adhan playback regression');
  }

  check(entries.length == 9);
  for (final hour in [5, 6, 12, 15, 18, 20]) {
    final at = DateTime(2026, 10, 16, hour);
    final start = at.subtract(const Duration(minutes: 5));
    check(
        adhanWindowEnd(start.subtract(const Duration(milliseconds: 1)), [at]) ==
            null);
    check(adhanWindowEnd(start, [at]) == at);
    check(adhanWindowEnd(at, [at]) == null);
    var elapsed = 0;
    for (final entry in entries) {
      check(adhanHadithAt(entries, start.add(Duration(seconds: elapsed)), at) ==
          null);
      check(adhanHadithAt(
              entries, start.add(Duration(seconds: elapsed + 5)), at) ==
          entry);
      elapsed += 5 + adhanDurationSeconds(entry.values.whereType<String>());
      check(adhanHadithAt(entries,
              start.add(Duration(milliseconds: elapsed * 1000 - 1)), at) ==
          entry);
    }
    check(elapsed < 300);
    check(
        adhanHadithAt(entries, start.add(Duration(seconds: elapsed + 5)), at) ==
            entries.first);
    check(adhanHadithAt(entries, at, at) == null);
  }
  final explanationsData = jsonDecode(
      File('assets/data/adhan-explanations.json').readAsStringSync());
  final explanations =
      (explanationsData['entries'] as List).cast<Map<String, dynamic>>();
  check(explanations.length == 10);
  check(normalInformationSeconds == 10);
  final scheduled = [...explanations, ...entries];
  final end = DateTime(2026, 10, 16, 12);
  final start = end.subtract(const Duration(minutes: 5));
  var elapsed = 0;
  for (final entry in scheduled) {
    if (elapsed + 5 >= 300) break;
    check(
        adhanHadithAt(scheduled, start.add(Duration(seconds: elapsed)), end) ==
            null);
    check(adhanHadithAt(scheduled,
            start.add(Duration(milliseconds: elapsed * 1000 + 4999)), end) ==
        null);
    check(adhanHadithAt(
            scheduled, start.add(Duration(seconds: elapsed + 5)), end) ==
        entry);
    elapsed += 5 + adhanDurationSeconds(entry.values.whereType<String>());
  }
  check(adhanHadithAt(scheduled, end, end) == null);
  final rotation = HadithRotation(ordered: [], randomHadiths: entries);
  final seen = <String>{};
  for (var i = 0; i < 9; i++) {
    seen.add(rotation.current['text'] as String);
    rotation.advance();
  }
  check(seen.length == 9);
  stdout.writeln(
      'Native adhan schedule, nine entries, special reading duration and random inclusion passed.');
}
