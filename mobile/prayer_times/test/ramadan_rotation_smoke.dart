import 'dart:convert';
import 'dart:io';
import 'package:prayer_times/models/hadith_rotation.dart';
import 'package:prayer_times/models/hadith_timing.dart';

void main() {
  final data = jsonDecode(File('assets/data/ramadan-hadiths.json').readAsStringSync());
  final entries = (data['entries'] as List).cast<Map<String, dynamic>>();
  if (entries.length != 75) throw StateError('Expected 75 supplied entries.');
  for (final friday in [false, true]) {
    final rotation = HadithRotation(
      ordered: [{'text': 'other'}],
      randomHadiths: [],
      fridayHadiths: [{'text': 'friday'}],
      ramadanHadiths: entries,
    )..setFridayMode(friday)..setRamadanMode(true);
    var special = 0;
    var general = 0;
    for (var i = 0; i < 1000; i++) {
      final seconds = hadithDurationSeconds(rotation.current.values.whereType<String>());
      if (rotation.currentIsGeneral) {
        general += seconds;
      } else {
        special += seconds;
      }
      rotation.advance();
    }
    final target = friday ? .75 : .60;
    if ((special - (special + general) * target).abs() > 60) {
      throw StateError('Incorrect reading-time mix: $special / $general');
    }
    if (friday) {
      rotation.setFridayMode(false);
      if (!rotation.toJson()['shares'].containsKey('ramadan')) {
        throw StateError('Ramadan must resume after Friday window');
      }
    }
  }
  stdout.writeln('Ramadan: 75 supplied entries, 60/40 time mix, Friday 75/25 override passed.');
}
