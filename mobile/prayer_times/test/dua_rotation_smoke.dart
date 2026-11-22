// Runs without Flutter: dart mobile/prayer_times/test/dua_rotation_smoke.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:prayer_times/models/dua_rotation.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final json =
      jsonDecode(
            File.fromUri(
              Platform.script.resolve('../assets/data/dua-ticker.json'),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final catalogue = DuaCatalogue.fromJson(json);
  check(catalogue.interval == const Duration(seconds: 10), 'Exactly 10 seconds');
  check((json['supplications'] as List).length == 91, 'All 91 supplications');
  check(
    (json['independent_quotes'] as List).length == 29,
    'All 29 standalone quotes',
  );
  final authors = catalogue.groups.where((group) => group.author != null);
  check(authors.length == 6, 'All six authors');
  check(
    authors.map((group) => group.texts.length).join(',') == '5,4,1,6,5,3',
    'Preserve every quotation and its author',
  );
  const totalTexts = 144;
  check(
    catalogue.groups.fold<int>(0, (sum, group) => sum + group.texts.length) ==
        totalTexts,
    'All 144 supplied texts',
  );
  final startsAcrossSeeds = <DuaGroup>{};
  for (var seed = 0; seed < 50; seed++) {
    final rotation = DuaRotation(catalogue, random: Random(seed));
    startsAcrossSeeds.add(rotation.group);
    DuaGroup? previous;
    for (var cycle = 0; cycle < 4; cycle++) {
      final seen = <DuaGroup>{};
      var shown = 0;
      for (var block = 0; block < catalogue.groups.length; block++) {
        final group = rotation.group;
        check(!identical(group, previous), 'No immediate block repeat');
        check(seen.add(group), 'Each block occurs once in a shuffled cycle');
        for (var quote = 0; quote < group.texts.length; quote++) {
          check(identical(rotation.group, group), 'Never interrupt an author');
          check(rotation.textIndex == quote, 'Keep original quotation order');
          check(
            rotation.current == group.displayAt(quote),
            'Preserve full text',
          );
          if (group.author != null) {
            check(
              rotation.current.startsWith('قال ${group.author}: '),
              'Show the correct author on every quote, never bare وقال',
            );
          }
          shown++;
          rotation.next();
        }
        previous = group;
      }
      check(shown == totalTexts, 'No omissions in a complete cycle');
    }
  }
  check(startsAcrossSeeds.length > 1, 'Different random orders');

  final one = DuaCatalogue(
    interval: const Duration(seconds: 7),
    groups: [
      DuaGroup(['نص واحد']),
    ],
  );
  final single = DuaRotation(one);
  check(single.next() == 'نص واحد', 'Single-entry catalogue is safe');
  try {
    DuaCatalogue.fromJson({
      'interval_seconds': 7,
      'supplications': [],
      'independent_quotes': [],
      'author_groups': [],
    });
    throw StateError('An empty catalogue must fail explicitly');
  } on FormatException {
    // Expected.
  }
  stdout.writeln(
    'PASS: all 144 supplied texts, 10-second interval, 50 seeded random orders '
    'over 4 cycles each; every author uninterrupted and attributed, '
    'no omissions or immediate block repeats.',
  );
}
