import 'dart:io';
import 'package:prayer_times/models/post_prayer_adhkar.dart';

void check(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  check(stretchAdhkarText('اللَّهُ اللَّهُمَّ بِاللَّهِ') == 'الله اللهم بالله', 'Allah protected from tatweel, without vowel marks');
  check(stretchAdhkarText('قُلْ هُوَ اللَّهُ أَحَدٌ', isQuran: true) == 'قل هو الله أحد', 'Quran without vowel marks or tatweel');
  check(stretchAdhkarText('لا لأ لإ لآ') == 'لا لأ لإ لآ', 'Lam alif protected');
  check(!stretchAdhkarText('الصلاة').contains('لـا'), 'No stretch inside prayer lam alif');
  check(stretchAdhkarText('سُبْحَانَ').contains('ـ'), 'Connected letters stretched');
  check(stretchAdhkarText('سُبْحَانَ').replaceAll('ـ', '') == 'سبحان', 'Letters preserved without vowel marks');
  final source = File('mobile/prayer_times/assets/data/post-prayer-adhkar.json').readAsStringSync();
  for (final prayer in ['fajrSecond', 'dhuhr', 'asr', 'maghrib', 'isha']) {
    final pages = adhkarForPrayer(source, prayer);
    final ids = pages.map((page) => page.id).toList();
    check(ids.first == 'istighfar-salam', 'Start with corrected istighfar and salam');
    check(ids.contains('tahlil-ten') == (prayer == 'fajrSecond' || prayer == 'maghrib'), 'Ten repetitions scope');
    check(ids.contains('fajr-dua') == (prayer == 'fajrSecond'), 'Fajr-only supplication scope');
    check(pages.firstWhere((page) => page.id == 'ayat-kursi').boardText ==
        '﴿ اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ﴾', 'Reference uses supplied Quran incipit');
    for (final page in pages.where((page) => ['ikhlas', 'falaq', 'nas'].contains(page.id))) {
      check(page.note == (prayer == 'fajrSecond' || prayer == 'maghrib' ? 'ثلاث مرات' : 'مرة واحدة'), 'Surah repetitions');
    }
    final columns = adhkarBoardColumns(pages);
    check(columns.length == 2, 'Two columns on one board');
    check(columns.first.first.id == 'istighfar-salam', 'Opening comes first');
    final weights = columns.map((column) =>
        column.fold<int>(0, (sum, page) => sum + page.boardWeight)).toList();
    final difference = (weights[0] - weights[1]).abs();
    final ordered = columns.expand((column) => column).toList();
    for (var split = 1; split < ordered.length; split++) {
      final first = ordered.take(split).fold<int>(0, (sum, page) => sum + page.boardWeight);
      final second = ordered.skip(split).fold<int>(0, (sum, page) => sum + page.boardWeight);
      check(difference <= (first - second).abs(), 'Balance columns by visible text');
    }
    final all = columns.expand((column) => column).toList();
    check(all.length == pages.length, 'All adhkar appear together');
    check(all.map((page) => page.id).toSet().length == pages.length, 'No duplicate adhkar');
    for (final page in all) {
      check(page.text == pages.firstWhere((original) => original.id == page.id).text,
          'Complete text preserved');
    }
  }
  stdout.writeln('Native single-board coverage, order, full texts and prayer-specific repetitions passed.');
}
