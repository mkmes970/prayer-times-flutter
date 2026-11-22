bool eveningWindowActive(DateTime now, DateTime? maghribAt, DateTime? endsAt) =>
    maghribAt != null && endsAt != null &&
    !now.isBefore(maghribAt.subtract(const Duration(minutes: 80))) &&
    now.isBefore(maghribAt.subtract(const Duration(minutes: 5)));

List<Map<String, dynamic>> parseEveningAdhkar(String source) {
  final entries = source.trim().split(RegExp(r'\r?\n\s*\r?\n'))
      .map((text) => <String, dynamic>{'text': text.trim()}).toList();
  if (entries.length != 26 || entries.any((entry) => (entry['text'] as String).isEmpty)) {
    throw const FormatException('Invalid evening adhkar catalogue');
  }
  return entries;
}
