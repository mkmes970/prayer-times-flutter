import type { HadithEntry } from "./hadith-rotation.ts";
import { adhanDurationSeconds, normalInformationSeconds } from "./hadith-timing.ts";

export const adhanProgressKey = "prayer-adhan-progress-v1";

// Persist only the next/incomplete entry. Interrupted readings restart in full.
export class AdhanPlayback {
  index: number;
  private window: number | null = null;
  private lastAt: number | null = null;
  private elapsed = 0;
  private paused = true;

  constructor(index = 0) { this.index = index; }

  at(entries: HadithEntry[], now: number, end: number | null, blocked = false): HadithEntry | null {
    const active = end !== null && now >= end - 300000 && now < end && entries.length > 0;
    const gap = this.lastAt === null ? Infinity : now - this.lastAt;
    if (!active || this.paused || this.window !== end || gap < 0 || gap > 2500) {
      this.elapsed = 0;
    } else {
      this.elapsed += gap;
    }
    this.lastAt = now;
    this.window = end;
    this.paused = !active || blocked;
    if (!active) return null;
    this.index = ((this.index % entries.length) + entries.length) % entries.length;
    const pause = normalInformationSeconds * 1000;
    let duration = pause + adhanDurationSeconds(entries[this.index]) * 1000;
    while (this.elapsed >= duration) {
      this.elapsed -= duration;
      this.index = (this.index + 1) % entries.length;
      duration = pause + adhanDurationSeconds(entries[this.index]) * 1000;
    }
    if (blocked) { this.elapsed = 0; return null; }
    return this.elapsed < pause ? null : entries[this.index];
  }
}
