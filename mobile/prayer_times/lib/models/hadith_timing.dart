const normalInformationSeconds = 10;

/// Count the complete displayed text, without counting vocalization marks.
int hadithDurationSeconds(Iterable<String> parts) {
  return _readingDuration(parts, 20, 60);
}

int adhanDurationSeconds(Iterable<String> parts) {
  return _readingDuration(parts, 15, 50);
}

int _readingDuration(Iterable<String> parts, int minimum, int maximum) {
  final plain = parts.join(' ').replaceAll(
        RegExp(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]'),
        '',
      );
  final letters = RegExp(r'[A-Za-z0-9\u0621-\u064a\u0660-\u0669]');
  final characters = letters.allMatches(plain).length;
  final band =
      ((characters + 149) ~/ 150 - 1).clamp(0, (maximum - minimum) ~/ 5);
  return minimum + band * 5;
}
