import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { recitationParts } from "../src/components/mockups/prayer-themes/recitation-colors.ts";
const quoted = "عن عمر قال: سمعت رسول الله ﷺ يقول: «إنما الأعمال بالنيات»";
const parts = recitationParts(quoted);
assert.equal(parts[0].recitation, false);
assert.equal(parts[1].text, "«إنما الأعمال بالنيات»");
assert.equal(parts[1].recitation, true);
const plain = recitationParts("عن عبد الله قال: قال رسول الله صلى الله عليه وسلم: من صمت نجا.");
assert.equal(plain[0].text, "عن عبد الله قال: قال رسول الله صلى الله عليه وسلم:");
assert.equal(plain[1].text.trim(), "من صمت نجا.");
assert.equal(plain[1].recitation, true);
const friday = recitationParts("عن فلان قال: ((قول أول))؛\nوعن آخر قال: ((قول ثان))");
assert.deepEqual(friday.map(part => part.recitation), [false, true, false, true]);
const catalogue = JSON.parse(readFileSync("../../mobile/prayer_times/assets/data/dashboard-hadiths.json", "utf8"));
for (const entries of Object.values(catalogue)) if (Array.isArray(entries)) {
  for (const entry of entries) if (typeof entry.text === "string")
    assert.equal(recitationParts(entry.text).map(part => part.text).join(""), entry.text);
}
const evening = readFileSync("../../mobile/prayer_times/assets/data/evening-adhkar.txt", "utf8");
for (const text of evening.trim().split(/\n\s*\n/)) {
  const parts = recitationParts(text, true);
  assert.equal(parts.map(part => part.text).join(""), text);
  assert.equal(parts[0].recitation, true);
  for (const part of parts) {
    if (/^(من |لم يضره|كانت له|حُطَّتْ)/.test(part.text.trimStart())) assert.equal(part.recitation, false);
  }
}
console.log("Hadith reporting prefixes, quoted/unquoted speech, Friday multiple reports, evening rewards and complete text preservation passed.");
