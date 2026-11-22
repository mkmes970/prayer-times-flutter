import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A selected entry stays pending until its full visible reading has finished.
/// Stable content IDs preserve progress when another collection gains entries.
class HadithDeck {
  HadithDeck(this.entries, this.random, {Map<String, dynamic>? state, this.ordered = false}) {
    final occurrences = <String, int>{};
    for (final entry in entries) {
      final digest = sha256.convert(utf8.encode(jsonEncode(entry))).toString();
      final occurrence = occurrences.update(digest, (n) => n + 1, ifAbsent: () => 0);
      _byId['$digest:$occurrence'] = entry;
    }
    final savedKnown = (state?['known'] as List?)?.cast<String>().toSet() ?? {};
    final savedRemaining = (state?['remaining'] as List?)?.cast<String>() ?? [];
    _remaining.addAll(savedRemaining.where(_byId.containsKey).toSet());
    _pending = state?['pending'] as String?;
    if (!_byId.containsKey(_pending)) _pending = null;
    _last = state?['last'] as String?;
    if (state != null) {
      _remaining.addAll(_byId.keys.where((id) =>
          !savedKnown.contains(id) && !_remaining.contains(id) && id != _pending));
    }
  }

  final List<Map<String, dynamic>> entries;
  final Random random;
  final bool ordered;
  final Map<String, Map<String, dynamic>> _byId = {};
  final List<String> _remaining = [];
  String? _pending;
  String? _last;

  Map<String, dynamic> get current {
    if (_byId.isEmpty) throw StateError('Empty hadith deck');
    if (_pending == null) {
      if (_remaining.isEmpty) {
        _remaining.addAll(_byId.keys);
        if (!ordered) _remaining.shuffle(random);
        if (!ordered && _remaining.length > 1 && _remaining.first == _last) {
          final next = _remaining[1];
          _remaining[1] = _remaining[0];
          _remaining[0] = next;
        }
      }
      _pending = _remaining.removeAt(0);
    }
    return _byId[_pending]!;
  }

  void complete() {
    if (_pending == null) throw StateError('No displayed hadith to complete');
    _last = _pending;
    _pending = null;
  }

  void restart() {
    _remaining.clear();
    _pending = null;
    _last = null;
  }

  Map<String, dynamic> toJson() => {
    'known': _byId.keys.toList(),
    'remaining': _remaining,
    'pending': _pending,
    'last': _last,
  };
}

/// Balances reading seconds, not card counts; dashboard pauses are excluded.
class HadithTimeShare {
  HadithTimeShare({this.special = 0, this.general = 0});
  int special;
  int general;

  bool chooseSpecial(int percentage) =>
      special * 100 <= (special + general) * percentage;

  void complete(bool isSpecial, int seconds) {
    if (isSpecial) {
      special += seconds;
    } else {
      general += seconds;
    }
  }

  Map<String, dynamic> toJson() => {'special': special, 'general': general};

  factory HadithTimeShare.fromJson(Map<String, dynamic>? json) => HadithTimeShare(
    special: json?['special'] as int? ?? 0,
    general: json?['general'] as int? ?? 0,
  );
}
