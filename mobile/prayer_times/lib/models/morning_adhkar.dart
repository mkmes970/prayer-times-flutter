DateTime? morningStartsAt(
    DateTime? fajrAt, int? wait, int prayerMinutes, int dhikrMinutes) {
  if (fajrAt == null || wait == null) return null;
  return fajrAt.add(Duration(minutes: wait)).add(prayerMinutes > 0
      ? Duration(minutes: prayerMinutes + dhikrMinutes)
      : Duration.zero);
}

List<Map<String, dynamic>> parseMorningAdhkar(String source) {
  final entries = source
      .trim()
      .split(RegExp(r'\r?\n\s*\r?\n'))
      .map((text) => <String, dynamic>{'text': text.trim()})
      .toList();
  if (entries.length != 30 ||
      entries.any((entry) => (entry['text'] as String).isEmpty)) {
    throw const FormatException('Invalid morning adhkar');
  }
  return entries;
}

bool morningWindowActive(DateTime? now, DateTime? start, DateTime? end) =>
    now != null &&
    start != null &&
    end != null &&
    !now.isBefore(start) &&
    now.isBefore(end);
