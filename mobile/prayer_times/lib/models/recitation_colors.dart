class RecitationPart {
  const RecitationPart(this.text, this.recitation);
  final String text;
  final bool recitation;
}

List<RecitationPart> recitationParts(String text, {bool evening = false}) {
  if (evening) {
    return RegExp(r'[^\n]*\n|[^\n]+$').allMatches(text).map((match) {
      final line = match[0]!;
      return RecitationPart(line, !RegExp(r'^(من |لم يضره|كانت له|حُطَّتْ|مائة حسنة)').hasMatch(line.trimLeft()));
    }).toList();
  }
  final parts = <RecitationPart>[];
  var offset = 0;
  for (final match in RegExp(r'«[\s\S]*?»|\(\([\s\S]*?\)\)').allMatches(text)) {
    if (match.start > offset) parts.add(RecitationPart(text.substring(offset, match.start), false));
    parts.add(RecitationPart(match[0]!, true));
    offset = match.end;
  }
  if (parts.isNotEmpty) {
    if (offset < text.length) parts.add(RecitationPart(text.substring(offset), false));
    return parts;
  }
  final plain = StringBuffer();
  final positions = <int>[];
  for (var index = 0; index < text.length; index++) {
    if (RegExp(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]').hasMatch(text[index])) continue;
    plain.write(text[index]); positions.add(index);
  }
  final report = RegExp(r'(?:رسول الله|النبي|صلى الله عليه وسلم|ﷺ)[^:\n]{0,150}:').firstMatch(plain.toString());
  final colon = report == null ? text.indexOf(':') : positions[report.end - 1];
  if (colon >= 0) {
    return [
      RecitationPart(text.substring(0, colon + 1), false),
      RecitationPart(text.substring(colon + 1), true),
    ];
  }
  return [RecitationPart(text, !RegExp(r'^ع[َ]?ن').hasMatch(text))];
}
