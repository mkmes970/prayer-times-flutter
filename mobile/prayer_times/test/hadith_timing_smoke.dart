import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:prayer_times/models/hadith_timing.dart';
import 'package:prayer_times/models/hadith_rotation.dart';
import 'package:prayer_times/models/friday_hadith_window.dart';
import 'package:prayer_times/models/image_hadith_catalogue.dart';

void main() {
  void expectDuration(int characters, int expected) {
    final text = List.filled(characters, 'بَ').join(' ');
    final actual = hadithDurationSeconds([text]);
    if (actual != expected) {
      throw StateError('$characters: $actual != $expected');
    }
  }

  for (final pair in [
    [0, 20],
    [150, 20],
    [151, 25],
    [300, 25],
    [301, 30],
    [450, 30],
    [451, 35],
    [600, 35],
    [601, 40],
    [750, 40],
    [751, 45],
    [900, 45],
    [901, 50],
    [1050, 50],
    [1051, 55],
    [1200, 55],
    [1201, 60],
    [1350, 60],
    [5000, 60],
  ]) {
    expectDuration(pair[0], pair[1]);
  }
  if (normalInformationSeconds != 10) throw StateError('Information duration');
  if (hadithDurationSeconds(['«', 'مَنْ\tصَمَتَ\nنَجَا.', '»']) != 20) {
    throw StateError('Vocalization and whitespace');
  }
  final catalogue = jsonDecode(
    File(
      'mobile/prayer_times/assets/data/dashboard-hadiths.json',
    ).readAsStringSync(),
  ) as Map<String, dynamic>;
  final ordered = (catalogue['ordered'] as List<dynamic>)
      .map((entry) => (entry as Map).cast<String, dynamic>())
      .toList();
  final random = (catalogue['random'] as List<dynamic>)
      .map((entry) => (entry as Map).cast<String, dynamic>())
      .toList();
  final friday = (catalogue['friday'] as List<dynamic>)
      .map((entry) => (entry as Map).cast<String, dynamic>())
      .toList();
  final fridayAdditional = (catalogue['fridayAdditional'] as List<dynamic>)
      .map((entry) => (entry as Map).cast<String, dynamic>())
      .toList();
  final fridayEntries = [...friday, ...fridayAdditional];
  final imageData = jsonDecode(
    File('mobile/prayer_times/assets/data/daily-hadiths-from-images.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final imageHadiths = parseImageHadithCatalogue(imageData);
  if (imageHadiths.length != 200 ||
      imageHadiths.asMap().entries.any((entry) =>
          entry.value['sourceNumber'] != entry.key + 1 ||
          entry.value.containsKey('number') ||
          (entry.value['source'] as String).isEmpty) ||
      !(imageHadiths[19]['text'] as String)
          .contains('أبي مسعود عقبة بن عمرو') ||
      !(imageHadiths[34]['text'] as String).contains('من ظلم قيد شبر') ||
      !(imageHadiths[24]['text'] as String).contains('لم يشربها في الآخرة') ||
      (imageHadiths[9]['text'] as String).contains('حفظها')) {
    throw StateError(
        'Keep all image entries, narrators, sources and separate notes.');
  }
  for (final key in ['narrator', 'report', 'body', 'source', 'number']) {
    final badRows = (imageData['entries'] as List<dynamic>)
        .map((row) => List<dynamic>.from(row as List))
        .toList();
    final column =
        {'number': 0, 'narrator': 1, 'report': 2, 'body': 3, 'source': 4}[key]!;
    badRows[0][column] = key == 'number' ? 2 : '';
    var rejected = false;
    try {
      parseImageHadithCatalogue({...imageData, 'entries': badRows});
    } on FormatException {
      rejected = true;
    }
    if (!rejected) throw StateError('Invalid image $key must be rejected.');
  }
  if (random.length != 28 ||
      fridayAdditional.length != 17 ||
      fridayAdditional.any(
        (entry) =>
            (entry['text'] as String? ?? '').isEmpty ||
            entry.containsKey('number'),
      ) ||
      friday.length != 40 ||
      friday.asMap().entries.any(
            (entry) =>
                entry.value['number'] != entry.key + 1 ||
                (entry.value['text'] as String? ?? '').isEmpty,
          ) ||
      random[2]['source'] != 'رواه البخاري مختصرًا والنسائي' ||
      random[7]['source'] != 'متفق عليه' ||
      random[8]['source'] != 'رواه الإمامان البخاري ومسلم في صحيحيهما' ||
      random[9]['source'] != 'رواه البخاري (2697) ومسلم (1718).') {
    throw StateError('Hadith pools and their sources must be retained.');
  }
  final fridayTitle = catalogue['fridayTitle'] as String?;
  if (fridayTitle != 'أربعون حديثًا في الجمعة') {
    throw StateError('Friday collection title.');
  }
  if (catalogue['fridayAdditionalTitle'] != 'أحاديث يوم الجمعة' ||
      fridayAdditional[9]['source'] != 'رواه مسلم.' ||
      fridayAdditional.skip(11).any((entry) => entry.containsKey('source'))) {
    throw StateError('Preserve submitted sources without inventing citations.');
  }
  if (ordered.length != 42 ||
      ordered.asMap().entries.any(
            (entry) =>
                entry.value['number'] != entry.key + 1 ||
                (entry.value['text'] as String).isEmpty,
          )) {
    throw StateError('The numbered collection must contain 1–42 in order.');
  }
  final randomForOtherDays = [
    ...random,
    ...imageHadiths,
  ];
  if (randomForOtherDays.length != 228) {
    throw StateError(
        'Independent pool must not contain duplicate Friday copies.');
  }
  final rotation = HadithRotation(
    ordered: ordered,
    randomHadiths: randomForOtherDays,
    fridayHadiths: fridayEntries,
    random: Random(42),
  );
  final all = [...ordered, ...randomForOtherDays, ...fridayEntries];
  final seenRandom = <Map<String, dynamic>>{};
  for (var index = 0; index < all.length; index++) {
    final current = rotation.current;
    if (!all.contains(current)) {
      throw StateError('Expected an entry from the complete catalogue.');
    }
    if (!seenRandom.add(current)) {
      throw StateError('Random hadiths should not repeat within a round.');
    }
    if (rotation.currentIsFridayHadith != fridayEntries.contains(current)) {
      throw StateError('Incorrect collection identity.');
    }
    rotation.advance();
  }
  if (seenRandom.length != 327 ||
      !ordered.every(seenRandom.contains) ||
      !fridayEntries.every(seenRandom.contains)) {
    throw StateError('All collections must participate in the shuffled round.');
  }
  final seenImageNumbers = seenRandom
      .where((entry) => entry.containsKey('sourceNumber'))
      .map((entry) => entry['sourceNumber'])
      .toSet();
  if (seenImageNumbers.length != 200) {
    throw StateError(
        'Every extracted hadith must be reachable in random playback.');
  }
  rotation.setFridayMode(true);
  final fridaySeen = <Map<String, dynamic>>{};
  final othersSeen = <Map<String, dynamic>>{};
  var fridaySeconds = 0;
  var generalSeconds = 0;
  for (var slot = 0; slot < 3000; slot++) {
    final seconds =
        hadithDurationSeconds(rotation.current.values.whereType<String>());
    if (!rotation.currentIsGeneral) {
      fridaySeconds += seconds;
      fridaySeen.add(rotation.current);
    } else {
      generalSeconds += seconds;
      othersSeen.add(rotation.current);
    }
    rotation.advance();
  }
  if ((fridaySeconds - (fridaySeconds + generalSeconds) * .75).abs() > 60) {
    throw StateError(
        'Friday weighting must use 75% dedicated and 25% general reading time.');
  }
  if (fridaySeen.length != fridayEntries.length ||
      othersSeen.length != all.length) {
    throw StateError('Every entry must remain reachable in weighted playback.');
  }
  rotation.setFridayMode(false);
  if (rotation.isFridayMode) throw StateError('Normal playback must resume.');
  final fridayDate = DateTime(2026, 10, 16);
  bool fridayWindowAt(int hour, int minute) => isFridayHadithWindow(
        DateTime(
            fridayDate.year, fridayDate.month, fridayDate.day, hour, minute),
        morningEndsAt:
            DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 7),
        dhuhrAt:
            DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 12),
      );
  if (fridayDate.weekday != DateTime.friday ||
      fridayWindowAt(6, 59) ||
      !isFridayHadithWindow(
        DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 7),
        morningEndsAt:
            DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 7),
        dhuhrAt:
            DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 12),
      ) ||
      !isFridayHadithWindow(
        DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 11, 59),
        morningEndsAt:
            DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 7),
        dhuhrAt:
            DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 12),
      ) ||
      isFridayHadithWindow(
        DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 12),
        morningEndsAt:
            DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 7),
        dhuhrAt:
            DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 12),
      ) ||
      isFridayHadithWindow(
        DateTime(2026, 10, 17, 12),
      )) {
    throw StateError(
        'Friday weighting must start at sunrise and end at Dhuhr.');
  }
  final sampleDurations = [
    hadithDurationSeconds([ordered[0]['text'] as String]),
    hadithDurationSeconds([ordered[23]['text'] as String]),
    hadithDurationSeconds([ordered[41]['text'] as String]),
    ...randomForOtherDays.map(
      (entry) => hadithDurationSeconds(entry.values.whereType<String>()),
    ),
  ];
  stdout.writeln(
    'Hadith timing passed. Collection: 42 ordered entries; random extras: ${random.length}; sample durations: $sampleDurations.',
  );
}
