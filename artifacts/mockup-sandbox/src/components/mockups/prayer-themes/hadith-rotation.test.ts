import assert from "node:assert/strict";
import catalogue from "../../../../../../mobile/prayer_times/assets/data/dashboard-hadiths.json";
import { HadithRotation } from "./hadith-rotation";
import { hadithDurationSeconds, normalInformationSeconds } from "./hadith-timing";
import { dailyImageHadiths, parseImageHadithCatalogue } from "./daily-hadiths";
import imageData from "../../../../../../mobile/prayer_times/assets/data/daily-hadiths-from-images.json";

assert.equal(normalInformationSeconds, 5);
assert.equal(catalogue.ordered.length, 42);
assert.deepEqual(catalogue.ordered.map((hadith) => hadith.number), Array.from({ length: 42 }, (_, i) => i + 1));
assert.equal(catalogue.random.length, 28);
assert.equal(catalogue.friday.length, 40);
assert.equal(catalogue.fridayAdditional.length, 17);
assert.equal(catalogue.fridayAdditionalTitle, "أحاديث يوم الجمعة");
assert.ok(catalogue.fridayAdditional.every((entry) => entry.text.length > 0 && !("number" in entry)));
assert.deepEqual(catalogue.friday.map((hadith) => hadith.number), Array.from({ length: 40 }, (_, i) => i + 1));
assert.equal(catalogue.random[2].source, "رواه البخاري مختصرًا والنسائي");
assert.equal(catalogue.random[7].source, "متفق عليه");
assert.equal(catalogue.random[8].source, "رواه الإمامان البخاري ومسلم في صحيحيهما");
assert.equal(catalogue.random[9].source, "رواه البخاري (2697) ومسلم (1718).");

const generalRandom = [
  ...catalogue.random,
  ...dailyImageHadiths,
];
assert.equal(generalRandom.length, 228);
assert.equal(dailyImageHadiths.length, 200);
assert.deepEqual(dailyImageHadiths.map((entry) => entry.sourceNumber),
  Array.from({ length: 200 }, (_, index) => index + 1));
assert.ok(dailyImageHadiths.every((entry) =>
  entry.number === undefined && entry.text && entry.source));
assert.match(dailyImageHadiths[19].text, /أبي مسعود عقبة بن عمرو/);
assert.match(dailyImageHadiths[34].text, /من ظلم قيد شبر/);
assert.match(dailyImageHadiths[24].text, /لم يشربها في الآخرة/);
assert.equal(dailyImageHadiths[9].explanation, "أحصاها: حفظها.");
assert.ok(!dailyImageHadiths[9].text.includes("حفظها"));
assert.throws(() => parseImageHadithCatalogue({ ...imageData, entries: imageData.entries.slice(1) }));
assert.throws(() => parseImageHadithCatalogue({
  ...imageData, entries: imageData.entries.map((row, index) => index ? row : [2, ...row.slice(1)]),
}));
for (const column of [1, 2, 3, 4]) {
  assert.throws(() => parseImageHadithCatalogue({
    ...imageData, entries: imageData.entries.map((row, index) => {
      const copy = [...row];
      if (!index) copy[column] = "";
      return copy;
    }),
  }));
}
const fridayEntries = [...catalogue.friday, ...catalogue.fridayAdditional];
const rotation = new HadithRotation(catalogue.ordered, generalRandom, fridayEntries);
const all = [...catalogue.ordered, ...generalRandom, ...fridayEntries];
assert.equal(all.length, 327);
const seen = new Set();
const seenImages = new Set<number>();
for (let index = 0; index < all.length; index++) {
  assert.ok(all.includes(rotation.current));
  assert.ok(!seen.has(rotation.current), "No repeated entry within a full shuffled round.");
  seen.add(rotation.current);
  assert.equal(rotation.currentIsFridayHadith, fridayEntries.includes(rotation.current));
  if (rotation.current.sourceNumber) seenImages.add(rotation.current.sourceNumber);
  rotation.next();
}
assert.equal(seen.size, all.length);
assert.ok(catalogue.ordered.every(entry => seen.has(entry)));
assert.ok(fridayEntries.every(entry => seen.has(entry)));
assert.equal(seenImages.size, 200);
assert.ok(hadithDurationSeconds(catalogue.random[1]) >= 20);
assert.ok([20, 25, 30, 35, 40, 45, 50, 55, 60].includes(hadithDurationSeconds(catalogue.friday[1])));

rotation.setFridayMode(true);
const fridaySeen = new Set();
const otherSeen = new Set();
for (let block = 0; block < 300; block++) {
  let fridayCount = 0;
  for (let slot = 0; slot < 5; slot++) {
    assert.equal(rotation.isFridayMode, true);
    if (rotation.currentIsFridayHadith) {
      fridayCount++;
      fridaySeen.add(rotation.current);
    } else {
      otherSeen.add(rotation.current);
      assert.ok(!fridayEntries.includes(rotation.current));
    }
    rotation.next();
  }
  assert.equal(fridayCount, 3, "Exactly three Friday entries per two random entries in every shuffled block.");
}
assert.equal(fridaySeen.size, fridayEntries.length);
assert.equal(otherSeen.size, catalogue.ordered.length + generalRandom.length);
rotation.setFridayMode(false);
assert.equal(rotation.isFridayMode, false);
assert.ok(all.includes(rotation.current));
const fallback = new HadithRotation(catalogue.ordered, [], []);
fallback.setFridayMode(true);
assert.equal(fallback.isFridayMode, false);
assert.throws(() => new HadithRotation([], [], []));

for (const [characters, seconds] of [[0, 20], [150, 20], [151, 25], [300, 25], [301, 30], [450, 30], [451, 35], [600, 35], [601, 40], [750, 40], [751, 45], [900, 45], [901, 50], [1050, 50], [1051, 55], [1200, 55], [1201, 60], [1350, 60], [5000, 60]]) {
  assert.equal(hadithDurationSeconds({ text: "بَ".repeat(characters) }), seconds);
}
console.log("All supplied hadiths shuffled, Friday 3:2 weighting, metadata and timing passed.");
