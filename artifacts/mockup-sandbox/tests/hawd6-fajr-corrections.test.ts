import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { browserRegions, emptyBrowserSettings, timesForRegion, decodePrayerTimes } from "../src/components/mockups/prayer-themes/browser-prayer-schedule.ts";

const source = JSON.parse(readFileSync("../../mobile/prayer_times/assets/data/hawd6-prayer-times.json", "utf8"));
// Visually transcribed from the six user-approved photographs, in day order.
const expected = [
  "5:58 5:58 5:59 5:59 6:00 6:00 6:00 6:00 5:59 5:59 5:59 5:58 5:58 5:57 5:56 5:56 5:56 5:56 5:55 5:55 5:55 5:54 5:54 5:53 5:53 5:52 5:51 5:51 5:50 5:49 5:48",
  "5:48 5:47 5:46 5:45 5:45 5:44 5:43 5:42 5:41 5:40 5:39 5:38 5:37 5:36 5:35 5:34 5:32 5:31 5:29 5:28 5:27 5:26 5:25 5:23 5:21 5:20 5:19 5:18 5:17",
  "5:16 5:16 5:15 5:14 5:12 5:11 5:10 5:08 5:06 5:05 5:03 5:02 5:00 4:59 4:57 4:56 4:54 4:53 4:52 4:50 4:49 4:48 4:46 4:45 4:44 4:43 4:42 4:40 4:39 4:37 4:36",
  "4:35 4:34 4:33 4:31 4:30 4:28 4:26 4:25 4:23 4:22 4:21 4:19 4:18 4:17 4:15 4:14 4:12 4:11 4:10 4:09 4:08 4:06 4:05 4:04 4:02 4:01 4:00 3:58 3:57 3:56",
  "3:56 3:55 3:54 3:53 3:51 3:50 3:48 3:47 3:46 3:45 3:44 3:43 3:42 3:41 3:40 3:40 3:39 3:38 3:37 3:37 3:36 3:35 3:35 3:34 3:34 3:33 3:33 3:32 3:32 3:32 3:31",
  "3:31 3:31 3:31 3:30 3:30 3:30 3:30 3:30 3:30 3:29 3:29 3:29 3:29 3:29 3:28 3:28 3:28 3:28 3:28 3:28 3:28 3:29 3:29 3:30 3:30 3:31 3:31 3:32 3:33 3:33",
];
for (const [index, values] of expected.entries()) {
  assert.deepEqual(source.months[index].days.map((d: any) => d.fajr_second),
    values.split(" ").map(value => value.padStart(5, "0")));
}
// Fingerprint every untouched field from the original JSON, including months 7–12.
const untouched = structuredClone(source);
for (const month of untouched.months) {
  if (month.month <= 6) for (const day of month.days) delete day.fajr_second;
}
const sorted = (value: any): any => Array.isArray(value) ? value.map(sorted)
  : value && typeof value === "object" ? Object.fromEntries(Object.keys(value).sort().map(key => [key, sorted(value[key])])) : value;
assert.equal(createHash("sha256").update(JSON.stringify(sorted(untouched))).digest("hex"),
  "3cc95a1d591f22db049b4cd69a9b2807e6e8bbf2c5a3e2682eab42152bdc37c6");
const saved = structuredClone(source);
for (const month of saved.months) for (const day of month.days) {
  if (month.month > 6) continue;
  const [h, m] = day.fajr_first.split(":").map(Number);
  const minutes = h * 60 + m + 15;
  day.fajr_second = `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
}
const settings = { ...emptyBrowserSettings, regionId: "hawd6", regions: [{ id: "hawd6", ...saved }] };
const migrated = browserRegions(settings).find(region => region.id === "hawd6")!;
assert.deepEqual(migrated.months, source.months, "Saved old bundled values also update");
assert.notDeepEqual(saved.months, source.months, "Never mutate saved inputs");
settings.regions[0].months[2].days[0].fajr_second = "05:17"; // An independent annual edit.
assert.equal(browserRegions(settings).find(region => region.id === "hawd6")!.months[2].days[0].fajr_second, "05:17");
for (const year of [2026, 2027, 2028]) for (const month of source.months) for (const day of month.days) {
  if (month.month === 2 && day.day === 29 && year !== 2028) continue;
  assert.deepEqual(timesForRegion("hawd6", new Date(Date.UTC(year, month.month - 1, day.day, 9))),
    decodePrayerTimes(day));
}
console.log("All 182 photographed Fajr values match; untouched fields fingerprint unchanged; saved copy correction and recurring lookups passed.");
