/// The highlight follows the five obligatory prayers, not theme changes.
class PrayerHighlightEvent {
  const PrayerHighlightEvent({
    required this.id,
    required this.adhanAt,
    required this.waitMinutes,
    required this.prayerMinutes,
    this.khutbahMinutes = 20,
  });

  final String id;
  final DateTime adhanAt;
  final int? waitMinutes;
  final int prayerMinutes;
  final int khutbahMinutes;

  DateTime get endsAt {
    if (id == 'dhuhr' && adhanAt.weekday == DateTime.friday) {
      return adhanAt.add(Duration(minutes: khutbahMinutes));
    }
    if (waitMinutes == null) return adhanAt.add(const Duration(seconds: 15));
    return adhanAt.add(Duration(minutes: waitMinutes! + prayerMinutes));
  }
}

String? highlightedPrayer(DateTime now, Iterable<PrayerHighlightEvent> events) {
  final sorted = events.toList()
    ..sort((a, b) => a.adhanAt.compareTo(b.adhanAt));
  final current = sorted.where(
    (event) => !now.isBefore(event.adhanAt) && now.isBefore(event.endsAt),
  );
  if (current.isNotEmpty) return current.last.id;
  for (final event in sorted) {
    if (event.adhanAt.isAfter(now)) return event.id;
  }
  return null;
}
