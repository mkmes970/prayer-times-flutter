import 'dart:convert';
import 'english_digits.dart';

String stretchAdhkarText(String text, {bool isQuran = false}) {
  text = englishDigits(text);
  text = text.replaceAll(RegExp(r'[\u0610-\u061a\u064b-\u0652\u0656-\u065f\u0670\u06d6-\u06ed]'), '');
  if (isQuran) return text;
  return text.replaceAllMapped(
    RegExp(r'[\u0621-\u063a\u0641-\u064a\u064b-\u065f\u0670]+'), (match) {
      final word = match[0]!;
      final plain = word.replaceAll(RegExp(r'[\u064b-\u065f\u0670]'), '');
      if (plain.contains('الله')) return word;
      final letters = RegExp(r'[\u0621-\u063a\u0641-\u064a][\u064b-\u065f\u0670]*')
          .allMatches(word).map((m) => m[0]!).toList();
      return List.generate(letters.length, (index) {
        final letter = letters[index];
        final next = index + 1 < letters.length ? letters[index + 1][0] : '';
        final connects = next.isNotEmpty && !'ءآأؤإاةدذرزوَى'.contains(letter[0]) && next != 'ء';
        final lamAlif = letter[0] == 'ل' && next.isNotEmpty && 'اأإآ'.contains(next);
        return '$letter${connects && !lamAlif ? 'ـ' : ''}';
      }).join();
    });
}

class DhikrPage {
  const DhikrPage({
    required this.id,
    required this.title,
    required this.text,
    required this.note,
    required this.weight,
    this.boardText,
  });

  final String id;
  final String title;
  final String text;
  final String note;
  final int weight;
  final String? boardText;

  bool get showDetails =>
      boardText != null || id == 'tahlil-ten' || id == 'fajr-dua';
  String get displayText =>
      '${showDetails ? '$title: ' : ''}${boardText ?? text}';
  String get displayNote => showDetails
      ? '(${boardText != null ? 'تُقرأ كاملة — ' : ''}$note)'
      : '';
  int get boardWeight {
    final value = '${boardText ?? text}${showDetails ? '$title$note' : ''}';
    return value.replaceAll(RegExp(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]'), '').length +
        35 + '\n'.allMatches(value).length * 20;
  }
}

List<DhikrPage> adhkarForPrayer(String source, String prayerId) {
  final catalogue = jsonDecode(source) as Map<String, dynamic>;
  final special = prayerId == 'fajrSecond' || prayerId == 'maghrib';
  return (catalogue['entries'] as List)
      .cast<Map<String, dynamic>>()
      .where((entry) =>
          entry['prayers'] == null || (entry['prayers'] as List).contains(prayerId))
      .map((entry) {
        final repeated = special && entry['fajrMaghribNote'] != null;
        return DhikrPage(
          id: entry['id'] as String,
          title: entry['title'] as String,
          text: entry['text'] as String,
          note: (repeated ? entry['fajrMaghribNote'] : entry['note']) as String,
          weight: (entry['weight'] as int) * (repeated ? 3 : 1),
          boardText: entry['boardText'] as String?,
        );
      }).toList(growable: false);
}

List<List<DhikrPage>> adhkarBoardColumns(List<DhikrPage> pages) {
  const order = [
    'istighfar-salam', 'la-hawla', 'la-mania', 'tasbih',
    'tahlil-ten', 'ayat-kursi', 'ikhlas', 'falaq', 'nas', 'fajr-dua',
  ];
  final sorted = [
    for (final id in order) ...pages.where((page) => page.id == id),
  ];
  final total = sorted.fold<int>(0, (sum, page) => sum + page.boardWeight);
  var before = 0, split = 1;
  var best = double.infinity;
  for (var index = 1; index < sorted.length; index++) {
    before += sorted[index - 1].boardWeight;
    final difference = (total - before * 2).abs().toDouble();
    if (difference < best) {
      best = difference;
      split = index;
    }
  }
  return [sorted.sublist(0, split), sorted.sublist(split)];
}
