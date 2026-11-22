import 'prayer_schedule.dart';

/// Refresh only the former bundled second-Fajr values, never user-edited times.
PrayerRegion correctHawd6Fajr(PrayerRegion saved, PrayerRegion bundled) {
  if (bundled.name != 'مواقيت الصلاة لقرية حوض 6' || saved.id != bundled.id) {
    return saved;
  }
  var changed = false;
  final annualDays = {...saved.annualDays};
  for (final entry in bundled.annualDays.entries) {
    if (int.parse(entry.key.substring(0, 2)) > 6) continue;
    final current = annualDays[entry.key];
    if (current == null) continue;
    // Before this source correction, the bundled second Fajr was always
    // fifteen minutes after the unchanged, user-defined first Fajr.
    final former = PrayerTimes.parseTimeMinutes(entry.value['fajrFirst']!) + 15;
    if (PrayerTimes.parseTimeMinutes(current['fajrSecond']!) != former ||
        current['fajrSecond'] == entry.value['fajrSecond']) {
      continue;
    }
    annualDays[entry.key] = PrayerTimes({
      ...current.values,
      'fajrSecond': entry.value['fajrSecond']!,
    });
    changed = true;
  }
  return changed ? PrayerRegion(
    id: saved.id, name: saved.name, days: saved.days, annualDays: annualDays,
  ) : saved;
}
