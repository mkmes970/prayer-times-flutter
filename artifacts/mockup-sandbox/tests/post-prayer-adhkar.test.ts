import assert from "node:assert/strict";
import { adhkarForPrayer, adhkarBoardColumns, adhkarBoardWeight, stretchAdhkarText } from "../src/components/mockups/prayer-themes/post-prayer-adhkar.ts";
import { prayerDashboard, baghdadDay, timesForRegion, emptyBrowserSettings } from "../src/components/mockups/prayer-themes/browser-prayer-schedule.ts";

assert.equal(stretchAdhkarText("اللَّهُ اللَّهُمَّ بِاللَّهِ"), "الله اللهم بالله");
assert.equal(stretchAdhkarText("قُلْ هُوَ اللَّهُ أَحَدٌ", true), "قل هو الله أحد");
assert.equal(stretchAdhkarText("لا لأ لإ لآ"), "لا لأ لإ لآ");
assert.equal(stretchAdhkarText("الصلاة").includes("لـا"), false);
assert.equal(stretchAdhkarText("رَبِّ").startsWith("رَـ"), false);
assert.ok(stretchAdhkarText("سُبْحَانَ").includes("ـ"));
assert.equal(stretchAdhkarText("سُبْحَانَ").replaceAll("ـ", ""), "سبحان");

for (const prayer of ["fajrSecond", "dhuhr", "asr", "maghrib", "isha"] as const) {
  const pages = adhkarForPrayer(prayer);
  const ids = pages.map(page => page.id);
  assert.equal(ids[0], "istighfar-salam");
  assert.equal(pages[0].text.match(/أَسْتَغْفِرُ اللَّهَ/g)?.length, 3);
  assert.ok(pages[0].text.includes("اللَّهُمَّ أَنْتَ السَّلَامُ"));
  assert.equal(ids.includes("tahlil-ten"), prayer === "fajrSecond" || prayer === "maghrib");
  assert.equal(ids.includes("fajr-dua"), prayer === "fajrSecond");
  assert.ok(ids.includes("ayat-kursi"));
  assert.equal(pages.find(page => page.id === "ayat-kursi")?.boardText,
    "﴿ اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ﴾");
  for (const id of ["ikhlas", "falaq", "nas"]) {
    const page = pages.find(page => page.id === id)!;
    assert.equal(page.note, prayer === "fajrSecond" || prayer === "maghrib" ? "ثلاث مرات" : "مرة واحدة");
  }
  const columns = adhkarBoardColumns(prayer);
  assert.equal(columns.length, 2);
  assert.equal(columns[0][0].id, "istighfar-salam");
  const ordered = columns.flat();
  const difference = Math.abs(columns[0].reduce((sum, page) => sum + adhkarBoardWeight(page), 0) -
    columns[1].reduce((sum, page) => sum + adhkarBoardWeight(page), 0));
  for (let split = 1; split < ordered.length; split++) {
    const alternate = Math.abs(ordered.slice(0, split).reduce((sum, page) => sum + adhkarBoardWeight(page), 0) -
      ordered.slice(split).reduce((sum, page) => sum + adhkarBoardWeight(page), 0));
    assert.ok(difference <= alternate, "Column split must balance visible text, not item counts");
  }
  const all = columns.flat().map(page => page.id);
  assert.deepEqual([...all].sort(), [...ids].sort(), "All eligible texts appear together, with no omissions or duplicates");
  for (const page of columns.flat()) {
    assert.equal(page.text, pages.find(original => original.id === page.id)?.text,
      "The single board must preserve the complete supplied text");
  }
}
for (const date of [new Date("2026-10-14T12:00:00+03:00"), new Date("2026-10-16T12:00:00+03:00")]) {
  const settings = { ...emptyBrowserSettings, regionId: "hawd6" };
  const times = timesForRegion("hawd6", date)!;
  for (const prayer of ["fajrSecond", "dhuhr", "asr", "maghrib", "isha"] as const) {
    const friday = prayer === "dhuhr" && baghdadDay(date).weekday === 5;
    const duration = friday ? settings.fridayKhutbahMinutes! :
      settings.iqamaMinutes[prayer]! + settings.prayerDurationMinutes![prayer]!;
    const start = baghdadDay(date).start + (times[prayer] + duration) * 60000;
    const alert = prayerDashboard(new Date(start), settings).alert;
    assert.equal(alert?.kind, "dhikr");
    assert.equal(alert?.prayerId, prayer);
    assert.equal(alert?.startsAt, start);
    assert.equal(alert?.endsAt, start + 480000);
    assert.notEqual(prayerDashboard(new Date(start + 480000), settings).alert?.kind, "dhikr");
  }
}
console.log("Single two-column adhkar board, complete texts, prayer-specific repetitions, Friday and exact duration passed.");
