import assert from "node:assert/strict";
import {
  regionOptions, timesForRegion, prayerDashboard, settingsValidation,
  baghdadDay, countdownText, readBrowserPrayerSettings,
  emptyBrowserSettings, defaultIqamaMinutes, defaultPrayerDurationMinutes,
} from "../src/components/mockups/prayer-themes/browser-prayer-schedule.ts";

for (const region of regionOptions) {
  for (let index = 0; index < 366; index++) {
    const date = new Date(Date.UTC(2024, 0, 1, 9) + index * 86400000);
    const times = timesForRegion(region.id, date);
    assert.ok(times, `${region.name}: ${date.toISOString()}`);
    const values = Object.values(times);
    assert.equal(values.length, 7);
    assert.ok(values.every((time, position) => position === 0 || time > values[position - 1]));
    // Hawd 6 Jan–Jun second Fajr follows the corrected photos; first Fajr stays unchanged.
    if (region.id !== "alam" && (region.id !== "hawd6" || baghdadDay(date).month > 6)) {
      assert.equal(times.fajrSecond - times.fajrFirst, 15);
    }
  }
}
const settings = { regionId: "hawd6", iqamaMinutes: { dhuhr: 15 } };
assert.equal(regionOptions.find(region => region.id === "alam")?.name,
  "مواقيت الصلاة في العلم");
for (const year of [2026, 2027, 2028]) {
  const at = (month: number, day: number) =>
    timesForRegion("alam", new Date(Date.UTC(year, month - 1, day, 9)))!;
  assert.equal(at(1, 1).fajrFirst, 5 * 60 + 32);
  assert.equal(at(1, 1).fajrSecond, 5 * 60 + 50);
  assert.equal(at(11, 7).fajrFirst, 4 * 60 + 55);
  assert.equal(at(11, 7).fajrSecond, 5 * 60 + 13);
  for (let day = 24; day <= 28; day++)
    assert.equal(at(4, day).maghrib, 18 * 60 + day + 21);
}
assert.ok(timesForRegion("alam", new Date("2028-02-29T12:00:00+03:00")));
assert.equal(regionOptions.find(region => region.id === "shajara")?.name,
  "مواقيت الصلاة لقرية الشجرة");
for (const year of [2026, 2027, 2028]) {
  const march = timesForRegion("shajara", new Date(Date.UTC(year, 2, 21, 9)))!;
  assert.equal(march.fajrSecond, 4 * 60 + 50);
  assert.equal(march.fajrFirst, 4 * 60 + 35);
  assert.equal(march.sunrise, 6 * 60 + 10);
  assert.equal(timesForRegion("shajara", new Date(Date.UTC(year, 3, 29, 9)))!.isha, 20 * 60 + 12);
  assert.equal(timesForRegion("shajara", new Date(Date.UTC(year, 3, 30, 9)))!.isha, 20 * 60 + 13);
}
assert.equal(regionOptions.find(region => region.id === "baggara")?.name,
  "مواقيت الصلاة لقرية البگارة");
const baggaraAt = (month: number, day: number) =>
  timesForRegion("baggara", new Date(Date.UTC(2028, month - 1, day, 9)))!;
assert.ok(baggaraAt(2, 29));
assert.equal(baggaraAt(1, 18).dhuhr, 12 * 60 + 20);
assert.equal(baggaraAt(3, 18).dhuhr, 12 * 60 + 18);
assert.equal(baggaraAt(10, 18).fajrSecond, 4 * 60 + 59);
assert.equal(baggaraAt(10, 18).fajrFirst, 4 * 60 + 44);
for (let day = 14; day <= 18; day++)
  assert.equal(baggaraAt(11, day).maghrib, 17 * 60 + (day <= 16 ? 2 : 1));
for (let day = 5; day <= 9; day++)
  assert.equal(baggaraAt(6, day).fajrSecond, 3 * 60 + 31);
for (const day of [30, 31])
  assert.equal(baggaraAt(5, day).fajrSecond, 3 * 60 + 29);
assert.equal(baggaraAt(8, 31).isha, 19 * 60 + 55);
assert.equal(baggaraAt(4, 8).sunrise, 5 * 60 + 49);
assert.equal(baggaraAt(4, 15).sunrise, 5 * 60 + 39);
assert.equal(regionOptions.find(region => region.id === "hawija")?.name,
  "مواقيت الصلاة لقضاء الحويجة وضواحيها");
