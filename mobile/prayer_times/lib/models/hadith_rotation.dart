import 'dart:math';

import 'hadith_deck.dart';
import 'hadith_timing.dart';

/// Session-random hadith pools, with persistent ordered recitation decks.
/// Priority: morning/evening > Friday > Ramadan > general.
class HadithRotation {
  HadithRotation({
    required this.ordered,
    required this.randomHadiths,
    this.fridayHadiths = const [],
    this.ramadanHadiths = const [],
    List<Map<String, dynamic>> morningAdhkar = const [],
    List<Map<String, dynamic>> eveningAdhkar = const [],
    Random? random,
    Map<String, dynamic>? state,
  }) {
    final rng = random ?? Random();
    final groups = {
      'general': [...ordered, ...randomHadiths, ...fridayHadiths, ...ramadanHadiths],
      'friday': fridayHadiths,
      'ramadan': ramadanHadiths,
      'morning': morningAdhkar,
      'evening': eveningAdhkar,
    };
    if (groups['general']!.isEmpty) throw ArgumentError('Hadith catalogue is empty.');
    for (final group in groups.entries) {
      _decks[group.key] = HadithDeck(group.value, rng,
        ordered: group.key == 'morning' || group.key == 'evening',
        state: group.key == 'morning' || group.key == 'evening'
          ? ((state?['decks'] as Map?)?[group.key] as Map<String, dynamic>?)
          : null);
      _shares[group.key] = HadithTimeShare.fromJson(
        (state?['shares'] as Map?)?[group.key] as Map<String, dynamic>?);
    }
    _sessions.addAll(((state?['sessions'] as Map?) ?? {}).cast<String, String>());
  }

  final List<Map<String, dynamic>> ordered;
  final List<Map<String, dynamic>> randomHadiths;
  final List<Map<String, dynamic>> fridayHadiths;
  final List<Map<String, dynamic>> ramadanHadiths;
  final Map<String, HadithDeck> _decks = {};
  final Map<String, HadithTimeShare> _shares = {};
  final Map<String, String> _sessions = {};
  bool _friday = false;
  bool _ramadan = false;
  String? _recitationMode;
  String? _selection;

  bool get isFridayMode => _friday;
  bool get currentIsFridayHadith => fridayHadiths.contains(current);
  bool get currentIsGeneral => _selectedDeck == 'general';
  bool get currentIsRecitation =>
      _selectedDeck == 'morning' || _selectedDeck == 'evening';

  String get _mode => _recitationMode ?? (_friday ? 'friday' : _ramadan ? 'ramadan' : 'general');
  int get _percentage => _mode == 'ramadan' ? 60 : 75;

  String get _selectedDeck {
    if (_selection == null) {
      final mode = _mode;
      _selection = mode != 'general' &&
          _shares[mode]!.chooseSpecial(_percentage) ? mode : 'general';
    }
    return _selection!;
  }

  Map<String, dynamic> get current => _decks[_selectedDeck]!.current;

  /// Reopening starts a fresh shuffle, never the saved hadith reading/cycle.
  /// Ordered daily adhkar and their progress are intentionally unaffected.
  void restartRandomSession() {
    for (final key in ['general', 'friday', 'ramadan']) {
      _decks[key]!.restart();
    }
    _selection = null;
  }

  void setFridayMode(bool enabled) {
    final next = enabled && fridayHadiths.isNotEmpty;
    if (_friday == next) return;
    _friday = next;
    _selection = null;
  }

  void setRamadanMode(bool enabled) {
    final next = enabled && ramadanHadiths.isNotEmpty;
    if (_ramadan == next) return;
    _ramadan = next;
    _selection = null;
  }

  void setRecitationMode(String? mode, {String? session}) {
    if (mode != null && mode != 'morning' && mode != 'evening') {
      throw ArgumentError('Invalid recitation mode');
    }
    if (mode != null && session != null && _sessions[mode] != session) {
      _sessions[mode] = session;
      _decks[mode]!.restart();
      _shares[mode] = HadithTimeShare();
      _selection = null;
    }
    if (_recitationMode == mode) return;
    _recitationMode = mode;
    _selection = null;
  }

  /// Call only after a complete, uninterrupted on-screen reading.
  void advance() {
    final deck = _selectedDeck;
    final seconds = hadithDurationSeconds(current.values.whereType<String>());
    if (_mode != 'general') _shares[_mode]!.complete(deck != 'general', seconds);
    _decks[deck]!.complete();
    _selection = null;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'decks': {
      for (final key in ['morning', 'evening']) key: _decks[key]!.toJson(),
    },
    'shares': _shares.map((key, value) => MapEntry(key, value.toJson())),
    'sessions': _sessions,
  };
}
