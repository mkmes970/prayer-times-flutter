import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/adhan_playback.dart';
import 'package:prayer_times/models/hadith_timing.dart';
import 'package:prayer_times/services/adhan_progress_store_native.dart';

void check(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  test('Adhan playback timing, persistence and complete sequence',
      runAdhanPlaybackChecks);
}

Future<void> runAdhanPlaybackChecks() async {
  for (final pair in [
    [0, 15],
    [150, 15],
    [151, 20],
    [301, 25],
    [451, 30],
    [601, 35],
    [751, 40],
    [901, 45],
    [1051, 50],
    [5000, 50]
  ]) {
    check(adhanDurationSeconds([List.filled(pair[0], 'بَ').join()]) == pair[1],
        'Adhan duration ${pair[0]}');
  }
  check(hadithDurationSeconds([List.filled(5000, 'ب').join()]) == 60,
      'Normal maximum');
  check(normalInformationSeconds == 10, 'Universal dashboard interval');
  final entries = <Map<String, dynamic>>[
    {'text': 'أول'},
    {'text': 'ثاني'},
    {'text': 'ثالث'}
  ];
  final end = DateTime(2026, 10, 16, 12);
  final start = end.subtract(const Duration(minutes: 5));
  var player = AdhanPlayback();
  for (var second = 0; second <= 34; second++) {
    final item = player.at(entries, start.add(Duration(seconds: second)), end);
    final pause = second < 10 || (second >= 25 && second < 35);
    check(item == (pause ? null : entries[second < 25 ? 0 : 1]),
        'Pause or ordered entry');
  }
  player.at(entries, start.add(const Duration(seconds: 35)), end,
      blocked: true);
  check(player.index == 1, 'Interrupted reading must restart');
  final directory = await Directory.systemTemp.createTemp('adhan-progress-');
  try {
    final store = AdhanProgressStore(File('${directory.path}/progress.json'));
    check(await store.load() == 0, 'New installation');
    await store.save(player.index);
    player = AdhanPlayback(await store.load());
    final nextEnd = end.add(const Duration(hours: 1));
    final nextStart = nextEnd.subtract(const Duration(minutes: 5));
    for (var second = 0; second <= 10; second++) {
      check(
          player.at(
                  entries, nextStart.add(Duration(seconds: second)), nextEnd) ==
              (second < 10 ? null : entries[1]),
          'Restore and replay interrupted entry');
    }
    player.at(entries, nextStart.add(const Duration(seconds: 90)), nextEnd);
    check(player.index == 1, 'No unseen background advances');
    await Future.wait([store.save(2), store.save(3)]);
    check(await store.load() == 3, 'Concurrent writes stay ordered');
    final data =
        jsonDecode(File('assets/data/adhan-hadiths.json').readAsStringSync());
    final explanations = jsonDecode(
        File('assets/data/adhan-explanations.json').readAsStringSync());
    final scheduled = [
      ...explanations['entries'] as List,
      ...data['entries'] as List
    ].cast<Map<String, dynamic>>();
    check(scheduled.length == 19, 'All nineteen entries preserved');
    player = AdhanPlayback();
    final completed = <int>[];
    for (var window = 0; window < 4; window++) {
      final until = end.add(Duration(hours: window));
      for (var second = 0; second <= 300; second++) {
        final before = player.index;
        player.at(
            scheduled,
            until
                .subtract(const Duration(minutes: 5))
                .add(Duration(seconds: second)),
            until,
            blocked: second >= 270);
        if (player.index != before) completed.add(before);
      }
      await store.save(player.index);
      player = AdhanPlayback(await store.load());
    }
    check(
        completed.length >= 19, 'All entries reachable across prayer windows');
    for (var i = 0; i < 19; i++) {
      check(completed[i] == i, 'No skipped or reordered entry');
    }
  } finally {
    await directory.delete(recursive: true);
  }
  stdout.writeln(
      'Native: 15–50 special timing, nineteen ordered entries, disk persistence, interrupted replay and background safety passed.');
}
