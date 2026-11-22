import {
  baghdadDay, browserRegions, emptyBrowserSettings, prayerKeys, settingsValidation, sourceDay,
} from "./browser-prayer-schedule.ts";
import type { BrowserPrayerSettings, BrowserRegion, PrayerId } from "./browser-prayer-schedule.ts";

export const hijriMonthNames = ["محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جمادى الأولى", "جمادى الآخرة",
  "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"];
export const prayerLabels: Record<PrayerId, string> = {
  fajrFirst: "الفجر الأول", fajrSecond: "الفجر الثاني", sunrise: "الشروق", dhuhr: "الظهر",
  asr: "العصر", maghrib: "المغرب", isha: "العشاء",
};
export function browserDateKey(now = new Date()) {
  const { year, month, day } = baghdadDay(now);
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}
function withRegion(settings: BrowserPrayerSettings, region: BrowserRegion) {
  return { ...settings, regions: [...(settings.regions ?? []).filter((entry) => entry.id !== region.id), region],
    removedRegionIds: (settings.removedRegionIds ?? []).filter((id) => id !== region.id) };
}
export function addBrowserRegion(settings: BrowserPrayerSettings, name: string): BrowserPrayerSettings {
  if (!name.trim()) throw new Error("أدخل اسم المنطقة.");
  const region: BrowserRegion = { id: crypto.randomUUID(), name: name.trim(), months: [] };
  return { ...withRegion(settings, region), regionId: region.id };
}
export function renameBrowserRegion(settings: BrowserPrayerSettings, id: string, name: string): BrowserPrayerSettings {
  const region = browserRegions(settings).find((entry) => entry.id === id);
  if (!region || !name.trim()) throw new Error("اختر منطقة وأدخل اسمها.");
  return withRegion(settings, { ...region, name: name.trim() });
}
export function deleteBrowserRegion(settings: BrowserPrayerSettings, id: string): BrowserPrayerSettings {
  const next = { ...settings, regions: (settings.regions ?? []).filter((region) => region.id !== id),
    removedRegionIds: [...new Set([...(settings.removedRegionIds ?? []), id])] };
  return { ...next, regionId: settings.regionId === id ? browserRegions(next)[0]?.id ?? null : settings.regionId };
}
export function setBrowserPrayerDay(settings: BrowserPrayerSettings, id: string, date: string,
  values: Record<PrayerId, string>): BrowserPrayerSettings {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || new Date(`${date}T00:00:00Z`).toISOString().slice(0, 10) !== date) throw new Error("اختر تاريخًا صحيحًا.");
  let previous = -1;
  for (const key of prayerKeys) {
    if (!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(values[key])) throw new Error(`أدخل وقت ${prayerLabels[key]} بصيغة 24 ساعة.`);
    const [hour, minute] = values[key].split(":").map(Number);
    const current = hour * 60 + minute;
    if (current <= previous) throw new Error("يجب أن تكون المواقيت مرتبة من الفجر الأول إلى العشاء.");
    previous = current;
  }
  const region = browserRegions(settings).find((entry) => entry.id === id);
  if (!region) throw new Error("اختر المنطقة أولًا.");
  return withRegion(settings, { ...region, days: { ...region.days, [date]: values } });
}
export function restoreBrowserDefaults(settings: BrowserPrayerSettings): BrowserPrayerSettings {
  return { ...structuredClone(emptyBrowserSettings), regionId: settings.regionId,
    regions: settings.regions, removedRegionIds: settings.removedRegionIds };
}
function nativeRegion(raw: Record<string, unknown>): BrowserRegion {
  const id = typeof raw.id === "string" ? raw.id : crypto.randomUUID();
  const region: BrowserRegion = { id, name: String(raw.name ?? ""), months: [], days: {} };
  if (Array.isArray(raw.months)) region.months = raw.months as BrowserRegion["months"];
  if (Array.isArray(raw.annualMonths)) {
    region.months = raw.annualMonths.map((month: { month: number; days: { day: number; prayers: Record<PrayerId, string> }[] }) =>
      ({ month: month.month, days: month.days.map((entry) => sourceDay(entry.prayers, entry.day)) }));
  }
  if (Array.isArray(raw.years)) {
    for (const year of raw.years) for (const month of year.months) for (const day of month.days) {
      region.days![`${year.year}-${String(month.month).padStart(2, "0")}-${String(day.day).padStart(2, "0")}`] = day.prayers;
    }
  }
  return region;
}
export function importBrowserBackup(text: string, current: BrowserPrayerSettings): BrowserPrayerSettings {
  if (text.length > 5_000_000) throw new Error("حجم الملف أكبر من المسموح (5 ميغابايت).");
  let raw: Record<string, unknown>;
  try { raw = JSON.parse(text); } catch { throw new Error("ملف JSON غير صحيح."); }
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("صيغة ملف غير مدعومة.");
  let result: BrowserPrayerSettings;
  if (raw.format === "prayer-browser-backup" && raw.version === 2 && raw.settings) {
    result = { ...emptyBrowserSettings, ...raw.settings as BrowserPrayerSettings, preferencesVersion: 2 };
  } else if (raw.settings && Array.isArray(raw.regions)) {
    const native = raw.settings as Record<string, unknown>;
    result = { ...emptyBrowserSettings, ...native, preferencesVersion: 2,
      regionId: typeof raw.selectedRegionId === "string" ? raw.selectedRegionId : null,
      regions: raw.regions.map(nativeRegion), removedRegionIds: browserRegions().map((region) => region.id),
      accentColor: typeof native.accentColor === "number" ? `#${(native.accentColor & 0xffffff).toString(16).padStart(6, "0")}` : "#17432e",
      pin: current.pin, hijriManualDate: native.hijriAnchorDate && native.hijriManualDay && native.hijriManualMonth
        ? { day: Number(native.hijriManualDay), month: Number(native.hijriManualMonth), anchor: String(native.hijriAnchorDate).slice(0, 10) } : null };
    // Native-only auto-start/PIN hashes do not become browser credentials.
    for (const key of ["pinSalt", "pinHash", "autoStartEnabled"]) delete (result as unknown as Record<string, unknown>)[key];
  } else if (typeof raw.name === "string" && (Array.isArray(raw.months) || Array.isArray(raw.annualMonths) || Array.isArray(raw.years))) {
    const region = nativeRegion(raw);
    result = { ...withRegion(current, region), regionId: region.id };
  } else throw new Error("الملف ليس جدول مواقيت أو نسخة احتياطية مدعومة.");
  const error = settingsValidation(result, false);
  if (error) throw new Error(error);
  return result;
}
export function exportBrowserBackup(settings: BrowserPrayerSettings): void {
  const blob = new Blob([JSON.stringify({ format: "prayer-browser-backup", version: 2,
    settings: { ...settings, regions: browserRegions(settings) } }, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url; link.download = "prayer-settings-backup.json"; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export async function hashBrowserPin(pin: string, salt?: string): Promise<{ salt: string; hash: string }> {
  if (!/^\d{4,8}$/.test(pin)) throw new Error("رمز PIN من 4 إلى 8 أرقام.");
  const hex = (bytes: Uint8Array) => Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
  const actualSalt = salt ?? hex(crypto.getRandomValues(new Uint8Array(16)));
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(pin), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", salt: new TextEncoder().encode(actualSalt),
    iterations: 100000, hash: "SHA-256" }, key, 256);
  return { salt: actualSalt, hash: hex(new Uint8Array(bits)) };
}
export async function verifyBrowserPin(pin: string, protection: { salt: string; hash: string }): Promise<boolean> {
  if (!/^\d{4,8}$/.test(pin)) return false;
  return (await hashBrowserPin(pin, protection.salt)).hash === protection.hash;
}
const hijriNumbers = new Intl.DateTimeFormat("en-u-ca-islamic-umalqura", {
  timeZone: "Asia/Baghdad", day: "numeric", month: "numeric", year: "numeric",
});
const manualCache = new Map<string, number>();
function manualOffset(manual: NonNullable<BrowserPrayerSettings["hijriManualDate"]>) {
  const key = `${manual.anchor}-${manual.day}-${manual.month}`;
  if (manualCache.has(key)) return manualCache.get(key)!;
  const anchor = new Date(`${manual.anchor}T12:00:00+03:00`).getTime();
  const parts = (date: number) => Object.fromEntries(hijriNumbers.formatToParts(date).map((part) => [part.type, Number(part.value)]));
  const year = parts(anchor).year;
  for (let days = -370; days <= 370; days++) {
    const candidate = parts(anchor + days * 86400000);
    if (candidate.year === year && candidate.month === manual.month && candidate.day === manual.day) {
      manualCache.set(key, days); return days;
    }
  }
  throw new Error("اليوم الهجري غير موجود في هذا الشهر؛ قد يكون الشهر 29 يومًا.");
}
export function hijriDisplay(now: Date, settings: BrowserPrayerSettings) {
  const offset = (settings.hijriOffsetDays ?? 0) + (settings.hijriManualDate ? manualOffset(settings.hijriManualDate) : 0);
  return new Intl.DateTimeFormat("ar-IQ-u-ca-islamic-umalqura-nu-latn", {
    timeZone: "Asia/Baghdad", day: "numeric", month: "long", year: "numeric",
  }).format(new Date(now.getTime() + offset * 86400000));
}
export function hijriMonthAt(now: Date, settings: BrowserPrayerSettings) {
  const offset = (settings.hijriOffsetDays ?? 0) +
    (settings.hijriManualDate ? manualOffset(settings.hijriManualDate) : 0);
  return Number(hijriNumbers.formatToParts(new Date(now.getTime() + offset * 86400000))
    .find((part) => part.type === "month")?.value);
}
export function validateBrowserPreferences(settings: BrowserPrayerSettings): string | null {
  const error = settingsValidation(settings, browserRegions(settings).length > 0);
  if (error) return error;
  try { if (settings.hijriManualDate) manualOffset(settings.hijriManualDate); }
  catch (error) { return (error as Error).message; }
  return null;
}
