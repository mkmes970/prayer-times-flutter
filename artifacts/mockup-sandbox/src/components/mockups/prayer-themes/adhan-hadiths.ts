import { adhanDurationSeconds } from "./hadith-timing.ts";
import type { HadithEntry } from "./hadith-rotation.ts";

// Only adhan slots are supplied by the caller; sunrise is not an adhan.
export function adhanWindowEnd(now: number, adhanTimes: number[]): number | null {
  const next = adhanTimes.filter(at => Number.isFinite(at) && at > now && at - now <= 5 * 60000);
  return next.length ? Math.min(...next) : null;
}

// Clock-anchored playback resumes correctly after a refresh or background pause.
export function adhanHadithAt(entries: HadithEntry[], now: number, endsAt: number | null): HadithEntry | null {
  if (endsAt === null || now < endsAt - 5 * 60000 || now >= endsAt || !entries.length) return null;
  const pause = 5 * 1000;
  const durations = entries.map(entry => pause + adhanDurationSeconds(entry) * 1000);
  let elapsed = (now - (endsAt - 5 * 60000)) % durations.reduce((sum, duration) => sum + duration, 0);
  for (let index = 0; index < entries.length; index++) {
    if (elapsed < pause) return null;
    if (elapsed < durations[index]) return entries[index];
    elapsed -= durations[index];
  }
  return null;
}
