import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AdhanPlayback } from "../src/components/mockups/prayer-themes/adhan-playback.ts";
import { adhanDurationSeconds, hadithDurationSeconds, normalInformationSeconds } from "../src/components/mockups/prayer-themes/hadith-timing.ts";

assert.equal(normalInformationSeconds, 5);
for (const [letters, seconds] of [[0,15],[150,15],[151,20],[301,25],[451,30],[601,35],[751,40],[901,45],[1051,50],[5000,50]]) {
  assert.equal(adhanDurationSeconds({ text: "بَ".repeat(letters) }), seconds);
}
assert.equal(hadithDurationSeconds({text:"ب".repeat(5000)}), 60);
const entries = [{text:"أول"},{text:"ثاني"},{text:"ثالث"}];
const end = 1000000, start = end - 300000;
let player = new AdhanPlayback();
assert.equal(player.at(entries, start - 1, end), null);
for (let seconds = 0; seconds <= 34; seconds++) {
  const entry = player.at(entries, start + seconds * 1000, end);
  if (seconds < 5 || (seconds >= 20 && seconds < 25)) assert.equal(entry, null);
  else assert.equal(entry, entries[seconds < 20 ? 0 : 1]);
}
assert.equal(player.at(entries, start + 35000, end, true), null);
assert.equal(player.index, 1, "Interrupted entry must not count as complete");
// Equivalent to restoring the saved cursor after a page refresh or restart.
player = new AdhanPlayback(JSON.parse(JSON.stringify({index:player.index})).index);
const nextEnd = end + 3600000, nextStart = nextEnd - 300000;
for (let second = 0; second <= 5; second++) {
  assert.equal(player.at(entries, nextStart + second * 1000, nextEnd),
    second < 5 ? null : entries[1]);
}
player.at(entries, nextStart + 90000, nextEnd);
assert.equal(player.index, 1, "Background time cannot silently complete unseen readings");
assert.equal(player.at(entries, nextEnd, nextEnd), null);

const catalogue = JSON.parse(readFileSync("../../mobile/prayer_times/assets/data/adhan-hadiths.json", "utf8"));
const explanations = JSON.parse(readFileSync("../../mobile/prayer_times/assets/data/adhan-explanations.json", "utf8"));
assert.equal(catalogue.entries.length, 9);
assert.equal(catalogue.entries[6].text, "عن أبي سعيد الخدري رضي الله عنه قال: قال رسول الله صلى الله عليه وسلم:\n«إني أراك تحب الغنم والبادية، فإذا كنت في غنمك أو باديتك فأذنت بالصلاة فارفع صوتك بالنداء، فإنه لا يسمع مدى صوت المؤذن جن ولا إنس ولا شيء إلا شهد له يوم القيامة»\nأخرجه البخاري");
assert.equal(catalogue.entries[7].text, "عن عقبة بن عامر رضي الله عنه قال: سمعت رسول الله صلى الله عليه وسلم يقول : «يعجب ربكم من راعي غنم في رأس شظية بجبل يؤذن بالصلاة ويصلي، فيقول الله عز وجل: انظروا إلى عبدي هذا يؤذن ويقيم الصلاة يخاف مني، قد غفرت لعبدي وأدخلته الجنة»\nأخرجه أبو داود والنسائي، وصححه الألباني");
assert.equal(catalogue.entries[8].text, "عن عبدالله بن عمر رضي الله عنهما قال: قال رسول الله صلى الله عليه وسلم:\n«من أذن ثنتي عشرة سنة وجبت له الجنة، وكتب له بتأذينه في كل يوم ستون حسنة، ولكل إقامة ثلاثون حسنة»\nأخرجه ابن ماجه وقال صحيح على شرط البخاري");
const scheduled = [...explanations.entries, ...catalogue.entries];
assert.equal(scheduled.length, 19);
player = new AdhanPlayback();
const completed: number[] = [];
for (let window = 0; window < 4; window++) {
  const until = end + window * 3600000;
  for (let second = 0; second <= 300; second++) {
    const before = player.index;
    player.at(scheduled, until - 300000 + second * 1000, until, second >= 270);
    if (player.index !== before) completed.push(before);
  }
  player = new AdhanPlayback(player.index);
}
assert.ok(completed.length >= 19);
assert.deepEqual(completed.slice(0, 19), Array.from({length:19}, (_, i) => i));
console.log("19 verbatim entries: persistent ordered progress, interrupted replay, pauses, wrapping, alert priority and background safety passed.");
