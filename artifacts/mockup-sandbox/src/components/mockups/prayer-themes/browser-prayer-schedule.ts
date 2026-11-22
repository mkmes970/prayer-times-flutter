import hawd6 from "../../../../../../mobile/prayer_times/assets/data/hawd6-prayer-times.json" with { type: "json" };
import abbasi from "../../../../../../mobile/prayer_times/assets/data/al-abbasi-prayer-times.json" with { type: "json" };
import dhuwaib from "../../../../../../mobile/prayer_times/assets/data/dhuwaib-prayer-times.json" with { type: "json" };
import hawija from "../../../../../../mobile/prayer_times/assets/data/hawija-prayer-times.json" with { type: "json" };
import tikrit from "../../../../../../mobile/prayer_times/assets/data/tikrit-prayer-times.json" with { type: "json" };
import baggara from "../../../../../../mobile/prayer_times/assets/data/baggara-prayer-times.json" with { type: "json" };
import shajara from "../../../../../../mobile/prayer_times/assets/data/shajara-prayer-times.json" with { type: "json" };
import alam from "../../../../../../mobile/prayer_times/assets/data/alam-prayer-times.json" with { type: "json" };

export const prayerKeys = ["fajrFirst", "fajrSecond", "sunrise", "dhuhr", "asr", "maghrib", "isha"] as const;
export type PrayerId = typeof prayerKeys[number];
export type AdhanPrayerId = Exclude<PrayerId, "fajrFirst" | "sunrise">;
export type BrowserTheme = "fajr" | "sunrise" | "dhuhr" | "asr" | "maghrib" | "isha";
export const prayerAnnouncementSeconds = 45;
export const adhanPrayers: { id: AdhanPrayerId; label: string }[] = [
  { id: "fajrSecond", label: "الفجر الثاني" }, { id: "dhuhr", label: "الظهر" },
  { id: "asr", label: "العصر" }, { id: "maghrib", label: "المغرب" }, { id: "isha", label: "العشاء" },
];
const tables = [{ id: "hawd6", ...hawd6 }, { id: "abbasi", ...abbasi }, { id: "dhuwaib", ...dhuwaib }, { id: "hawija", ...hawija }, { id: "tikrit", ...tikrit }, { id: "baggara", ...baggara }, { id: "shajara", ...shajara }, { id: "alam", ...alam }];
export const regionOptions = tables.map(({ id, name }) => ({ id, name }));
export type BrowserRegion = {
  id: string; name: string;
  months: { month: number; days: SourceDay[] }[];
  days?: Record<string, Record<PrayerId, string>>;
};
export type BrowserPrayerSettings = {
  regionId: string | null;
  iqamaMinutes: Partial<Record<AdhanPrayerId, number>>;
  preferencesVersion?: number;
  prayerDurationMinutes?: Partial<Record<AdhanPrayerId, number>>;
  postPrayerDhikrMinutes?: number | null;
  fridayKhutbahMinutes?: number | null;
  mosqueName?: string;
  showHijriDate?: boolean;
  hadithEnabled?: boolean;
  tickerScrollingEnabled?: boolean;
  tickerSpeed?: number;
  hijriOffsetDays?: number;
  hijriManualDate?: { day: number; month: number; anchor: string } | null;
  fontScale?: number; clockScale?: number; systemFont?: boolean;
  accentColor?: string;
  keepAwake?: boolean; immersiveMode?: boolean;
  pin?: { salt: string; hash: string } | null;
  regions?: BrowserRegion[];
  removedRegionIds?: string[];
};
export type BrowserPrayerAlert = { title: string; remaining: number | null; startsAt: number;
  endsAt?: number; prayerId?: AdhanPrayerId; showPhone?: boolean;
  kind?: "countdown" | "announcement" | "blackout" | "dhikr" | "khutbah" };
