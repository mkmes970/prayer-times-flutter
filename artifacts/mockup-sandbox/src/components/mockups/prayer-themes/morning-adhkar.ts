import { hadithDurationSeconds } from "./hadith-timing.ts";
import type { HadithEntry } from "./hadith-rotation.ts";

export type MorningItem = { entry: HadithEntry; recitation: boolean };
export function morningStartsAt(fajrAt: number | null, wait: number | undefined,
  prayerMinutes: number, dhikrMinutes: number) {
  if (fajrAt === null || wait === undefined) return null;
  // Blank prayer duration means there is only the existing 45-second announcement.
  return fajrAt + wait * 60000 +
    (prayerMinutes > 0 ? (prayerMinutes + dhikrMinutes) * 60000 : 45000);
}
export function parseMorningAdhkar(source: string) {
  const entries = source.trim().split(/\r?\n\s*\r?\n/).map(text => ({ text: text.trim() }));
  if (entries.length !== 30 || entries.some(entry => !entry.text)) throw new Error("Invalid morning adhkar");
  return entries;
}
// A daily shuffled deck is stable across ticks/reloads; similar source entries remain separate.
export function morningPlaylist(source: string, pool: HadithEntry[], seed: number): MorningItem[] {
  if (!pool.length) throw new Error("Missing morning hadith pool");
  const deck = [...pool];
  let state = seed >>> 0;
  for (let i = deck.length - 1; i > 0; i--) {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    const j = state % (i + 1);
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  const items: MorningItem[] = [];
  parseMorningAdhkar(source).forEach((entry, index) => {
    items.push({ entry, recitation: true });
    if ((index + 1) % 5 === 0) for (let n = 0; n < 3; n++) {
      items.push({ entry: deck[(((index + 1) / 5 - 1) * 3 + n) % deck.length], recitation: false });
    }
  });
  return items;
}
export function morningWindowActive(now: number, start: number | null, end: number | null) {
  return start !== null && end !== null && now >= start && now < end;
}
export function morningItemAt(items: MorningItem[], now: number, start: number | null, end: number | null) {
  if (!morningWindowActive(now, start, end) || start === null || !items.length) return null;
  const durations = items.map(item => (5 + hadithDurationSeconds(item.entry)) * 1000);
  let elapsed = (now - start) % durations.reduce((a, b) => a + b, 0);
  for (let i = 0; i < items.length; i++) {
    if (elapsed < 5000) return null;
    if (elapsed < durations[i]) return items[i];
    elapsed -= durations[i];
  }
  return null;
}