for (const year of [2026, 2027, 2028]) {
  const at = (month: number, day: number) =>
    timesForRegion("hawija", new Date(Date.UTC(year, month - 1, day, 9)))!;
  assert.equal(at(6, 28).dhuhr, 12 * 60 + 13);
  assert.equal(at(8, 18).isha, 20 * 60 + 15);
  assert.equal(at(11, 24).fajrSecond, 5 * 60 + 30);
  assert.equal(at(11, 25).fajrSecond, 5 * 60 + 31);
  assert.equal(at(2, 19).sunrise, 6 * 60 + 52);
  assert.equal(at(4, 4).maghrib, 18 * 60 + 32);
}
assert.ok(timesForRegion("hawija", new Date("2028-02-29T12:00:00+03:00")));
assert.equal(regionOptions.find(region => region.id === "tikrit")?.name,
  "مواقيت الصلاة لمدينة تكريت وضواحيها");
const tikritLeapDay = timesForRegion("tikrit", new Date("2028-02-29T12:00:00+03:00"))!;
assert.deepEqual(tikritLeapDay,
  timesForRegion("tikrit", new Date("2028-02-28T12:00:00+03:00")));
assert.equal(tikritLeapDay.fajrFirst, 4 * 60 + 57);
assert.equal(tikritLeapDay.fajrSecond, 5 * 60 + 12);
assert.equal(tikritLeapDay.asr, 15 * 60 + 35);
for (const year of [2026, 2027, 2028]) {
  const annual = timesForRegion("tikrit", new Date(`${year}-10-14T12:00:00+03:00`))!;
  assert.equal(annual.dhuhr, 11 * 60 + 56);
  assert.ok(timesForRegion("tikrit", new Date(`${year}-12-31T12:00:00+03:00`)));
  assert.ok(timesForRegion("tikrit", new Date(`${year + 1}-01-01T12:00:00+03:00`)));
}
const date = new Date("2026-10-13T10:00:00+03:00");
const times = timesForRegion(settings.regionId, date)!;
const adhan = baghdadDay(date).start + times.dhuhr * 60000;
const highlightSettings = { ...emptyBrowserSettings, regionId: "hawd6" };
const ids = ["fajrSecond", "dhuhr", "asr", "maghrib", "isha"] as const;
for (const [index, id] of ids.entries()) {
  const start = baghdadDay(date).start + times[id] * 60000;
  const end = start + (defaultIqamaMinutes[id]! + defaultPrayerDurationMinutes[id]!) * 60000;
  for (const instant of [start - 1000, start, end - 1]) {
    assert.equal(prayerDashboard(new Date(instant), highlightSettings).activePrayerId, id);
  }
  assert.equal(prayerDashboard(new Date(end), highlightSettings).activePrayerId, ids[index + 1] ?? "fajrSecond");
}
const fridayHighlightDate = new Date("2026-10-16T10:00:00+03:00");
const fridayHighlightTimes = timesForRegion("hawd6", fridayHighlightDate)!;
const fridayHighlightStart = baghdadDay(fridayHighlightDate).start + fridayHighlightTimes.dhuhr * 60000;
const fridayHighlightEnd = fridayHighlightStart + 20 * 60000;
assert.equal(prayerDashboard(new Date(fridayHighlightEnd - 1), highlightSettings).activePrayerId, "dhuhr");
assert.equal(prayerDashboard(new Date(fridayHighlightEnd), highlightSettings).activePrayerId, "asr");
assert.equal(prayerDashboard(new Date(adhan - 31000), settings).alert, null);
assert.equal(prayerDashboard(new Date(adhan - 30000), settings).alert?.remaining, 30);
assert.equal(prayerDashboard(new Date(adhan - 29900), settings).alert?.remaining, 30);
assert.equal(prayerDashboard(new Date(adhan), settings).alert?.title, "حان موعد أذان الظهر");
assert.ok(prayerDashboard(new Date(adhan + 14999), settings).alert);
assert.equal(prayerDashboard(new Date(adhan + 15000), settings).alert, null);
assert.equal(prayerDashboard(new Date(adhan + 15 * 60000 - 30000), settings).alert?.remaining, 30);
assert.equal(prayerDashboard(new Date(adhan + 15 * 60000), settings).alert?.title, "الصلاة قائمة");
for (const prayerId of ["fajrSecond", "dhuhr", "asr", "maghrib", "isha"] as const) {
  const configured = { ...emptyBrowserSettings, regionId: "hawd6" };
  const start = baghdadDay(date).start + timesForRegion("hawd6", date)![prayerId] * 60000;
  const iqamaAt = start + configured.iqamaMinutes[prayerId]! * 60000;
  const during = (offset: number) => prayerDashboard(new Date(iqamaAt + offset), configured);
  assert.equal(during(0).alert?.kind, "announcement");
  assert.equal(during(44999).alert?.kind, "announcement");
  assert.equal(during(45000).alert?.kind, "blackout");
  assert.equal(during(60000).alert?.kind, "blackout");
  if (prayerId === "fajrSecond") {
    assert.equal(during(-30000).alert?.title, "الوقت المتبقي لإقامة الصلاة");
    assert.equal(during(-31000).iqama?.iqamaLabel, "الفجر");
    assert.equal(prayerDashboard(new Date(start), configured).alert?.title, "حان موعد أذان الفجر الثاني");
  }
  const withoutDuration = { ...configured, prayerDurationMinutes: {} };
  assert.equal(prayerDashboard(new Date(iqamaAt + 44999), withoutDuration).alert?.kind, "announcement");
  assert.equal(prayerDashboard(new Date(iqamaAt + 45000), withoutDuration).alert, null);
}
assert.equal(prayerDashboard(new Date(adhan + 16 * 60000), settings).alert?.kind, "blackout");
assert.equal(prayerDashboard(new Date(adhan + 23 * 60000), settings).alert?.kind, "dhikr");
assert.equal(prayerDashboard(new Date(adhan + 31 * 60000), settings).alert, null);
assert.equal(countdownText(adhan, new Date(adhan - 30000)), "00:00:30");

