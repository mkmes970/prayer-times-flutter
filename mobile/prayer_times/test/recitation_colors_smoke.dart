import 'dart:io';
import 'package:prayer_times/models/recitation_colors.dart';

void check(bool value, String label) {
  if (!value) throw StateError(label);
}
void main() {
  const text = 'عن عمر قال: قال رسول الله ﷺ: «إنما الأعمال بالنيات»';
  final parts = recitationParts(text);
  check(!parts.first.recitation && parts.last.recitation, 'Narrator black, quoted speech red');
  check(parts.map((part) => part.text).join() == text, 'Complete hadith preserved');
  final plain = recitationParts('عن عبد الله قال: قال رسول الله صلى الله عليه وسلم: من صمت نجا.');
  check(plain.last.recitation && plain.last.text.trim() == 'من صمت نجا.', 'Unquoted speech red');
  final source = File('mobile/prayer_times/assets/data/evening-adhkar.txt').readAsStringSync();
  for (final text in source.trim().split(RegExp(r'\n\s*\n'))) {
    final segments = recitationParts(text, evening: true);
    check(segments.map((part) => part.text).join() == text, 'Evening text unchanged');
    check(segments.first.recitation, 'Recitation red');
    for (final part in segments) {
      if (RegExp(r'^(من |لم يضره|كانت له|حُطَّتْ)').hasMatch(part.text.trimLeft())) {
        check(!part.recitation, 'Reward black');
      }
    }
  }
  stdout.writeln('Native hadith narrator/body colors, evening rewards and text preservation passed.');
}
