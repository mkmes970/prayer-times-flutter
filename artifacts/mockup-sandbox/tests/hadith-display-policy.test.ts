import assert from "node:assert/strict";
import { HadithRotation } from "../src/components/mockups/prayer-themes/hadith-rotation.ts";
import { fridayHadithWindowActive } from "../src/components/mockups/prayer-themes/friday-hadith-window.ts";
import { prayerDashboard, emptyBrowserSettings, regionOptions, baghdadDay } from "../src/components/mockups/prayer-themes/browser-prayer-schedule.ts";

const general = Array.from({ length: 17 }, (_, i) => ({ text: `general-${i}` }));
const friday = Array.from({ length: 13 }, (_, i) => ({ text: `friday-${i}` }));
const ramadan = Array.from({ length: 11 }, (_, i) => ({ text: `ramadan-${i}` }));
for (const [isFriday, isRamadan, blockSize] of [[true, false, 5], [false, true, 5], [true, true, 7]] as const) {
  const rotation = new HadithRotation(general, [], friday, ramadan);
  rotation.setFridayMode(isFriday);
  rotation.setRamadanMode(isRamadan);
  for (let block = 0; block < 100; block++) {
    const counts = { general: 0, friday: 0, ramadan: 0 };
    for (let i = 0; i < blockSize; i++) {
      const category = rotation.current.text.split("-")[0] as keyof typeof counts;
      counts[category]++;
      rotation.next();
    }
    if (isFriday && isRamadan) assert.deepEqual(counts, { general: 3, friday: 2, ramadan: 2 });
    else if (isRamadan) assert.deepEqual(counts, { general: 3, friday: 0, ramadan: 2 });
    else {
      assert.equal(counts.friday, 3);
      assert.equal(counts.general + counts.ramadan, 2);
    }
  }
  rotation.setFridayMode(false);
  rotation.setRamadanMode(false);
  const seen = new Set();
  // A mode transition can leave a partially consumed bag from earlier playback.
  for (let i = 0; i < 2 * (general.length + friday.length + ramadan.length); i++) {
    seen.add(rotation.current);
    rotation.next();
  }
  assert.equal(seen.size, general.length + friday.length + ramadan.length,
    "Normal playback must include every category without deduplicating source entries");
}
for (const region of regionOptions) {
  const date = new Date("2026-10-16T12:00:00+03:00");
  const settings = { ...emptyBrowserSettings, regionId: region.id };
  const { times } = prayerDashboard(date, settings);
  const day = baghdadDay(date);
  const start = day.start + (times!.sunrise + 10) * 60000;
  const end = day.start + (times!.isha + settings.iqamaMinutes.isha! +
    settings.prayerDurationMinutes!.isha! + settings.postPrayerDhikrMinutes!) * 60000;
  assert.equal(fridayHadithWindowActive(start - 1, day.weekday, start, end), false);
  assert.equal(fridayHadithWindowActive(start, day.weekday, start, end), true);
  assert.equal(fridayHadithWindowActive(end - 1, day.weekday, start, end), true);
  assert.equal(fridayHadithWindowActive(end, day.weekday, start, end), false);
  assert.equal(fridayHadithWindowActive(start, 4, start, end), false);
  assert.equal(fridayHadithWindowActive(start, day.weekday, null, end), false);
}
console.log("Exact 3:2 / 2:3 / 2:3:2 blocks, all-category random playback and regional Friday sunrise/Isha boundaries passed.");