export const browserPrayerSettingsKey = "prayer-display.browser.settings.v1";
export const defaultIqamaMinutes = { fajrSecond: 20, dhuhr: 15, asr: 15, maghrib: 8, isha: 15 };
export const defaultPrayerDurationMinutes = { fajrSecond: 10, dhuhr: 8, asr: 8, maghrib: 7, isha: 10 };
export const emptyBrowserSettings: BrowserPrayerSettings = {
  preferencesVersion: 2, regionId: null, iqamaMinutes: defaultIqamaMinutes,
  prayerDurationMinutes: defaultPrayerDurationMinutes, postPrayerDhikrMinutes: 8,
  fridayKhutbahMinutes: 20, mosqueName: "", showHijriDate: true, hijriOffsetDays: 0,
  hadithEnabled: false,
  tickerScrollingEnabled: false, tickerSpeed: 32,
  hijriManualDate: null, fontScale: 1, clockScale: 1, systemFont: false,
  accentColor: "#17432e", keepAwake: true, immersiveMode: false, pin: null,
  regions: [], removedRegionIds: [],
};
const dayMilliseconds = 86400000;
const dateFormatter = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Baghdad", year: "numeric", month: "2-digit", day: "2-digit",
});

export function baghdadDay(now: Date) {
  const parts = dateFormatter.formatToParts(now);
  const value = (name: string) => Number(parts.find((part) => part.type === name)?.value);
  const year = value("year"), month = value("month"), day = value("day");
  return { year, month, day, weekday: new Date(Date.UTC(year, month - 1, day)).getUTCDay(),
    start: Date.UTC(year, month - 1, day) - 3 * 3600000 };
}

export type SourceDay = (typeof hawd6.months)[number]["days"][number];
const sourceKeys: Record<PrayerId, keyof SourceDay> = {
  fajrFirst: "fajr_first", fajrSecond: "fajr_second", sunrise: "sunrise",
  dhuhr: "dhuhr", asr: "asr", maghrib: "maghrib", isha: "isha",
};
export function decodePrayerTimes(row: SourceDay): Record<PrayerId, number> {
  let previous = -1;
  const result = {} as Record<PrayerId, number>;
  for (const id of prayerKeys) {
    const raw = String(row[sourceKeys[id]]);
    if (!/^\d{1,2}:[0-5]\d$/.test(raw)) throw new Error(`وقت غير صحيح: ${raw}`);
    const [hour, minute] = raw.split(":").map(Number);
    if (hour > 23) throw new Error(`ساعة غير صحيحة: ${raw}`);
    const candidates = hour === 0 || hour > 12
      ? [hour * 60 + minute] : [(hour % 12) * 60 + minute, (hour % 12) * 60 + minute + 720];
    const value = candidates.find((candidate) => candidate > previous);
    if (value === undefined) throw new Error(`ترتيب غير صحيح عند ${id}`);
    result[id] = value;
    previous = value;
  }
  return result;
}