const friday = new Date("2026-10-16T10:00:00+03:00");
const fridayTimes = timesForRegion("hawd6", friday)!;
const fridayStart = baghdadDay(friday).start;
const fridayNoon = fridayStart + fridayTimes.dhuhr * 60000;
assert.equal(prayerDashboard(new Date(fridayNoon + 15 * 60000 - 30000), settings).alert?.kind, "blackout");
assert.equal(prayerDashboard(new Date(fridayNoon + 15 * 60000), settings).alert?.title, "استمع للخطبة بارك الله فيك");
assert.equal(prayerDashboard(new Date(fridayNoon + 20 * 60000), settings).alert?.kind, "dhikr");
assert.equal(prayerDashboard(new Date(fridayNoon + 28 * 60000), settings).alert, null);
const fridayAt = (ms: number, options = settings) => prayerDashboard(new Date(fridayNoon + ms), options).alert;
assert.equal(fridayAt(-30000)?.showPhone, true);
assert.equal(fridayAt(-30000)?.remaining, 30);
assert.equal(fridayAt(-1)?.remaining, 1);
assert.equal(fridayAt(0)?.title, "استمع للخطبة");
assert.equal(fridayAt(0)?.kind, "khutbah");
assert.equal(fridayAt(59999)?.kind, "khutbah");
assert.equal(fridayAt(60000)?.title, "استمع للخطبة بارك الله فيك");
assert.equal(fridayAt(20 * 60000 - 1)?.kind, "blackout");
for (const minutes of [1, 5, 30]) for (const dhikr of [0, 5, 12]) {
  const custom = { ...settings, fridayKhutbahMinutes: minutes, postPrayerDhikrMinutes: dhikr };
  const end = minutes * 60000;
  assert.equal(fridayAt(0, custom)?.kind, "khutbah");
  assert.equal(fridayAt(end, custom)?.kind ?? null, dhikr > 0 ? "dhikr" : null);
  assert.equal(fridayAt(end + dhikr * 60000, custom), null);
}
for (const prayer of ["fajrSecond", "dhuhr", "asr", "maghrib", "isha"] as const) {
  const configured = { ...emptyBrowserSettings, regionId: "hawd6" };
  const day = new Date("2026-10-14T10:00:00+03:00");
  const schedule = timesForRegion("hawd6", day)!;
  const at = baghdadDay(day).start + schedule[prayer] * 60000;
  assert.equal(prayerDashboard(new Date(at - 30000), configured).alert?.showPhone, false);
  const iqama = at + configured.iqamaMinutes[prayer]! * 60000;
  const alert = prayerDashboard(new Date(iqama - 30000), configured).alert;
  assert.equal(alert?.title, "الوقت المتبقي لإقامة الصلاة");
  assert.equal(alert?.showPhone, true);
}
assert.equal(prayerDashboard(new Date(fridayNoon + 15000), settings).iqama, undefined);
const fridayAsr = fridayStart + fridayTimes.asr * 60000;
assert.equal(prayerDashboard(new Date(fridayAsr + 15 * 60000 - 30000), {
  ...settings, iqamaMinutes: { asr: 15 },
}).alert?.remaining, 30);
assert.ok(prayerDashboard(new Date(fridayNoon), settings).fridayHadiths);
assert.equal(prayerDashboard(new Date(fridayStart + fridayTimes.isha * 60000), settings).fridayHadiths, true);
assert.equal(prayerDashboard(new Date(fridayStart), settings).fridayHadiths, true);
assert.equal(prayerDashboard(new Date(fridayStart + 86400000), settings).fridayHadiths, false);
assert.equal(prayerDashboard(date, { regionId: null, iqamaMinutes: {} }).times, null);
assert.ok(settingsValidation({ regionId: "unavailable", iqamaMinutes: {} }));
assert.ok(settingsValidation({ regionId: "hawd6", iqamaMinutes: { dhuhr: 1.5 } }));
assert.equal(settingsValidation(settings), null);

