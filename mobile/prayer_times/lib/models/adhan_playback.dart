import 'hadith_timing.dart';

/// Only completed, visibly displayed readings advance the persistent cursor.
class AdhanPlayback {
  AdhanPlayback([this.index = 0]);
  int index;
  DateTime? _window;
  DateTime? _lastAt;
  int _elapsed = 0;
  bool _paused = true;

  Map<String, dynamic>? at(List<Map<String, dynamic>> entries, DateTime now,
      DateTime? end, {bool blocked = false}) {
    final active = end != null && !now.isBefore(end.subtract(const Duration(minutes: 5))) &&
        now.isBefore(end) && entries.isNotEmpty;
    final gap = _lastAt == null ? 999999 : now.difference(_lastAt!).inMilliseconds;
    if (!active || _paused || _window != end || gap < 0 || gap > 2500) {
      _elapsed = 0;
    } else {
      _elapsed += gap;
    }
    _lastAt = now;
    _window = end;
    _paused = !active || blocked;
    if (!active) return null;
    index %= entries.length;
    const pause = normalInformationSeconds * 1000;
    int duration() => pause +
        adhanDurationSeconds(entries[index].values.whereType<String>()) * 1000;
    while (_elapsed >= duration()) {
      _elapsed -= duration();
      index = (index + 1) % entries.length;
    }
    if (blocked) {
      _elapsed = 0;
      return null;
    }
    return _elapsed < pause ? null : entries[index];
  }
}
