import 'dart:io';
import 'package:prayer_times/models/prayer_highlight.dart';

void main() {
  final events = [
    for (final (id, hour, minute, wait, length) in [
      ('fajrSecond', 5, 0, 20, 10),
      ('dhuhr', 11, 50, 15, 8),
      ('asr', 15, 0, 15, 8),
      ('maghrib', 17, 35, 8, 7),
      ('isha', 19, 0, 15, 10),
    ])
      PrayerHighlightEvent(
        id: id,
        adhanAt: DateTime(2026, 10, 13, hour, minute),
        waitMinutes: wait,
        prayerMinutes: length,
      ),
    PrayerHighlightEvent(
      id: 'fajrSecond',
      adhanAt: DateTime(2026, 10, 14, 5),
      waitMinutes: 20,
      prayerMinutes: 10,
    ),
  ];
  for (var index = 0; index < events.length - 1; index++) {
    final event = events[index];
    for (final instant in [
      event.adhanAt.subtract(const Duration(seconds: 1)),
      event.adhanAt,
      event.endsAt.subtract(const Duration(seconds: 1)),
    ]) {
      if (highlightedPrayer(instant, events) != event.id) {
        throw StateError('Wrong highlight for ${event.id} at $instant');
      }
    }
    if (highlightedPrayer(event.endsAt, events) != events[index + 1].id) {
      throw StateError('Did not advance at ${event.endsAt}');
    }
  }
  final friday = PrayerHighlightEvent(
    id: 'dhuhr', adhanAt: DateTime(2026, 10, 16, 11, 50),
    waitMinutes: 15, prayerMinutes: 8, khutbahMinutes: 20,
  );
  if (friday.endsAt != DateTime(2026, 10, 16, 12, 10)) {
    throw StateError('Friday khutbah timing');
  }
  final midnight = PrayerHighlightEvent(
    id: 'isha', adhanAt: DateTime(2026, 10, 13, 23, 50),
    waitMinutes: 15, prayerMinutes: 10,
  );
  if (highlightedPrayer(DateTime(2026, 10, 14, 0, 14), [midnight, events.last]) != 'isha' ||
      highlightedPrayer(DateTime(2026, 10, 14, 0, 15), [midnight, events.last]) != 'fajrSecond') {
    throw StateError('Midnight continuation');
  }
  stdout.writeln('PASS: five prayers, exact end transitions, Friday khutbah, midnight.');
}
