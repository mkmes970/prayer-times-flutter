import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/dua_rotation.dart';
import 'package:prayer_times/models/hadith_rotation.dart';
import 'package:prayer_times/models/image_hadith_catalogue.dart';
import 'package:prayer_times/models/pdf_hadith_catalogue.dart';
import 'package:prayer_times/ui/dua_ticker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Object? read(String file) => jsonDecode(File('assets/data/$file').readAsStringSync());
  List<Map<String, dynamic>> added(int count) =>
      parsePdfHadithCatalogue(read('pdf-hadiths-$count.json'), count);

  for (final count in [100, 600]) {
    test('repairs split honorifics in the $count-hadith collection', () {
      final source = ((read('pdf-hadiths-$count.json') as Map)['entries'] as List)
          .cast<Map<String, dynamic>>();
      final corrected = added(count);
      for (var i = 0; i < source.length; i++) {
        final original = source[i]['text'] as String;
        expect(corrected[i], {
          ...source[i],
          'text': normalizeHadithText(original),
        });
      }

      int sourceCount(RegExp pattern) => source
          .where((entry) => pattern.hasMatch(entry['text'] as String))
          .length;
      expect(sourceCount(RegExp(r'عنه\s+ا')), count == 100 ? 9 : 41);
      expect(sourceCount(RegExp(r'عنه\s+م\s+ا')), count == 100 ? 0 : 88);
      expect(sourceCount(RegExp(r'عنهم\s+ا')), count == 100 ? 12 : 0);

      for (final entry in corrected) {
        final text = entry['text'] as String;
        expect(text, isNot(matches(RegExp(r'عنه\s+ا'))));
        expect(text, isNot(matches(RegExp(r'عنه\s+م\s+ا'))));
        expect(text, isNot(matches(RegExp(r'عنهم\s+ا'))));
      }
      // Normalizing must not mutate the source transcription in memory.
      expect(source.length, count);
    });
  }

  for (final count in [100, 600]) {
    test('$count complete numbered source entries retain narrators and attribution', () async {
      final entries = added(count);
      final bundled = parsePdfHadithCatalogue(jsonDecode(
        await rootBundle.loadString('assets/data/pdf-hadiths-$count.json')), count);
      expect(bundled, entries);
      for (var i = 0; i < count; i++) {
        final entry = entries[i];
        final text = entry['text'] as String;
        expect(entry['number'], i + 1);
        expect(text, matches(RegExp(r'^(عن |عبد الله)')));
        expect(text, contains('«'));
        expect(text, matches(RegExp(r'متفق عليه|البخاري|مسلم|رواه مالك')));
        expect(text, isNot(matches(RegExp('[\uE000-\uF8FF\uFFFD]'))));
        expect(text, isNot(contains('المستوى')));
        expect(text, isNot(contains('المنهج المقترح')));
        expect(entry['pages'], isNotEmpty);
      }
    });
  }

  test('1152 entries share one random pool including all similar narrations', () {
    final dashboard = read('dashboard-hadiths.json') as Map;
    List<Map<String, dynamic>> list(String key) =>
        (dashboard[key] as List).cast<Map<String, dynamic>>();
    List<Map<String, dynamic>> external(String file) =>
        ((read(file) as Map)['entries'] as List).cast<Map<String, dynamic>>();
    final rotation = HadithRotation(
      ordered: list('ordered'),
      randomHadiths: [
        ...list('random'),
        ...parseImageHadithCatalogue(
          (read('daily-hadiths-from-images.json') as Map).cast<String, dynamic>()),
        ...external('abu-hurayra-50-hadiths.json'),
        ...added(100),
        ...added(600),
      ],
      fridayHadiths: [...list('friday'), ...list('fridayAdditional')],
      ramadanHadiths: external('ramadan-hadiths.json'),
      random: Random(794),
    );
    final seen = <Map<String, dynamic>>{};
    for (var i = 0; i < 1152; i++) {
      expect(seen.add(rotation.current), isTrue);
      rotation.advance();
    }
    expect(seen.length, 1152);
    expect(seen.where((entry) => entry['pages'] is List).length, 700);
  });

  test('ticker retains every original group and adds only the 600-book', () async {
    final original = DuaCatalogue.fromJson(read('dua-ticker.json'));
    final rotation = await loadDuaRotation();
    expect(rotation.catalogue.groups.length, original.groups.length + 600);
    for (var i = 0; i < original.groups.length; i++) {
      expect(rotation.catalogue.groups[i].texts, original.groups[i].texts);
      expect(rotation.catalogue.groups[i].author, original.groups[i].author);
    }
    expect(
      rotation.catalogue.groups.skip(original.groups.length).map((g) => g.texts.single),
      added(600).map((e) => e['text']),
    );
    // The 100-book is not appended, even if it shares individual narrations.
    expect(rotation.catalogue.groups.skip(original.groups.length).length, 600);
    final expectedTexts = [
      for (final group in rotation.catalogue.groups)
        for (var i = 0; i < group.texts.length; i++) group.displayAt(i),
    ]..sort();
    final actualTexts = <String>[];
    for (var i = 0; i < 744; i++) {
      expect(rotation.group.texts.length, 1,
        reason: 'Each quotation must shuffle individually, not as an author block.');
      actualTexts.add(rotation.current);
      rotation.next();
    }
    expect(actualTexts..sort(), expectedTexts);
  });

  test('cross-page continuations include their ending and original attribution', () {
    final entries = added(600);
    final continuations = entries.where((entry) => (entry['pages'] as List).length > 1);
    expect(continuations.map((e) => e['number']),
      [519, 533, 542, 551, 560, 569, 586, 590, 597]);
    expect(entries[532]['text'], contains('فهجرته إلى ما هاجر إليه» متفق عليه'));
    expect(entries[596]['text'], contains('ليس لها ريح وطعمها مر» متفق عليه'));
    expect(entries[599]['text'], contains('وزنة عرشه، ومداد كلماته» رواه مسلم'));
    // Preserve the book's actual attribution, not the introduction's claim
    // that every entry is necessarily from the two Sahih collections.
    expect(entries[368]['text'], endsWith('رواه مالك'));
  });
}
