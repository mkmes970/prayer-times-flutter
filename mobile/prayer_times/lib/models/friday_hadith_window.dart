/// Friday weighting applies from sunrise until Dhuhr, including Ramadan.
bool isFridayHadithWindow(
  DateTime now, {
  DateTime? morningEndsAt,
  DateTime? dhuhrAt,
}) =>
    now.weekday == DateTime.friday &&
    morningEndsAt != null && dhuhrAt != null &&
    !now.isBefore(morningEndsAt) && now.isBefore(dhuhrAt);