export function browserRegions(settings?: BrowserPrayerSettings): BrowserRegion[] {
  // Old saved copies must not shadow the corrected bundled Fajr timetable.
  // Keep explicit dated edits and all independently edited annual cells.
  const overrides = (settings?.regions ?? []).map(region => {
    if (region.id !== "hawd6") return region;
    return { ...region, months: region.months.map(month => {
      if (month.month > 6) return month;
      return { ...month, days: month.days.map(row => {
        const source = hawd6.months.find(value => value.month === month.month)
          ?.days.find(value => value.day === row.day);
        if (!source) return row;
        const minutes = (time: string) => {
          const [h, m] = time.split(":").map(Number);
          return h * 60 + m;
        };
        return minutes(row.fajr_second) === minutes(source.fajr_first) + 15
          ? { ...row, fajr_second: source.fajr_second } : row;
      }) };
    }) };
  });
  return [...tables.filter((region) => !settings?.removedRegionIds?.includes(region.id) &&
    !overrides.some((other) => other.id === region.id)), ...overrides];
}
export function timesForRegion(regionId: string | null, now: Date, settings?: BrowserPrayerSettings) {
  const table = browserRegions(settings).find((region) => region.id === regionId);
  if (!table) return null;
  const { year, month, day } = baghdadDay(now);
  const key = `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  if (table.days?.[key]) return decodePrayerTimes(sourceDay(table.days[key], day));
  const row = table.months.find((entry) => entry.month === month)?.days.find((entry) => entry.day === day);
  return row ? decodePrayerTimes(row) : null;
}
export function sourceDay(values: Record<PrayerId, string>, day: number): SourceDay {
  return Object.fromEntries([["day", day], ...prayerKeys.map((id) => [sourceKeys[id], values[id]])]) as SourceDay;
}

export function formatPrayerTime(minutes: number) {
  return `${Math.floor(minutes / 60) % 12 || 12}:${String(minutes % 60).padStart(2, "0")}`;
}
export function countdownText(target: number | undefined, now: Date) {
  if (target === undefined) return "--:--:--";
  const seconds = Math.max(0, Math.ceil((target - now.getTime()) / 1000));
  return [Math.floor(seconds / 3600), Math.floor(seconds / 60) % 60, seconds % 60]
    .map((part) => String(part).padStart(2, "0")).join(":");
}

export function settingsValidation(value: unknown, requireRegion = true): string | null {
  if (!value || typeof value !== "object") return "إعدادات غير صحيحة.";
  const settings = value as BrowserPrayerSettings;
  if (settings.regions !== undefined && !Array.isArray(settings.regions)) return "بيانات المناطق غير صحيحة.";
  if (settings.removedRegionIds !== undefined && (!Array.isArray(settings.removedRegionIds) ||
    settings.removedRegionIds.some((id) => typeof id !== "string"))) return "قائمة المناطق المحذوفة غير صحيحة.";
  const ids = new Set<string>();
  try {
    for (const region of settings.regions ?? []) {
      if (!region || typeof region.id !== "string" || ids.has(region.id) || !region.name?.trim() ||
        !Array.isArray(region.months)) return "بيانات المنطقة غير صحيحة أو مكررة.";
      ids.add(region.id);
      const dates = new Set<string>();
      for (const month of region.months) {
        if (!Number.isInteger(month.month) || month.month < 1 || month.month > 12 || !Array.isArray(month.days)) return "شهر غير صحيح.";
        for (const row of month.days) {
          if (!Number.isInteger(row.day) || row.day < 1 || row.day > new Date(Date.UTC(2000, month.month, 0)).getUTCDate() ||
            dates.has(`${month.month}-${row.day}`)) return "يوم غير صحيح أو مكرر.";
          dates.add(`${month.month}-${row.day}`);
          decodePrayerTimes(row);
        }
      }
      for (const [date, values] of Object.entries(region.days ?? {})) {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || new Date(`${date}T00:00:00Z`).toISOString().slice(0, 10) !== date) return "تاريخ غير صحيح.";
        decodePrayerTimes(sourceDay(values, 1));
      }
    }
  } catch { return "المواقيت غير صحيحة أو ليست مرتبة."; }
  if ((requireRegion || settings.regionId !== null) &&
      !browserRegions(settings).some((region) => region.id === settings.regionId)) return "اختر منطقة من القائمة.";
  if (!settings.iqamaMinutes || typeof settings.iqamaMinutes !== "object" ||
      Array.isArray(settings.iqamaMinutes)) return "أوقات انتظار الإقامة غير صحيحة.";
  for (const [id, minutes] of Object.entries(settings.iqamaMinutes)) {
    if (!adhanPrayers.some((prayer) => prayer.id === id) ||
        !Number.isInteger(minutes) || minutes < 1 || minutes > 60) {
      return "انتظار الإقامة يجب أن يكون رقمًا صحيحًا من 1 إلى 60 دقيقة، أو يُترك فارغًا.";
    }
  }
  if (settings.prayerDurationMinutes !== undefined) {
    if (!settings.prayerDurationMinutes || typeof settings.prayerDurationMinutes !== "object") return "مدد الصلاة غير صحيحة.";
    for (const [id, minutes] of Object.entries(settings.prayerDurationMinutes)) {
      if (!adhanPrayers.some((prayer) => prayer.id === id) || !Number.isInteger(minutes) || minutes < 0 || minutes > 360) return "مدة الصلاة من صفر إلى 360 دقيقة.";
    }
  }
  for (const key of ["postPrayerDhikrMinutes", "fridayKhutbahMinutes"] as const) {
    const minutes = settings[key];
    if (minutes !== undefined && minutes !== null && (!Number.isInteger(minutes) || minutes < 0 || minutes > 360)) return "مدد الأذكار والخطبة من صفر إلى 360 دقيقة.";
  }
  if (settings.mosqueName !== undefined && (typeof settings.mosqueName !== "string" || settings.mosqueName.length > 100)) return "اسم المسجد أطول من المسموح.";
  for (const key of ["showHijriDate", "hadithEnabled", "tickerScrollingEnabled", "systemFont", "keepAwake", "immersiveMode"] as const) {
    if (settings[key] !== undefined && typeof settings[key] !== "boolean") return "خيار إعدادات غير صحيح.";
  }
  if (settings.tickerSpeed !== undefined &&
    (typeof settings.tickerSpeed !== "number" || !Number.isFinite(settings.tickerSpeed) ||
      settings.tickerSpeed < 8 || settings.tickerSpeed > 80)) return "سرعة تمرير الشريط غير صحيحة.";
  for (const [key, low, high] of [["fontScale", 0.8, 1.4], ["clockScale", 0.8, 1.3], ["hijriOffsetDays", -3, 3]] as const) {
    if (settings[key] !== undefined && (typeof settings[key] !== "number" || !Number.isFinite(settings[key]) || settings[key]! < low || settings[key]! > high)) return "قيمة المظهر أو التاريخ غير صحيحة.";
  }
  if (settings.accentColor !== undefined && !/^#[\da-f]{6}$/i.test(settings.accentColor)) return "لون غير صحيح.";
  if (settings.hijriManualDate && (!Number.isInteger(settings.hijriManualDate.day) || settings.hijriManualDate.day < 1 || settings.hijriManualDate.day > 30 ||
    !Number.isInteger(settings.hijriManualDate.month) || settings.hijriManualDate.month < 1 || settings.hijriManualDate.month > 12 ||
    !/^\d{4}-\d{2}-\d{2}$/.test(settings.hijriManualDate.anchor) ||
    new Date(`${settings.hijriManualDate.anchor}T00:00:00Z`).toISOString().slice(0, 10) !== settings.hijriManualDate.anchor)) return "تاريخ هجري يدوي غير صحيح.";
  if (settings.pin && (!/^[\da-f]{32}$/i.test(settings.pin.salt) || !/^[\da-f]{64}$/i.test(settings.pin.hash))) return "بيانات رمز الحماية غير صحيحة.";
  return null;
}

export function readBrowserPrayerSettings(): { settings: BrowserPrayerSettings; notice: string | null } {
  try {
    const raw = localStorage.getItem(browserPrayerSettingsKey);
    if (!raw) return { settings: emptyBrowserSettings, notice: null };
    const value: unknown = JSON.parse(raw);
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid stored settings");
    const parsed = value as BrowserPrayerSettings;
    const migrated = parsed?.preferencesVersion === 2 ? { ...emptyBrowserSettings, ...parsed } :
      { ...emptyBrowserSettings, ...parsed, preferencesVersion: 2, iqamaMinutes: defaultIqamaMinutes,
        prayerDurationMinutes: defaultPrayerDurationMinutes, postPrayerDhikrMinutes: 8, fridayKhutbahMinutes: 20 };
    if (settingsValidation(migrated, false)) {
      return { settings: emptyBrowserSettings, notice: "تعذر قراءة الإعدادات السابقة. اختر المنطقة واحفظها من جديد." };
    }
    if (parsed.preferencesVersion !== 2) {
      try { localStorage.setItem(browserPrayerSettingsKey, JSON.stringify(migrated)); }
      catch { return { settings: migrated, notice: "طُبقت الأوقات الافتراضية، لكن تعذر حفظها في هذا المتصفح. أعد الحفظ من الضبط." }; }
    }
    return { settings: migrated, notice: null };
  } catch {
    return { settings: emptyBrowserSettings, notice: "تعذر الوصول إلى حفظ الإعدادات في هذا المتصفح." };
  }
}

export function prayerDashboard(now: Date, settings: BrowserPrayerSettings) {
  const today = baghdadDay(now);
  const times = timesForRegion(settings.regionId, now, settings);
  const timestamp = now.getTime();
  const events = [-1, 0, 1].flatMap((offset) => {
    const date = new Date(today.start + offset * dayMilliseconds);
    const day = baghdadDay(date);
    const values = timesForRegion(settings.regionId, date, settings);
    return values ? adhanPrayers.map((prayer) => {
      const adhanAt = day.start + values[prayer.id] * 60000;
      const wait = day.weekday === 5 && prayer.id === "dhuhr" ? undefined : settings.iqamaMinutes[prayer.id];
      const fridayNoon = day.weekday === 5 && prayer.id === "dhuhr";
      const duration = settings.prayerDurationMinutes === undefined
        ? defaultPrayerDurationMinutes[prayer.id] : settings.prayerDurationMinutes[prayer.id] ?? 0;
      const khutbah = settings.fridayKhutbahMinutes === undefined ? 20 : settings.fridayKhutbahMinutes ?? 0;
      const highlightedUntil = fridayNoon
        ? adhanAt + khutbah * 60000
        : wait === undefined ? adhanAt + 15000 : adhanAt + (wait + duration) * 60000;
      return { ...prayer, iqamaLabel: prayer.id === "fajrSecond" ? "الفجر" : prayer.label,
        adhanAt, highlightedUntil, iqamaAt: wait === undefined ? undefined : adhanAt + wait * 60000 };
    }) : [];
  });
  const nextPrayer = events.find((event) => event.adhanAt > timestamp);
  const currentPrayer = events.filter((event) =>
    timestamp >= event.adhanAt && timestamp < event.highlightedUntil).at(-1);
  const iqama = events.find((event) => event.iqamaAt !== undefined &&
    timestamp >= event.adhanAt && timestamp < event.iqamaAt);
  const alerts: BrowserPrayerAlert[] = [];
  const addAlert = (start: number, end: number, title: string, countdown: boolean,
    kind: BrowserPrayerAlert["kind"] = countdown ? "countdown" : "announcement",
    prayerId?: AdhanPrayerId, showPhone = false) => {
    if (timestamp >= start && timestamp < end) alerts.push({
      startsAt: start, endsAt: end, prayerId, showPhone, title, kind, remaining: countdown ? Math.ceil((end - timestamp) / 1000) : null,
    });
  };
  const dhikrMinutes = settings.postPrayerDhikrMinutes === undefined ? 8 : settings.postPrayerDhikrMinutes ?? 0;
  for (const event of events) {
    const fridayNoon = baghdadDay(new Date(event.adhanAt)).weekday === 5 && event.id === "dhuhr";
    addAlert(event.adhanAt - 30000, event.adhanAt, `الوقت المتبقي لأذان ${event.label}`, true, "countdown", event.id, fridayNoon);
    if (!fridayNoon) addAlert(event.adhanAt, event.adhanAt + 15000, `حان موعد أذان ${event.label}`, false);
    if (event.iqamaAt !== undefined) {
      addAlert(event.iqamaAt - 30000, event.iqamaAt, "الوقت المتبقي لإقامة الصلاة", true, "countdown", event.id, true);
      const minutes = settings.prayerDurationMinutes === undefined
        ? defaultPrayerDurationMinutes[event.id] : settings.prayerDurationMinutes[event.id] ?? 0;
      const prayerEnd = event.iqamaAt + minutes * 60000;
      const announceEnd = event.iqamaAt + prayerAnnouncementSeconds * 1000;
      addAlert(event.iqamaAt, announceEnd, "الصلاة قائمة", false);
      if (minutes > 0) {
        addAlert(announceEnd, prayerEnd, "الصلاة قائمة", false, "blackout");
        addAlert(prayerEnd, prayerEnd + dhikrMinutes * 60000, "أذكار بعد الصلاة", true, "dhikr", event.id);
      }
    } else if (baghdadDay(new Date(event.adhanAt)).weekday === 5 && event.id === "dhuhr") {
      const khutbah = settings.fridayKhutbahMinutes === undefined ? 20 : settings.fridayKhutbahMinutes ?? 0;
      if (khutbah > 0) {
        const khutbahEnd = event.adhanAt + khutbah * 60000;
        const introductionEnd = Math.min(event.adhanAt + 60000, khutbahEnd);
        addAlert(event.adhanAt, introductionEnd, "استمع للخطبة", false, "khutbah", event.id);
        addAlert(introductionEnd, khutbahEnd, "استمع للخطبة بارك الله فيك", false, "blackout", event.id);
        addAlert(khutbahEnd, khutbahEnd + dhikrMinutes * 60000, "أذكار بعد الصلاة", true, "dhikr", event.id);
      }
    }
  }
  const periods: [PrayerId, BrowserTheme][] = [
    ["fajrSecond", "fajr"], ["sunrise", "sunrise"], ["dhuhr", "dhuhr"],
    ["asr", "asr"], ["maghrib", "maghrib"], ["isha", "isha"],
  ];
  const period = times ? periods.filter(([id]) => timestamp >= today.start + times[id] * 60000).at(-1) : undefined;
  return {
    times, nextPrayer, iqama, activePrayerId: (currentPrayer ?? nextPrayer)?.id ?? null,
    theme: period?.[1] ?? "isha",
    alert: alerts.sort((a, b) => {
      const priority = (alert: BrowserPrayerAlert) => alert.kind === "countdown" || alert.kind === "announcement" ? 1 : 0;
      return priority(b) - priority(a) || b.startsAt - a.startsAt;
    })[0] ?? null,
    fridayHadiths: today.weekday === 5,
  };
}
