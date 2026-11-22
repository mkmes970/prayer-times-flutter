import 'dart:math';
import 'english_digits.dart';

/// A singleton supplication, or an uninterrupted ordered block of quotations.
class DuaGroup {
  DuaGroup(Iterable<String> texts, {this.author})
    : texts = List.unmodifiable(texts) {
    if (this.texts.isEmpty ||
        this.texts.any((text) => text.trim().isEmpty) ||
        (author != null && author!.trim().isEmpty)) {
      throw const FormatException('نصوص الشريط أو اسم القائل فارغ.');
    }
  }

  final List<String> texts;
  final String? author;

  String displayAt(int index) =>
      author == null ? texts[index] : 'قال $author: ${texts[index]}';
}

class DuaCatalogue {
  DuaCatalogue({required this.interval, required Iterable<DuaGroup> groups})
    : groups = List.unmodifiable(groups) {
    if (this.groups.isEmpty || interval <= Duration.zero) {
      throw const FormatException('قائمة الشريط أو مدة العرض غير صحيحة.');
    }
  }

  final Duration interval;
  final List<DuaGroup> groups;

  factory DuaCatalogue.fromJson(Object? value) {
    if (value is! Map || value['interval_seconds'] is! int) {
      throw const FormatException('ملف نصوص الشريط غير صحيح.');
    }
    List<String> strings(Object? value) {
      if (value is! List || value.any((text) => text is! String)) {
        throw const FormatException('نصوص الشريط يجب أن تكون قائمة نصية.');
      }
      return value.cast<String>();
    }

    final groups = <DuaGroup>[
      for (final text in strings(value['supplications'])) DuaGroup([text]),
      for (final text in strings(value['independent_quotes'])) DuaGroup([text]),
    ];
    final authors = value['author_groups'];
    if (authors is! List) {
      throw const FormatException('مجموعات المقولات غير صحيحة.');
    }
    for (final entry in authors) {
      if (entry is! Map || entry['author'] is! String) {
        throw const FormatException('اسم صاحب المقولات غير صحيح.');
      }
      groups.add(
        DuaGroup(strings(entry['texts']), author: entry['author'] as String),
      );
    }
    return DuaCatalogue(
      interval: Duration(seconds: value['interval_seconds'] as int),
      groups: groups,
    );
  }
}

/// Supports legacy author blocks and the ticker's individual-text shuffle.
/// Every selected item appears once per cycle, without a boundary repeat.
class DuaRotation {
  DuaRotation(this.catalogue, {Random? random, bool shuffleIndividualTexts = false})
    : _random = random ?? Random(),
      _groups = shuffleIndividualTexts
        ? [for (final group in catalogue.groups)
            for (var i = 0; i < group.texts.length; i++)
              DuaGroup([group.displayAt(i)])]
        : catalogue.groups {
    _startNextGroup();
  }

  final DuaCatalogue catalogue;
  final Random _random;
  final List<DuaGroup> _groups;
  final List<DuaGroup> _remaining = [];
  DuaGroup? _previousGroup;
  late DuaGroup _group;
  int _textIndex = 0;

  String get current => englishDigits(_group.displayAt(_textIndex));
  DuaGroup get group => _group;
  int get textIndex => _textIndex;

  String next() {
    if (_textIndex + 1 < _group.texts.length) {
      _textIndex++;
    } else {
      _startNextGroup();
    }
    return current;
  }

  void _startNextGroup() {
    if (_remaining.isEmpty) {
      _remaining.addAll(_groups);
      _remaining.shuffle(_random);
      if (_remaining.length > 1 && identical(_remaining.last, _previousGroup)) {
        final first = _remaining.first;
        _remaining[0] = _remaining.last;
        _remaining[_remaining.length - 1] = first;
      }
    }
    _group = _remaining.removeLast();
    _previousGroup = _group;
    _textIndex = 0;
  }
}
