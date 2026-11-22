/// Bundled source transcriptions. Similar narrations remain separate entries.
String normalizeHadithText(String text) {
  return text
      .replaceAll(RegExp(r'عنه\s+م\s+ا(?=[ء-ي])'), 'عنهما ')
      .replaceAll(RegExp(r'عنه\s+م\s+ا'), 'عنهما')
      .replaceAll(RegExp(r'عنه\s+ا(?=[ء-ي])'), 'عنها ')
      .replaceAll(RegExp(r'عنه\s+ا'), 'عنها')
      .replaceAll(RegExp(r'عنهم\s+ا(?=[ء-ي])'), 'عنهم ')
      .replaceAll(RegExp(r'عنهم\s+ا'), 'عنهم');
}

List<Map<String, dynamic>> parsePdfHadithCatalogue(Object? value, int count) {
  if (value is! Map || value['entries'] is! List) {
    throw const FormatException('Invalid PDF hadith catalogue.');
  }
  final entries = (value['entries'] as List)
      .map((entry) => (entry as Map).cast<String, dynamic>())
      .toList();
  if (entries.length != count ||
      entries.asMap().entries.any((entry) =>
          entry.value['number'] != entry.key + 1 ||
          entry.value['text'] is! String ||
          (entry.value['text'] as String).trim().isEmpty ||
          entry.value['pages'] is! List ||
          (entry.value['pages'] as List).isEmpty)) {
    throw FormatException('Incomplete PDF hadith catalogue: expected $count.');
  }
  // Repair split honorifics from the scanned source for both the dashboard
  // and ticker. Retain every other word and all source metadata.
  return entries
      .map((entry) => <String, dynamic>{
            ...entry,
            'text': normalizeHadithText(entry['text'] as String),
          })
      .toList();
}
