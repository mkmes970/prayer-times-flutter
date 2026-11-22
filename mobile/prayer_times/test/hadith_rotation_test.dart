import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/hadith_rotation.dart';
import 'package:prayer_times/models/hadith_timing.dart';
import 'package:prayer_times/models/morning_adhkar.dart';
import 'package:prayer_times/models/evening_adhkar.dart';
import 'package:prayer_times/models/friday_hadith_window.dart';
import 'package:prayer_times/services/hadith_progress_store_native.dart';

void main() {
  final general = List.generate(
      80,
      (i) => <String, dynamic>{
            'text': 'حديث عام $i ${'ا' * (i * 20)}',
          });
  final friday = List.generate(40, (i) => <String, dynamic>{'text': 'جمعة $i'});
  final ramadan =
      List.generate(75, (i) => <String, dynamic>{'text': 'رمضان $i'});
  final morning = parseMorningAdhkar(
      File('assets/data/morning-adhkar.txt').readAsStringSync());
  final evening = parseEveningAdhkar(
      File('assets/data/evening-adhkar.txt').readAsStringSync());
  HadithRotation player({Map<String, dynamic>? state}) => HadithRotation(
        ordered: general.take(30).toList(),
        randomHadiths: general.skip(30).toList(),
        fridayHadiths: friday,
        ramadanHadiths: ramadan,
        morningAdhkar: morning,
        eveningAdhkar: evening,
        random: Random(721),
        state: state,
      );
  Map<String, dynamic> snapshot(HadithRotation rotation) =>
      jsonDecode(jsonEncode(rotation.toJson())) as Map<String, dynamic>;

  test(
      'general cycles exhaust all collections and never repeat at the boundary',
      () {
    final rotation = player();
    final all = [...general, ...friday, ...ramadan];
    Map<String, dynamic>? last;
    for (var cycle = 0; cycle < 3; cycle++) {
      final seen = <Map<String, dynamic>>{};
      for (var i = 0; i < all.length; i++) {
        final entry = rotation.current;
        if (i == 0 && last != null) expect(entry, isNot(same(last)));
        expect(seen.add(entry), isTrue);
        expect(all, contains(same(entry)));
        last = entry;
        rotation.advance();
      }
      expect(seen.length, all.length);
    }
  });

  test('disk restart ignores the previous random reading and cycle', () async {
    final directory =
        await Directory.systemTemp.createTemp('hadith-progress-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = HadithProgressStore(File('${directory.path}/progress.json'));
    final rotation = player();
    final freshFirst = rotation.current;
    rotation.advance();
    final oldPending = rotation.current;
    await store.save(rotation.toJson());
    final state = await store.load();
    expect(state!['decks'].containsKey('general'), isFalse);
    final restored = player(state: state);
    // A fixed RNG makes a fresh session reproducible in this test only.
    expect(restored.current, freshFirst);
    expect(restored.current, isNot(oldPending));
    restored.advance();
    restored.restartRandomSession();
    expect(snapshot(restored)['decks'].keys,
        unorderedEquals(['morning', 'evening']));
  });

  test('similar and exactly duplicated submissions remain separate entries',
      () {
    final first = <String, dynamic>{'text': 'رواية مكررة كما أرسلها المستخدم'};
    final second = Map<String, dynamic>.from(first);
    final rotation =
        HadithRotation(ordered: [first, second], randomHadiths: []);
    final a = rotation.current;
    rotation.advance();
    final b = rotation.current;
    expect(identical(a, b), isFalse);
    expect(a['text'], b['text']);
  });

  test('category interruptions cannot skip or restart the general cycle', () {
    var rotation = player();
    final pending = rotation.current;
    rotation.setFridayMode(true);
    for (var i = 0; i < 100; i++) {
      if (rotation.currentIsGeneral) break;
      rotation.current;
      rotation.advance();
    }
    rotation.setFridayMode(false);
    expect(rotation.current, same(pending));
  });

  for (final mode in ['morning', 'evening', 'friday', 'ramadan']) {
    test('$mode uses duration-weighted percentages with unequal length texts',
        () {
      final rotation = player();
      if (mode == 'friday') rotation.setFridayMode(true);
      if (mode == 'ramadan') rotation.setRamadanMode(true);
      if (mode == 'morning' || mode == 'evening') {
        rotation.setRecitationMode(mode, session: '2026-10-18');
      }
      var special = 0;
      var ordinary = 0;
      var orderedIndex = 0;
      final recitations = mode == 'morning' ? morning : evening;
      for (var i = 0; i < 2000; i++) {
        final seconds =
            hadithDurationSeconds(rotation.current.values.whereType<String>());
        if (rotation.currentIsGeneral) {
          ordinary += seconds;
        } else {
          special += seconds;
          if (rotation.currentIsRecitation) {
            expect(rotation.current,
                same(recitations[orderedIndex++ % recitations.length]));
          }
        }
        rotation.advance();
      }
      final target = mode == 'ramadan' ? .60 : .75;
      expect((special - (special + ordinary) * target).abs(),
          lessThanOrEqualTo(60));
      final before = snapshot(rotation)['shares'][mode];
      final restored = player(state: snapshot(rotation));
      expect(snapshot(restored)['shares'][mode], before);
    });
  }

  test(
      'morning and evening sessions resume today but restart in order tomorrow',
      () {
    for (final mode in ['morning', 'evening']) {
      var rotation = player()..setRecitationMode(mode, session: '2026-10-18');
      final entries = mode == 'morning' ? morning : evening;
      expect(rotation.current, same(entries.first));
      rotation.advance();
      final pending = rotation.current;
      rotation = player(state: snapshot(rotation))
        ..setRecitationMode(mode, session: '2026-10-18');
      expect(rotation.current, pending);
      rotation.setRecitationMode(mode, session: '2026-10-19');
      expect(rotation.current, same(entries.first));
    }
  });

  test('Friday overrides Ramadan only before Dhuhr; daily adhkar override both',
      () {
    final rotation = player()
      ..setFridayMode(true)
      ..setRamadanMode(true);
    expect(rotation.currentIsFridayHadith, isTrue);
    rotation.setRecitationMode('morning', session: '2026-10-16');
    expect(rotation.currentIsRecitation, isTrue);
    rotation.current;
    rotation.advance();
    rotation.setRecitationMode(null);
    rotation.setFridayMode(false);
    // Ramadan had no completed reading during the Friday/morning overrides.
    expect(rotation.currentIsGeneral, isFalse);
    expect(ramadan, contains(same(rotation.current)));
    final sunrise = DateTime(2026, 10, 16, 6);
    final dhuhr = DateTime(2026, 10, 16, 12);
    expect(
        isFridayHadithWindow(sunrise, morningEndsAt: sunrise, dhuhrAt: dhuhr),
        isTrue);
    expect(isFridayHadithWindow(dhuhr, morningEndsAt: sunrise, dhuhrAt: dhuhr),
        isFalse);
    expect(
        eveningWindowActive(DateTime(2026, 10, 16, 16, 40),
            DateTime(2026, 10, 16, 18), DateTime(2026, 10, 16, 17, 55)),
        isTrue);
  });

  test('new sessions include every catalogue entry including new additions',
      () {
    final rotation = player();
    rotation.current;
    rotation.advance();
    final state = snapshot(rotation);
    final extra = <String, dynamic>{'text': 'حديث جديد مستقل'};
    final updated = HadithRotation(
      ordered: [...general.take(30)],
      randomHadiths: [...general.skip(30), extra],
      fridayHadiths: friday,
      ramadanHadiths: ramadan,
      state: state,
    );
    final remaining = <Map<String, dynamic>>{};
    for (var i = 0;
        i < general.length + friday.length + ramadan.length + 1;
        i++) {
      expect(remaining.add(updated.current), isTrue);
      updated.advance();
    }
    expect(remaining, contains(same(extra)));
  });
}
