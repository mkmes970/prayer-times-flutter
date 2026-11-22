import assert from "node:assert/strict";
import { emptyBrowserSettings, browserRegions, timesForRegion, settingsValidation } from "../src/components/mockups/prayer-themes/browser-prayer-schedule.ts";
import {
  addBrowserRegion, renameBrowserRegion, deleteBrowserRegion, setBrowserPrayerDay,
  importBrowserBackup, restoreBrowserDefaults, hashBrowserPin, verifyBrowserPin,
  hijriDisplay, validateBrowserPreferences,
} from "../src/components/mockups/prayer-themes/browser-prayer-preferences.ts";

const original = { ...structuredClone(emptyBrowserSettings), regionId: "abbasi" };
assert.equal(original.hadithEnabled, false, "hadiths are disabled by default");
assert.equal(original.tickerScrollingEnabled, false, "ticker uses static 10-second mode until enabled");
assert.equal(original.tickerSpeed, 32, "ticker has a readable default speed");
assert.equal(settingsValidation({ ...original, hadithEnabled: true }), null);
assert.notEqual(settingsValidation({ ...original, hadithEnabled: "true" } as unknown as typeof original), null);
assert.equal(settingsValidation({ ...original, tickerScrollingEnabled: true, tickerSpeed: 64 }), null);
assert.notEqual(settingsValidation({ ...original, tickerScrollingEnabled: "true" } as unknown as typeof original), null);
assert.notEqual(settingsValidation({ ...original, tickerSpeed: 100 }), null);
const date = new Date("2026-10-13T10:00:00+03:00");
const before = timesForRegion("abbasi", date, original)!;
const values = Object.fromEntries(Object.entries(before).map(([id, minutes]) =>
  [id, `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`]));
let settings = setBrowserPrayerDay(original, "abbasi", "2026-10-13", { ...values, dhuhr: "11:57" } as Parameters<typeof setBrowserPrayerDay>[3]);
assert.equal(timesForRegion("abbasi", date, settings)?.dhuhr, 717);
assert.equal(timesForRegion("abbasi", new Date("2027-10-13T10:00:00+03:00"), settings)?.dhuhr, before.dhuhr, "date-specific editing must not change recurring source");
assert.throws(() => setBrowserPrayerDay(settings, "abbasi", "2026-10-13", { ...values, dhuhr: "02:00" } as Parameters<typeof setBrowserPrayerDay>[3]));
settings = renameBrowserRegion(settings, "abbasi", "اسم اختبار");
assert.equal(browserRegions(settings).find((region) => region.id === "abbasi")?.name, "اسم اختبار");
assert.equal(browserRegions(original).find((region) => region.id === "abbasi")?.name.includes("العباسي"), true, "draft must not mutate original");
settings = addBrowserRegion(settings, "منطقة جديدة");
const customId = settings.regionId!;
assert.equal(timesForRegion(customId, date, settings), null, "new region has no invented timetable");
settings = setBrowserPrayerDay(settings, customId, "2026-10-13", values as Parameters<typeof setBrowserPrayerDay>[3]);
assert.deepEqual(timesForRegion(customId, date, settings), before);
settings = deleteBrowserRegion(settings, customId);
assert.equal(browserRegions(settings).some((region) => region.id === customId), false);
assert.equal(settingsValidation(settings), null);

const backup = JSON.stringify({ format: "prayer-browser-backup", version: 2,
  settings: { ...settings, regions: browserRegions(settings) } });
const restored = importBrowserBackup(backup, original);
const hadithBackup = JSON.stringify({ format: "prayer-browser-backup", version: 2,
  settings: { ...settings, hadithEnabled: true, regions: browserRegions(settings) } });
assert.equal(importBrowserBackup(hadithBackup, original).hadithEnabled, true, "backup preserves hadith toggle");
assert.deepEqual(timesForRegion("abbasi", date, restored), timesForRegion("abbasi", date, settings));
assert.equal(browserRegions(restored).find((region) => region.id === "abbasi")?.name, "اسم اختبار");
const rawTable = JSON.stringify({ name: "جدول اختبار", months: browserRegions(original)[0].months });
assert.ok(timesForRegion(importBrowserBackup(rawTable, original).regionId, date, importBrowserBackup(rawTable, original)) === null,
  "separate imports have separate identities");
const imported = importBrowserBackup(rawTable, original);
assert.ok(timesForRegion(imported.regionId, date, imported));
assert.throws(() => importBrowserBackup("bad json", original));
assert.throws(() => importBrowserBackup('{"name":"invalid","months":[{"month":14,"days":[]}]}', original));
const native = importBrowserBackup(JSON.stringify({ settings: { ...emptyBrowserSettings, accentColor: 0xff31546c },
  selectedRegionId: "native-region", regions: [{ id: "native-region", name: "جدول أندرويد",
    annualMonths: [{ month: 10, days: [{ day: 13, prayers: values }] }], years: [] }] }), original);
assert.deepEqual(timesForRegion(native.regionId, date, native), before);
assert.equal(native.accentColor, "#31546c");
const reset = restoreBrowserDefaults({ ...settings, iqamaMinutes: { dhuhr: 2 }, postPrayerDhikrMinutes: 1 });
assert.equal(reset.iqamaMinutes.dhuhr, 15);
assert.equal(reset.postPrayerDhikrMinutes, 8);
assert.equal(timesForRegion("abbasi", date, reset)?.dhuhr, 717, "reset preferences must retain timetables");
assert.notEqual(hijriDisplay(date, original), hijriDisplay(date, { ...original, hijriOffsetDays: 1 }));
assert.equal(validateBrowserPreferences({ ...original, hijriManualDate: { day: 2, month: 5, anchor: "2026-10-13" } }), null);

const protection = await hashBrowserPin("2468");
assert.equal(protection.hash.length, 64);
assert.equal(protection.salt.length, 32);
assert.ok(await verifyBrowserPin("2468", protection));
assert.equal(await verifyBrowserPin("2469", protection), false);
assert.equal(await verifyBrowserPin("", protection), false);
assert.equal(JSON.stringify(protection).includes('"2468"'), false);
console.log("Region CRUD/date editing, native/browser backup, defaults reset, Hijri and local PIN checks passed.");
