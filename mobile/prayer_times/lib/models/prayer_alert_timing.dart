enum PrayerAlertKind { adhanCountdown, adhanAnnouncement, iqamaCountdown }

String iqamaPrayerLabel(String prayerId, String label) =>
    prayerId == 'fajrSecond' ? 'الفجر' : label;

/// Event dates must be the date of the adhan, including for waits that cross
/// midnight. The first Fajr and sunrise are not adhan/iqama events.
class PrayerAlertEvent {
  const PrayerAlertEvent({
    required this.prayerId,
    required this.label,
    required this.adhanAt,
    this.iqamaMinutes,
  });

  final String prayerId;
  final String label;
  final DateTime adhanAt;
  final int? iqamaMinutes;
}

class PrayerAlert {
  const PrayerAlert({
    required this.kind,
    required this.label,
    required this.prayerId,
    required this.startsAt,
    required this.endsAt,
  });

  final PrayerAlertKind kind;
  final String label;
  final String prayerId;
  final DateTime startsAt;
  final DateTime endsAt;

  int secondsAt(DateTime now) {
    final remaining = endsAt.difference(now).inMicroseconds;
    return remaining <= 0
        ? 0
        : (remaining / Duration.microsecondsPerSecond).ceil();
  }
}

/// Countdowns open exactly 30 seconds before the deadline, then retain zero
/// for its one-second clock interval. Derive time from the actual deadline,
/// never from a ticking counter (including after suspension).
PrayerAlert? activePrayerAlert(
  DateTime now,
  Iterable<PrayerAlertEvent> events,
) {
  final candidates = <PrayerAlert>[];
  void add(
    PrayerAlertKind kind,
    PrayerAlertEvent event,
    String label,
    DateTime start,
    DateTime end,
  ) {
    final visibleEnd = kind == PrayerAlertKind.adhanAnnouncement
        ? end
        : end.add(const Duration(seconds: 1));
    if (!now.isBefore(start) && now.isBefore(visibleEnd)) {
      candidates.add(PrayerAlert(
        kind: kind,
        label: label,
        prayerId: event.prayerId,
        startsAt: start,
        endsAt: end,
      ));
    }
  }

  for (final event in events) {
    final fridayNoon =
        event.prayerId == 'dhuhr' && event.adhanAt.weekday == DateTime.friday;
    add(
      PrayerAlertKind.adhanCountdown,
      event,
      'الوقت المتبقي لأذان ${event.label}',
      event.adhanAt.subtract(const Duration(seconds: 30)),
      event.adhanAt,
    );
    if (!fridayNoon) {
      add(
        PrayerAlertKind.adhanAnnouncement,
        event,
        'حان موعد أذان ${event.label}',
        event.adhanAt.add(const Duration(seconds: 1)),
        event.adhanAt.add(const Duration(seconds: 16)),
      );
    }
    // The Friday exception applies to Dhuhr only, not to other prayers.
    if (fridayNoon) continue;
    final minutes = event.iqamaMinutes;
    if (minutes == null || minutes <= 0) continue;
    final iqama = event.adhanAt.add(Duration(minutes: minutes));
    add(
      PrayerAlertKind.iqamaCountdown,
      event,
      'الوقت المتبقي لإقامة الصلاة',
      iqama.subtract(const Duration(seconds: 30)),
      iqama,
    );
  }
  if (candidates.isEmpty) return null;
  // A new adhan/countdown takes priority over an older overlapping event.
  candidates.sort((a, b) => b.startsAt.compareTo(a.startsAt));
  return candidates.first;
}