let stored: string | null = null;
Object.defineProperty(globalThis, "localStorage", { configurable: true, value: {
  getItem: () => stored, setItem: (_key: string, value: string) => { stored = value; },
} });
assert.equal(readBrowserPrayerSettings().settings.regionId, null);
stored = JSON.stringify(settings);
const migrated = readBrowserPrayerSettings().settings;
assert.equal(migrated.regionId, settings.regionId);
assert.deepEqual(migrated.iqamaMinutes, defaultIqamaMinutes);
assert.deepEqual(migrated.prayerDurationMinutes, defaultPrayerDurationMinutes);
assert.equal(migrated.postPrayerDhikrMinutes, 8);
assert.equal(migrated.fridayKhutbahMinutes, 20);
stored = JSON.stringify({ ...emptyBrowserSettings, regionId: "hawd6", iqamaMinutes: { dhuhr: 2 } });
assert.equal(readBrowserPrayerSettings().settings.iqamaMinutes.dhuhr, 2, "later edits must survive reload");
stored = JSON.stringify({ ...emptyBrowserSettings, regionId: "hawija" });
const restoredHawija = readBrowserPrayerSettings().settings;
assert.equal(restoredHawija.regionId, "hawija");
assert.equal(prayerDashboard(date, restoredHawija).times?.asr, 15 * 60 + 11);
stored = JSON.stringify({ ...emptyBrowserSettings, regionId: "tikrit" });
const restoredTikrit = readBrowserPrayerSettings().settings;
assert.equal(restoredTikrit.regionId, "tikrit");
assert.equal(settingsValidation(restoredTikrit), null);
assert.equal(prayerDashboard(date, restoredTikrit).times?.dhuhr, 11 * 60 + 57);
stored = JSON.stringify({ ...emptyBrowserSettings, regionId: "shajara" });
const restoredShajara = readBrowserPrayerSettings().settings;
assert.equal(restoredShajara.regionId, "shajara");
assert.equal(settingsValidation(restoredShajara), null);
assert.ok(prayerDashboard(date, restoredShajara).times);
stored = "invalid";
assert.ok(readBrowserPrayerSettings().notice);
stored = JSON.stringify({ regionId: "removed-region", iqamaMinutes: {} });
assert.equal(readBrowserPrayerSettings().settings.regionId, null);
assert.ok(readBrowserPrayerSettings().notice);
const midnight = new Date("2026-12-31T23:59:50+03:00");
assert.ok(prayerDashboard(midnight, settings).nextPrayer!.adhanAt > midnight.getTime());
assert.equal(prayerDashboard(new Date(adhan), settings).theme, "dhuhr");
console.log(`All ${regionOptions.length * 366} regional dates, storage, approved Hawija corrections, 30/15-second alerts, Friday and year-boundary checks passed.`);
