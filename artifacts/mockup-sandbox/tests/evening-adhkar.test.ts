import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { eveningItemAt, eveningPlaylist, eveningWindowActive, parseEveningAdhkar } from "../src/components/mockups/prayer-themes/evening-adhkar.ts";
import { hadithDurationSeconds, normalInformationSeconds } from "../src/components/mockups/prayer-themes/hadith-timing.ts";
import { HadithRotation } from "../src/components/mockups/prayer-themes/hadith-rotation.ts";
import { prayerDashboard, emptyBrowserSettings, regionOptions, baghdadDay } from "../src/components/mockups/prayer-themes/browser-prayer-schedule.ts";

const source = readFileSync("../../mobile/prayer_times/assets/data/evening-adhkar.txt", "utf8");
const entries = parseEveningAdhkar(source);
assert.equal(entries.length, 26);
const upload = readFileSync("../../attached_assets/Pasted-1--1791988159044_1791988159050.txt", "utf8");
const original = upload.split(/^\d+\.\s*$/m).slice(1).map(block =>
  block.replace(/\s*\[[^\]]+\]\./g, "").trim());
const normalize = (text: string) => text.replace(/\s+/g, " ").trim();
assert.deepEqual(entries.map(entry => normalize(entry.text)), original.map(normalize),
  "Keep every supplied recitation and merit explanation in order; exclude only numbering and citations");
assert.equal(normalInformationSeconds, 5);
for (const [letters, seconds] of [[1, 20], [151, 25], [301, 30], [451, 35], [601, 40], [751, 45], [901, 50], [1051, 55], [1201, 60], [2000, 60]]) {
  assert.equal(hadithDurationSeconds({ text: "س".repeat(letters) }), seconds);
}
const pool = Array.from({ length: 80 }, (_, i) => ({ text: `حديث مسائي ${i}`, number: i }));
const items = eveningPlaylist(source, pool, 1792100000);
assert.equal(items.length, 36);
assert.deepEqual(items.filter(item => item.recitation).map(item => normalize(item.entry.text!)),
  entries.map(entry => normalize(entry.text)));
assert.equal(items.filter(item => !item.recitation).length, 10);
for (let index = 0; index < items.length; index++) {
  assert.equal(items[index].recitation, index % 7 < 5 || index === items.length - 1);
}
const pause = 5000;
const durations = items.map(item => (hadithDurationSeconds(item.entry) + 5) * 1000);
const cycle = durations.reduce((sum, duration) => sum + duration, 0);
for (const region of regionOptions) {
  // A weekday and Friday: the same regional timing rule applies to both.
  for (const date of ["2026-10-14T12:00:00+03:00", "2026-10-16T12:00:00+03:00"]) {
    const now = new Date(date);
    const settings = { ...emptyBrowserSettings, regionId: region.id };
    const schedule = prayerDashboard(now, settings);
    const maghrib = baghdadDay(now).start + schedule.times!.maghrib * 60000;
    const end = maghrib + (settings.iqamaMinutes.maghrib! + settings.prayerDurationMinutes!.maghrib!) * 60000;
    const start = maghrib - 90 * 60000;
    assert.equal(eveningItemAt(items, start - 1, maghrib, end), null);
    let elapsed = 0;
    for (let index = 0; index < items.length; index++) {
      assert.equal(eveningWindowActive(start + elapsed, maghrib, end), true, "No unrelated random hadiths during the dashboard gap");
      assert.equal(eveningItemAt(items, start + elapsed, maghrib, end), null);
      assert.equal(eveningItemAt(items, start + elapsed + pause - 1, maghrib, end), null);
      assert.deepEqual(eveningItemAt(items, start + elapsed + pause, maghrib, end), items[index]);
      assert.deepEqual(eveningItemAt(items, start + elapsed + durations[index] - 1, maghrib, end), items[index]);
      elapsed += durations[index];
    }
    assert.equal(eveningItemAt(items, start + cycle, maghrib, end), null);
    assert.deepEqual(eveningItemAt(items, start + cycle + pause, maghrib, end), items[0]);
    assert.ok(eveningWindowActive(maghrib + 15000, maghrib, end), "Continue only evening cycle between adhan and iqama");
    assert.equal(eveningWindowActive(end, maghrib, end), false);
    assert.equal(eveningItemAt(items, end, maghrib, end), null);
    assert.equal(eveningItemAt(items, start, null, end), null);
    assert.equal(prayerDashboard(new Date(maghrib - 1000), settings).alert?.kind, "countdown");
    assert.equal(prayerDashboard(new Date(maghrib), settings).alert?.kind, "announcement");
    assert.equal(prayerDashboard(new Date(maghrib + settings.iqamaMinutes.maghrib! * 60000 + 46000), settings).alert?.kind, "blackout");
    assert.equal(prayerDashboard(new Date(end), settings).alert?.kind, "dhikr");
  }
}
const fridayEntry = { text: "Friday" }, other = { text: "Other" };
const rotation = new HadithRotation([other], Array.from({ length: 4 }, (_, i) => ({text:`general${i}`})), [fridayEntry]);
rotation.setFridayMode(true);
const counts = [rotation.current, ...Array.from({ length: 99 }, () => rotation.next())].filter(entry => entry === fridayEntry).length;
assert.equal(counts, 60, "Friday schedule is 3 Friday hadiths per 2 general hadiths");
console.log("Evening: 5 recitations then 2 hadiths, 5-second pauses, sequence and boundaries; Friday 3:2 schedule passed.");
