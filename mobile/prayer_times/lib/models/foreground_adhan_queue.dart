/// Foreground-only deadlines in real device time (clock correction is already
/// applied by AdhanAlarmSchedule). Never replay old alarms after suspension.
class ForegroundAdhanQueue {
  final _played = <String>{};
  List<({String key, DateTime at})> _events = [];

  void update(List<Map<String, Object>> events) {
    _events = [
      for (final event in events)
        (
          key: '${event['prayerId']}:${event['date']}',
          at: DateTime.parse('${event['date']}T'
              '${event['hour'].toString().padLeft(2, '0')}:'
              '${event['minute'].toString().padLeft(2, '0')}:'
              '${(event['second'] ?? 0).toString().padLeft(2, '0')}'),
        ),
    ];
  }

  bool takeDue(DateTime now, {required bool visible}) {
    var due = false;
    for (final event in _events) {
      if (event.at.isAfter(now) || _played.contains(event.key)) continue;
      _played.add(event.key);
      final late = now.difference(event.at);
      if (visible && late <= const Duration(seconds: 5)) due = true;
    }
    // Only retain identities still relevant to the current schedule.
    final currentKeys = _events.map((event) => event.key).toSet();
    _played.removeWhere((key) => !currentKeys.contains(key));
    return due;
  }
}
