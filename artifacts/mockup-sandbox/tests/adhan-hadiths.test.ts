import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { adhanHadithAt, adhanWindowEnd } from "../src/components/mockups/prayer-themes/adhan-hadiths.ts";
import { adhanDurationSeconds as hadithDurationSeconds, normalInformationSeconds } from "../src/components/mockups/prayer-themes/hadith-timing.ts";
import { HadithRotation } from "../src/components/mockups/prayer-themes/hadith-rotation.ts";
import { baghdadDay, emptyBrowserSettings, prayerDashboard, regionOptions } from "../src/components/mockups/prayer-themes/browser-prayer-schedule.ts";
const { entries } = JSON.parse(readFileSync("../../mobile/prayer_times/assets/data/adhan-hadiths.json", "utf8"));
assert.equal(entries.length, 9);
assert.deepEqual(entries.map((entry: { number: number }) => entry.number), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
const explanations = JSON.parse(readFileSync("../../mobile/prayer_times/assets/data/adhan-explanations.json", "utf8")).entries;
assert.equal(explanations.length, 10);
assert.deepEqual(explanations.map((entry: { number: number }) => entry.number), [1,2,3,4,5,6,7,8,9,10]);
assert.equal(normalInformationSeconds, 5, "Dashboard pauses are five seconds at all times");
const pause = 5000;
for (const region of regionOptions) {
  for (const date of ["2026-10-15T12:00:00+03:00", "2026-10-16T12:00:00+03:00", "2026-03-06T12:00:00+03:00"]) {
    const day = new Date(date);
    const settings = { ...emptyBrowserSettings, regionId: region.id };
    const times = prayerDashboard(day, settings).times!;
    const adhanTimes = Object.entries(times).filter(([id]) => id !== "sunrise")
      .map(([, minutes]) => baghdadDay(day).start + minutes * 60000);
    assert.equal(adhanTimes.length, 6, "Include both Fajr adhans, never sunrise");
    for (const at of adhanTimes) {
      const start = at - 300000;
      assert.equal(adhanWindowEnd(start - 1, adhanTimes), null);
      assert.equal(adhanWindowEnd(start, adhanTimes), at);
      assert.equal(adhanWindowEnd(at - 1, adhanTimes), at);
      assert.equal(adhanWindowEnd(at, adhanTimes), null);
      let elapsed = 0;
      for (const entry of entries) {
        assert.equal(adhanHadithAt(entries, start + elapsed, at), null);
        assert.equal(adhanHadithAt(entries, start + elapsed + pause - 1, at), null);
        assert.equal(adhanHadithAt(entries, start + elapsed + pause, at), entry);
        elapsed += pause + hadithDurationSeconds(entry) * 1000;
        assert.equal(adhanHadithAt(entries, start + elapsed - 1, at), entry);
      }
      assert.ok(elapsed < 300000, "All six can display within the window");
      assert.equal(adhanHadithAt(entries, start + elapsed + pause, at), entries[0], "Repeat after all six");
      assert.equal(adhanHadithAt(entries, at, at), null);
      // Existing final 30-second countdown and adhan must keep priority.
      if (at !== baghdadDay(day).start + times.fajrFirst * 60000) {
        assert.equal(prayerDashboard(new Date(at - 1000), settings).alert?.kind, "countdown");
        const fridayNoon = baghdadDay(day).weekday === 5 &&
          at === baghdadDay(day).start + times.dhuhr * 60000;
        assert.equal(prayerDashboard(new Date(at), settings).alert?.kind,
          fridayNoon ? "khutbah" : "announcement");
      }
    }
    const sunrise = baghdadDay(day).start + times.sunrise * 60000;
    assert.equal(adhanWindowEnd(sunrise - 300000, adhanTimes), null);
  }
}
assert.equal(adhanWindowEnd(Date.now(), []), null);
assert.equal(adhanHadithAt(entries, 0, null), null);
const scheduled = [...explanations, ...entries];
// Longer reading times must not extend the five-minute window or delay prayer alerts.
for (const entry of explanations) {
  const duration = hadithDurationSeconds(entry);
  assert.ok(duration >= 15 && duration <= 50 && duration % 5 === 0);
}
const end = 1000000;
let offset = 0;
for (const entry of scheduled) {
  if (offset + pause >= 300000) break;
  assert.equal(adhanHadithAt(scheduled, end - 300000 + offset, end), null);
  assert.equal(adhanHadithAt(scheduled, end - 300000 + offset + pause - 1, end), null);
  assert.equal(adhanHadithAt(scheduled, end - 300000 + offset + pause, end), entry);
  offset += pause + hadithDurationSeconds(entry) * 1000;
}
assert.equal(adhanHadithAt(scheduled, end, end), null);
assert.equal(scheduled.length, 19);
const base = readFileSync("../mockup-sandbox/src/components/mockups/prayer-themes/Base.tsx", "utf8");
assert.ok(base.includes("[...adhanExplanations.entries, ...adhanCatalogue.entries]"));
const randomPool = base.slice(base.lastIndexOf("...adhanCatalogue.entries") - 300, base.lastIndexOf("...adhanCatalogue.entries") + 50);
assert.ok(!randomPool.includes("adhanExplanations"), "Scheduled-only entries must not enter random pool");
const random = new HadithRotation([], entries);
assert.equal(new Set([random.current, ...Array.from({ length: 8 }, () => random.next())]).size, 9);
console.log("Adhan collection: nine entries, regional boundaries, 15–50-second reading times, sunrise exclusion and prayer priority passed.");
