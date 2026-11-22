import { hadithDurationSeconds } from "./hadith-timing.ts";
import type { HadithEntry } from "./hadith-rotation.ts";

export function eveningWindowActive(now: number, maghribAt: number | null, endsAt: number) {
  return maghribAt !== null && now >= maghribAt - 90 * 60000 && now < endsAt;
}

export type EveningItem = { entry: HadithEntry; recitation: boolean };
export function parseEveningAdhkar(source: string): HadithEntry[] {
  const entries = source.trim().split(/\r?\n\s*\r?\n/).map(text => ({ text: text.trim() }));
  if (entries.length !== 26 || entries.some(entry => !entry.text)) throw new Error("Invalid evening adhkar catalogue");
  return entries;
}

export function eveningPlaylist(source: string, pool: HadithEntry[], seed: number): EveningItem[] {
  if (!pool.length) throw new Error("Missing evening hadith pool");
  const deck = [...pool];
  let state = seed >>> 0;
  for (let i = deck.length - 1; i > 0; i--) {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    const j = state % (i + 1);
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  const items: EveningItem[] = [];
  parseEveningAdhkar(source).forEach((entry, index) => {
    items.push({ entry, recitation: true });
    if ((index + 1) % 5 === 0) for (let n = 0; n < 2; n++) {
      items.push({ entry: deck[(((index + 1) / 5 - 1) * 2 + n) % deck.length], recitation: false });
    }
  });
  return items;
}

export function eveningItemAt(items: EveningItem[], now: number,
  maghribAt: number | null, endsAt: number): EveningItem | null {
  if (!items.length || !eveningWindowActive(now, maghribAt, endsAt) || maghribAt === null) return null;
  const start = maghribAt - 90 * 60000;
  const durations = items.map(item => (5 + hadithDurationSeconds(item.entry)) * 1000);
  const total = durations.reduce((sum, duration) => sum + duration, 0);
  let elapsed = (now - start) % total;
  for (let index = 0; index < items.length; index++) {
    if (elapsed < 5000) return null;
    if (elapsed < durations[index]) return items[index];
    elapsed -= durations[index];
  }
  return null;
}
