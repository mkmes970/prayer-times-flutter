import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { HadithRotation } from "../src/components/mockups/prayer-themes/hadith-rotation.ts";
import { recitationParts } from "../src/components/mockups/prayer-themes/recitation-colors.ts";

const catalogue = JSON.parse(readFileSync("../../mobile/prayer_times/assets/data/ramadan-hadiths.json", "utf8"));
assert.equal(catalogue.entries.length, 75);
for (const entry of catalogue.entries) {
  assert.ok(entry.text.length > 0);
  assert.equal(recitationParts(entry.text).map(part => part.text).join(""), entry.text);
}
const other = [{ text: "other" }];
const friday = [{ text: "friday" }];
const ramadan = [{ text: "ramadan" }];
for (const isFriday of [false, true]) {
  const rotation = new HadithRotation(other, [], friday, ramadan);
  rotation.setFridayMode(isFriday);
  rotation.setRamadanMode(true);
  const counts = { other: 0, friday: 0, ramadan: 0 };
  const displayCount = isFriday ? 70 : 50;
  for (let i = 0; i < displayCount; i++) {
    counts[rotation.current.text as keyof typeof counts]++;
    rotation.next();
  }
  assert.deepEqual(counts, isFriday
    ? { other: 30, friday: 20, ramadan: 20 }
    : { other: 30, friday: 0, ramadan: 20 });
}
// Repeated texts must remain separate entries rather than being deduplicated.
const rotation = new HadithRotation([], [], [], catalogue.entries);
const seen = new Set();
for (let i = 0; i < 75; i++) {
  seen.add(rotation.current);
  rotation.next();
}
assert.equal(seen.size, 75);
console.log("Ramadan catalogue, verbatim rendering, random reachability and weights passed.");

const pdf = JSON.parse(readFileSync("../../mobile/prayer_times/assets/data/abu-hurayra-50-hadiths.json", "utf8"));
assert.equal(pdf.entries.length, 50);
for (const [index, entry] of pdf.entries.entries()) {
  assert.equal(entry.number, index + 1);
  assert.ok(entry.text.startsWith("عَنْ أَبِي هُرَيْرَةَ"));
  assert.ok((entry.text + entry.source).includes("مُتَّفَقٌ عَلَيْهِ"));
  assert.equal(recitationParts(entry.text).map(part => part.text).join(""), entry.text);
}
for (const number of [17, 23, 25]) {
  assert.match(pdf.entries[number - 1].text, /وَعِنْدَ|وَزَادَ/);
}
const pdfRotation = new HadithRotation([], pdf.entries);
const pdfSeen = new Set();
for (let i = 0; i < 50; i++) {
  pdfSeen.add(pdfRotation.current);
  pdfRotation.next();
}
assert.equal(pdfSeen.size, 50);
console.log("All 50 PDF hadiths retain narrators, sources and variant continuations and are reachable.");
