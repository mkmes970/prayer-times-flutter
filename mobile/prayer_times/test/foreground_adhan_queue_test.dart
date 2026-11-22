import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/foreground_adhan_queue.dart';

Map<String, Object> event(String prayer, String date, int hour, int minute,
        [int second = 0]) =>
    {'prayerId': prayer, 'date': date, 'hour': hour, 'minute': minute,
      'second': second};

void main() {
  test('plays once at real device deadline, including corrected seconds', () {
    final queue = ForegroundAdhanQueue()
      ..update([event('dhuhr', '2026-11-01', 11, 59, 45)]);
    expect(queue.takeDue(DateTime(2026, 11, 1, 11, 59, 44), visible: true), false);
    expect(queue.takeDue(DateTime(2026, 11, 1, 11, 59, 45), visible: true), true);
    expect(queue.takeDue(DateTime(2026, 11, 1, 11, 59, 46), visible: true), false);
    queue.update([event('dhuhr', '2026-11-01', 11, 59, 45)]);
    expect(queue.takeDue(DateTime(2026, 11, 1, 11, 59, 47), visible: true), false);
  });

  test('a suspended or hidden page never replays a missed prayer', () {
    final queue = ForegroundAdhanQueue()
      ..update([event('asr', '2026-11-01', 15, 0)]);
    expect(queue.takeDue(DateTime(2026, 11, 1, 15), visible: false), false);
    expect(queue.takeDue(DateTime(2026, 11, 1, 15, 0, 1), visible: true), false);
    queue.update([event('maghrib', '2026-11-01', 17, 0)]);
    expect(queue.takeDue(DateTime(2026, 11, 1, 18), visible: true), false);
  });

  test('allows normal short timer drift but not late catch-up', () {
    for (final seconds in [1, 5, 6, 60]) {
      final queue = ForegroundAdhanQueue()
        ..update([event('fajrSecond', '2026-11-01', 5, 30)]);
      expect(queue.takeDue(DateTime(2026, 11, 1, 5, 30, seconds),
          visible: true), seconds <= 5);
    }
  });

  test('updated region and muted prayers replace the previous schedule', () {
    final queue = ForegroundAdhanQueue()
      ..update([event('dhuhr', '2026-11-01', 12, 0)]);
    queue.update([event('dhuhr', '2026-11-01', 12, 10)]);
    expect(queue.takeDue(DateTime(2026, 11, 1, 12), visible: true), false);
    expect(queue.takeDue(DateTime(2026, 11, 1, 12, 10), visible: true), true);
    queue.update([]);
    expect(queue.takeDue(DateTime(2026, 11, 1, 12, 10, 1), visible: true), false);
  });

  test('a new date and corrected midnight deadline are independent', () {
    final queue = ForegroundAdhanQueue()
      ..update([
        event('isha', '2026-11-01', 23, 59, 50),
        event('fajrSecond', '2026-11-02', 5, 0),
      ]);
    expect(queue.takeDue(DateTime(2026, 11, 1, 23, 59, 50), visible: true), true);
    expect(queue.takeDue(DateTime(2026, 11, 2, 5), visible: true), true);
  });
}
