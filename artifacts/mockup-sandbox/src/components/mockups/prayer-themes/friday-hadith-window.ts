export function fridayHadithWindowActive(
  now: number, weekday: number, morningEndsAt: number | null, ishaEndsAt: number | null,
) {
  return weekday === 5 && morningEndsAt !== null && ishaEndsAt !== null &&
    now >= morningEndsAt && now < ishaEndsAt;
}
