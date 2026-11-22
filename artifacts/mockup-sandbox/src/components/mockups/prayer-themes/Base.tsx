import "./prayer-themes.css";
import { useEffect, useLayoutEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { NewsTicker } from "./NewsTicker";
import { HadithPanel } from "./HadithPanel";
import { hadithDurationSeconds, normalInformationSeconds } from "./hadith-timing";
import hadithCatalogue from "../../../../../../mobile/prayer_times/assets/data/dashboard-hadiths.json";
import { HadithRotation } from "./hadith-rotation";
import { fridayHadithWindowActive } from "./friday-hadith-window";
import eveningSource from "../../../../../../mobile/prayer_times/assets/data/evening-adhkar.txt?raw";
import morningSource from "../../../../../../mobile/prayer_times/assets/data/morning-adhkar.txt?raw";
import { morningPlaylist, morningItemAt, morningWindowActive, morningStartsAt } from "./morning-adhkar";
import { englishDigits } from "./english-digits";
import { eveningItemAt, eveningPlaylist, eveningWindowActive, parseEveningAdhkar } from "./evening-adhkar";
import { dailyImageHadiths } from "./daily-hadiths";
import ramadanCatalogue from "../../../../../../mobile/prayer_times/assets/data/ramadan-hadiths.json";
import abuHurayraCatalogue from "../../../../../../mobile/prayer_times/assets/data/abu-hurayra-50-hadiths.json";
import adhanCatalogue from "../../../../../../mobile/prayer_times/assets/data/adhan-hadiths.json";
import adhanExplanations from "../../../../../../mobile/prayer_times/assets/data/adhan-explanations.json";
import { adhanWindowEnd } from "./adhan-hadiths";
import { AdhanPlayback, adhanProgressKey } from "./adhan-playback";
import { PrayerAlertPreview } from "./PrayerAlertPreview";
import { PrayerSettingsDialog } from "./PrayerSettingsDialog";
import {
  browserPrayerSettingsKey, readBrowserPrayerSettings, browserRegions, baghdadDay,
  prayerDashboard, countdownText, formatPrayerTime,
  type BrowserPrayerSettings, type PrayerId,
} from "./browser-prayer-schedule";
import { hijriDisplay, hijriMonthAt, validateBrowserPreferences } from "./browser-prayer-preferences";
import { landscapeDisplaySize, enterPrayerFullscreen } from "./display-viewport";
import { OrnamentalFrame } from "./OrnamentalFrame";

type ThemeKey = "fajr" | "sunrise" | "dhuhr" | "asr" | "maghrib" | "isha";

// Defer DOM writes so observers cannot generate resize-loop runtime errors.
function observeDisplayResize(element: Element, resize: () => void) {
  resize();
  let frame = 0;
  const observer = new ResizeObserver(() => {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(resize);
  });
  observer.observe(element);
  return () => {
    observer.disconnect();
    cancelAnimationFrame(frame);
  };
}

const themeDetails: Record<ThemeKey, { orb: "sun" | "moon" | "none" }> = {
  fajr: { orb: "moon" },
  sunrise: { orb: "sun" },
  dhuhr: { orb: "none" },
  asr: { orb: "sun" },
  maghrib: { orb: "sun" },
  isha: { orb: "moon" },
};

const prayers = [
  { id: "fajrFirst", name: "الفجر الأول", icon: "crescent" },
  { id: "fajrSecond", name: "الفجر الثاني", icon: "crescent" },
  { id: "sunrise", name: "الشروق", icon: "rise" },
  { id: "dhuhr", name: "الظهر", icon: "sun" },
  { id: "asr", name: "العصر", icon: "cloud" },
  { id: "maghrib", name: "المغرب", icon: "set" },
  { id: "isha", name: "العشاء", icon: "crescent" },
];

function PrayerSymbol({ kind }: { kind: string }) {
  if (kind === "crescent") {
    return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M16.8 3.7A8.7 8.7 0 1 0 20.3 17 7.5 7.5 0 0 1 16.8 3.7Z" fill="currentColor" /></svg>;
  }
  if (kind === "rise") {
    return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v13m-5-5 5-5 5 5M5 20h14" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" /></svg>;
  }
  if (kind === "sun") {
    return <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4" fill="currentColor" /><path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" /></svg>;
  }
  if (kind === "cloud") {
    return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6.2 17.5h11a3.3 3.3 0 0 0 .3-6.6 5.7 5.7 0 0 0-10.8-1.2 4 4 0 0 0-.5 7.8Z" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" /></svg>;
  }
  return <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 18h16M7 15l5-5 5 5M12 10V4" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

function MosqueSilhouette() {
  return (
    <div className="mosque-backdrop" aria-hidden="true">
      <svg viewBox="0 0 560 150" preserveAspectRatio="none">
        <g className="mosque-fill">
          <path d="M0 133h560v17H0z" opacity=".55" />
          <path d="M69 133c1-17 13-29 27-29s26 12 27 29ZM422 133c1-17 13-29 27-29s26 12 27 29Z" opacity=".55" />
          <path d="M67 150v-48l5-7 5 7v48Zm416 0v-48l5-7 5 7v48Z" opacity=".65" />
          <path d="M67 108h10m-9 14h8m408-14h10m-9 14h8" opacity=".45" />
          <path d="M67 150v-20c31-8 65-8 96 0v-9h234v-8c31-8 65-8 96 0v37Z" />
          <path d="M99 121c1-16 13-28 29-28s28 12 29 28Zm81 0c2-20 17-35 36-35s34 15 36 35Zm58 0c2-27 21-47 42-47s40 20 42 47Zm76 0c2-20 17-35 36-35s34 15 36 35Zm83 0c1-16 13-28 29-28s28 12 29 28Z" />
          <path d="M96 150v-29l5-7 5 7v29Zm353 0v-29l5-7 5 7v29ZM162 121V92l5-6 5 6v29Zm225 0V92l5-6 5 6v29Z" />
        </g>
        <g className="mosque-line">
          <path d="M115 120q2-23 13-34m14 0q11 11 13 34m-27-29v-9m44 38q3-32 20-47m19 0q17 15 20 47m-39-39v-11m62 50q4-43 23-64m19 0q19 21 23 64m-42-55v-14m62 69q3-32 20-47m19 0q17 15 20 47m-39-39v-11m44 11q2 23 13 34m14 0q11-11 13-34m-27 5v-9M96 126h10m343 0h10M95 139h12m339 0h12" />
          <path d="M67 130q48-10 96 0m0-9h234m0-8q48-10 96 0" />
        </g>
      </svg>
    </div>
  );
}

function Atmosphere({ theme, orb }: { theme: ThemeKey; orb: "sun" | "moon" | "none" }) {
  return (
    <div className="sky-motifs" aria-hidden="true">
      <div className="starfield">{Array.from({ length: 8 }, (_, index) => <i key={index} />)}</div>
      <div className="horizon-line" />
      <div className="cloud-wash one" />
      <div className="cloud-wash two" />
      {orb === "sun" && <div className="sun-disc" />}
      {orb === "moon" && <div className="moon-disc" />}
      {theme === "asr" && <div className="cloud-wash one directional-shadow" />}
    </div>
  );
}

export function PrayerThemeBase({ theme: previewTheme }: { theme: ThemeKey }) {
  const viewportRef = useRef<HTMLDivElement>(null);
  const previewRef = useRef<HTMLElement>(null);
  const ribbonRef = useRef<HTMLDivElement>(null);
  const layoutRef = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const viewport = viewportRef.current;
    const preview = previewRef.current;
    if (!viewport || !preview) return;
    const resize = () => {
      const size = landscapeDisplaySize(viewport.clientWidth, viewport.clientHeight);
      preview.style.width = `${size.width}px`;
      preview.style.height = `${size.height}px`;
      preview.style.setProperty("--display-rotation", `${size.rotation}deg`);
    };
    return observeDisplayResize(viewport, resize);
  }, []);
  useLayoutEffect(() => {
    const ribbon = ribbonRef.current;
    if (!ribbon) return;
    const resize = () => previewRef.current?.style.setProperty(
      "--ribbon-space", `${ribbon.offsetHeight + 11}px`,
    );
    return observeDisplayResize(ribbon, resize);
  }, []);
  useLayoutEffect(() => {
    const layout = layoutRef.current;
    if (!layout) return;
    const main = layout.querySelector<HTMLElement>(".prayer-main")!;
    const icon = layout.querySelector<HTMLElement>(".prayer-icon")!;
    const layoutLeft = (element: HTMLElement) => {
      let left = 0;
      let current: HTMLElement | null = element;
      while (current && current !== layout) {
        left += current.offsetLeft;
        current = current.offsetParent as HTMLElement | null;
      }
      return left;
    };
    const resize = () => {
      const left = layoutLeft(main) +
        parseFloat(getComputedStyle(main).paddingLeft);
      const width = Math.max(0, layoutLeft(icon) - 12 - left);
      main.style.setProperty("--hadith-panel-width", `${width}px`);
    };
    return observeDisplayResize(layout, resize);
  }, []);
  const [now, setNow] = useState(() => new Date());
  const [savedSettings, setSavedSettings] = useState(readBrowserPrayerSettings);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [deviceNotice, setDeviceNotice] = useState<string | null>(null);
  const [adhanProgress] = useState(() => {
    try {
      const raw = localStorage.getItem(adhanProgressKey);
      const index = raw === null ? 0 : JSON.parse(raw).index;
      if (!Number.isInteger(index) || index < 0) throw new Error("Invalid adhan progress");
      return { player: new AdhanPlayback(index), error: false };
    } catch (error) {
      console.error("Cannot read adhan playback progress", error);
      return { player: new AdhanPlayback(), error: true };
    }
  });
  useEffect(() => {
    if (adhanProgress.error) setDeviceNotice("تعذر قراءة موضع أحاديث الأذان المحفوظ؛ بدأ التسلسل من البداية.");
  }, [adhanProgress]);
  const enterFullscreen = async () => {
    if (viewportRef.current) {
      setDeviceNotice(await enterPrayerFullscreen(viewportRef.current));
    }
  };
  const dashboard = prayerDashboard(now, savedSettings.settings);
  const adhanTimes = [now, new Date(now.getTime() + 86400000)].flatMap(day => {
    const times = prayerDashboard(day, savedSettings.settings).times;
    return times ? Object.entries(times)
      .filter(([id]) => id !== "sunrise")
      .map(([, minutes]) => baghdadDay(day).start + minutes * 60000) : [];
  });
  const adhanEndsAt = adhanWindowEnd(now.getTime(), adhanTimes);
  const adhanActive = adhanEndsAt !== null;
  const adhanEntry = adhanProgress.player.at(
    [...adhanExplanations.entries, ...adhanCatalogue.entries], now.getTime(), adhanEndsAt,
    Boolean(dashboard.alert) || settingsOpen || document.visibilityState !== "visible");
  const adhanIndex = adhanProgress.player.index;
  useEffect(() => {
    try {
      localStorage.setItem(adhanProgressKey, JSON.stringify({ index: adhanIndex }));
    } catch (error) {
      console.error("Cannot save adhan playback progress", error);
      setDeviceNotice("تعذر حفظ موضع أحاديث الأذان على هذا الجهاز.");
    }
  }, [adhanIndex]);
  const maghribAt = dashboard.times
    ? baghdadDay(now).start + dashboard.times.maghrib * 60000 : null;
  const eveningEnd = (maghribAt ?? 0) + (
    (savedSettings.settings.iqamaMinutes.maghrib ?? 0) +
    (savedSettings.settings.prayerDurationMinutes === undefined ? 7 :
      savedSettings.settings.prayerDurationMinutes.maghrib ?? 0)
  ) * 60000;
  const allHadiths = useMemo(() => [
    ...hadithCatalogue.ordered, ...hadithCatalogue.random, ...dailyImageHadiths,
    ...abuHurayraCatalogue.entries, ...adhanCatalogue.entries,
    ...hadithCatalogue.friday, ...hadithCatalogue.fridayAdditional,
    ...ramadanCatalogue.entries,
  ], []);
  const eveningPreview = Number(new URLSearchParams(window.location.search).get("eveningEntry"));
  const eveningActive = (eveningPreview >= 1 && eveningPreview <= 26) ||
    eveningWindowActive(now.getTime(), maghribAt, eveningEnd);
  const eveningItems = useMemo(() => eveningPlaylist(eveningSource, allHadiths,
    Math.floor((maghribAt ?? baghdadDay(now).start) / 1000)), [allHadiths, maghribAt]);
  const eveningEntry = eveningPreview >= 1 && eveningPreview <= 26
    ? { entry: parseEveningAdhkar(eveningSource)[eveningPreview - 1], recitation: true }
    : eveningItemAt(eveningItems, now.getTime(), maghribAt, eveningEnd);
  const theme = dashboard.times ? dashboard.theme : previewTheme;
  const morningStart = morningStartsAt(
    dashboard.times ? baghdadDay(now).start + dashboard.times.fajrSecond * 60000 : null,
    savedSettings.settings.iqamaMinutes.fajrSecond,
    savedSettings.settings.prayerDurationMinutes === undefined ? 10 : savedSettings.settings.prayerDurationMinutes.fajrSecond ?? 0,
    savedSettings.settings.postPrayerDhikrMinutes === undefined ? 8 : savedSettings.settings.postPrayerDhikrMinutes ?? 0);
  const morningEnd = dashboard.times ? baghdadDay(now).start + (dashboard.times.sunrise + 10) * 60000 : null;
  const morningActive = morningWindowActive(now.getTime(), morningStart, morningEnd);
  const morningItems = useMemo(() => morningPlaylist(morningSource, allHadiths,
    baghdadDay(now).start / 1000), [allHadiths, baghdadDay(now).start]);
  const morningItem = morningItemAt(morningItems, now.getTime(), morningStart, morningEnd);
  const fridayHadithEnd = dashboard.times
    ? baghdadDay(now).start + (dashboard.times.isha +
      (savedSettings.settings.iqamaMinutes.isha ?? 0) +
      (savedSettings.settings.prayerDurationMinutes === undefined ? 10 :
        savedSettings.settings.prayerDurationMinutes.isha ?? 0) +
      (savedSettings.settings.postPrayerDhikrMinutes === undefined ? 8 :
        savedSettings.settings.postPrayerDhikrMinutes ?? 0)) * 60000
    : null;
  const fridayMode = fridayHadithWindowActive(
    now.getTime(), baghdadDay(now).weekday, morningEnd, fridayHadithEnd) ||
    new URLSearchParams(window.location.search).get("friday") === "true";
  const ramadanMode = hijriMonthAt(now, savedSettings.settings) === 9 &&
    (baghdadDay(now).weekday !== 5 || fridayMode);
  const region = browserRegions(savedSettings.settings).find((option) => option.id === savedSettings.settings.regionId);
  const saveSettings = (value: BrowserPrayerSettings): string | null => {
    const error = validateBrowserPreferences(value);
    if (error) return error;
    try {
      localStorage.setItem(browserPrayerSettingsKey, JSON.stringify(value));
    } catch {
      return "تعذر حفظ الاختيار. اسمح للمتصفح بحفظ بيانات الموقع ثم حاول مرة أخرى.";
    }
    setSavedSettings({ settings: value, notice: null });
    setSettingsOpen(false);
    if (value.immersiveMode && !document.fullscreenElement) {
      void enterFullscreen();
    } else if (!value.immersiveMode && document.fullscreenElement) {
      void document.exitFullscreen().catch(() => setDeviceNotice("تعذر إغلاق وضع ملء الشاشة."));
    }
    return null;
  };
  useEffect(() => {
    if (!savedSettings.settings.keepAwake) return;
    let sentinel: WakeLockSentinel | undefined;
    let cancelled = false;
    const acquire = async () => {
      if (document.visibilityState !== "visible") return;
      if (!("wakeLock" in navigator)) {
        setDeviceNotice("هذا المتصفح لا يدعم إبقاء الشاشة مضاءة تلقائيًا."); return;
      }
      try {
        const lock = await navigator.wakeLock.request("screen");
        if (cancelled) await lock.release();
        else { sentinel = lock; setDeviceNotice(null); }
      } catch {
        setDeviceNotice("تعذر إبقاء الشاشة مضاءة؛ قد تمنع نافذة العرض أو توفير البطارية ذلك.");
      }
    };
    void acquire();
    document.addEventListener("visibilitychange", acquire);
    return () => {
      cancelled = true;
      document.removeEventListener("visibilitychange", acquire);
      void sentinel?.release().catch(() => {});
    };
  }, [savedSettings.settings.keepAwake]);
  useEffect(() => {
    const update = (event: StorageEvent) => {
      if (event.key === browserPrayerSettingsKey || event.key === null) setSavedSettings(readBrowserPrayerSettings());
    };
    window.addEventListener("storage", update);
    return () => window.removeEventListener("storage", update);
  }, []);
  const hadithRotationRef = useRef<HadithRotation | null>(null);
  if (!hadithRotationRef.current) {
    const fridayEntries = [...hadithCatalogue.friday, ...hadithCatalogue.fridayAdditional];
    const generalRandomHadiths = [
      ...hadithCatalogue.random,
      ...dailyImageHadiths,
      ...abuHurayraCatalogue.entries,
      ...adhanCatalogue.entries,
    ];
    const rotation = new HadithRotation(
      hadithCatalogue.ordered,
      generalRandomHadiths,
      fridayEntries,
      ramadanCatalogue.entries,
    );
    rotation.setFridayMode(fridayMode);
    rotation.setRamadanMode(ramadanMode);
    const startEntry = Number(new URLSearchParams(window.location.search).get("fridayEntry"));
    if (rotation.isFridayMode && Number.isInteger(startEntry) &&
        startEntry >= 1 && startEntry <= fridayEntries.length) {
      rotation.selectForPreview(fridayEntries[startEntry - 1]);
    }
    // Select a source entry only for previewing; subsequent playback still
    // advances through normal random playback.
    const dailyEntry = Number(new URLSearchParams(window.location.search).get("dailyEntry"));
    if (!rotation.isFridayMode && Number.isInteger(dailyEntry) &&
        dailyEntry >= 1 && dailyEntry <= dailyImageHadiths.length) {
      rotation.selectForPreview(dailyImageHadiths[dailyEntry - 1]);
    }
    hadithRotationRef.current = rotation;
  }
  const hadithRotation = hadithRotationRef.current;
  const [currentHadith, setCurrentHadith] = useState(() => hadithRotation.current);
  useEffect(() => {
    if (hadithRotation.isFridayMode !== fridayMode) {
      hadithRotation.setFridayMode(fridayMode);
      setCurrentHadith(hadithRotation.current);
    }
    hadithRotation.setRamadanMode(ramadanMode);
    setCurrentHadith(hadithRotation.current);
  }, [fridayMode, ramadanMode, hadithRotation]);
  // The query only selects the initial preview state for a screenshot.
  const [showHadith, setShowHadith] = useState(
    () => new URLSearchParams(window.location.search).get("panel") === "hadith",
  );
  const hadithEnabled = savedSettings.settings.hadithEnabled === true;
  useEffect(() => {
    if (adhanActive || eveningActive || morningActive) {
      setShowHadith(false);
      return;
    }
    if (!hadithEnabled) {
      setShowHadith(false);
      return;
    }
    const timer = window.setInterval(() => {
      if (!document.hidden) {
        if (showHadith) setCurrentHadith(hadithRotation.next());
        setShowHadith((visible) => !visible);
      }
    }, (showHadith ? hadithDurationSeconds(currentHadith) : normalInformationSeconds) * 1000);
    return () => window.clearInterval(timer);
  }, [showHadith, currentHadith, hadithRotation, hadithEnabled, eveningActive, adhanActive, morningActive]);
  const contentVisible = adhanActive ? Boolean(adhanEntry)
    : morningActive ? Boolean(morningItem) : eveningActive ? Boolean(eveningEntry) : hadithEnabled && showHadith;
  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  const clock = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Baghdad",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h12",
  }).formatToParts(now).filter((part) => part.type !== "dayPeriod").map((part) => part.value).join("").trim();
  const weekday = new Intl.DateTimeFormat("ar-IQ", {
    timeZone: "Asia/Baghdad",
    weekday: "long",
  }).format(now);
  const gregorianParts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Baghdad",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(now).split("/");
  const activePrayer = dashboard.activePrayerId;
  const details = themeDetails[theme];
  const themeClass = `${theme}-theme`;
  return (
    <div ref={viewportRef} className="prayer-display-viewport">
    <main ref={previewRef} className={`prayer-preview ${themeClass} ${savedSettings.settings.systemFont ? "system-font" : ""}`}
      style={{
        "--font-scale": savedSettings.settings.fontScale ?? 1,
        "--clock-scale": savedSettings.settings.clockScale ?? 1,
        "--card-bg": savedSettings.settings.accentColor ?? "#17432e",
        "--card-ink": "#fff4ce",
        "--icon-bg": savedSettings.settings.accentColor ?? "#17432e",
      } as CSSProperties}>
      <PrayerAlertPreview activeAlert={dashboard.alert} clock={clock} />
      {settingsOpen && <PrayerSettingsDialog
        initialSettings={{
          ...savedSettings.settings,
          immersiveMode: Boolean(document.fullscreenElement) || savedSettings.settings.immersiveMode,
        }}
        storageNotice={[savedSettings.notice, deviceNotice].filter(Boolean).join(" ") || undefined}
        onSave={saveSettings}
        onClose={() => setSettingsOpen(false)}
      />}
      <div className="sky-light" />
      <Atmosphere theme={theme} orb={details.orb} />
      <MosqueSilhouette />
      <OrnamentalFrame className="ornate-frame" />
      <div className="top-rule" />
      <button className="fullscreen-control" type="button" onClick={() => void enterFullscreen()}
        aria-label="ملء الشاشة والعرض الأفقي" title="ملء الشاشة والعرض الأفقي">
        <svg viewBox="0 0 24 24" width="17" height="17" aria-hidden="true">
          <path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5"
            fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
        </svg>
      </button>
      {deviceNotice && !settingsOpen &&
        <button className="display-notice" onClick={() => setDeviceNotice(null)}>{deviceNotice} اضغط لإخفاء التنبيه.</button>}
      <div className="botanical botanical-left" aria-hidden="true">
        <svg viewBox="0 0 150 110">
          <path d="M3 7c36 18 63 45 96 89" className="branch-stem" />
          <path d="M23 20C6 9 3 1 4 0c15 2 27 7 30 22-5 3-8 2-11-2Z" className="branch-leaf" />
          <path d="M40 34C37 15 42 7 44 6c9 13 12 25 2 36-5-1-7-4-6-8Z" className="branch-leaf" />
          <path d="M56 49C38 42 33 34 33 32c16-2 28 1 34 15-3 5-7 5-11 2Z" className="branch-leaf" />
          <path d="M73 65C70 47 75 38 77 37c9 13 12 25 2 36-5-1-7-4-6-8Z" className="branch-leaf" />
          <path d="M89 80C72 74 66 66 66 64c16-2 28 1 34 15-3 5-7 5-11 2Z" className="branch-leaf" />
          <circle cx="22" cy="13" r="4" className="branch-flower" />
          <circle cx="59" cy="43" r="3.5" className="branch-flower" />
        </svg>
      </div>
      <div className="botanical botanical-right" aria-hidden="true">
        <svg viewBox="0 0 150 110">
          <path d="M3 7c36 18 63 45 96 89" className="branch-stem" />
          <path d="M23 20C6 9 3 1 4 0c15 2 27 7 30 22-5 3-8 2-11-2Z" className="branch-leaf" />
          <path d="M40 34C37 15 42 7 44 6c9 13 12 25 2 36-5-1-7-4-6-8Z" className="branch-leaf" />
          <path d="M56 49C38 42 33 34 33 32c16-2 28 1 34 15-3 5-7 5-11 2Z" className="branch-leaf" />
          <path d="M73 65C70 47 75 38 77 37c9 13 12 25 2 36-5-1-7-4-6-8Z" className="branch-leaf" />
          <path d="M89 80C72 74 66 66 66 64c16-2 28 1 34 15-3 5-7 5-11 2Z" className="branch-leaf" />
          <circle cx="22" cy="13" r="4" className="branch-flower" />
          <circle cx="59" cy="43" r="3.5" className="branch-flower" />
        </svg>
      </div>
      {!contentVisible && <>
        <div className="hanging-lantern lantern-left" aria-hidden="true"><Lantern /></div>
        <div className="hanging-lantern lantern-center" aria-hidden="true"><Lantern /></div>
      </>}
      <button className="settings-control" type="button" aria-label="الضبط" onClick={() => setSettingsOpen(true)}>
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" aria-hidden="true">
          <path d="M9.7 3.5h4.6l.5 2.2c.5.2 1 .5 1.4.8l2.2-.7 2.3 4-1.7 1.5v1.6l1.7 1.5-2.3 4-2.2-.7c-.4.3-.9.6-1.4.8l-.5 2.2H9.7l-.5-2.2c-.5-.2-1-.5-1.4-.8l-2.2.7-2.3-4L5 12.9v-1.6l-1.7-1.5 2.3-4 2.2.7c.4-.3.9-.6 1.4-.8l.5-2.2Z" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round" />
          <circle cx="12" cy="12.1" r="2.6" stroke="currentColor" strokeWidth="1.5" />
        </svg>
      </button>
      <div className="prayer-layout" ref={layoutRef}>
        <section className="prayer-main" aria-label="معلومات اليوم">
          {contentVisible ? (
            <HadithPanel
              entry={adhanActive ? adhanEntry! : morningActive ? morningItem!.entry : eveningEntry?.entry ?? currentHadith}
              evening={!adhanActive && (morningActive ? morningItem!.recitation : eveningEntry?.recitation === true)}
            />
          ) : <div className="calendar-block">
            <div className="screen-title" title={savedSettings.settings.mosqueName?.trim() || "مواقيت الصلاة"}>
              {englishDigits(savedSettings.settings.mosqueName?.trim() || "مواقيت الصلاة")}
            </div>
            <div className="clock-time">{clock}</div>
            <div className="weekday">{weekday}</div>
            <div className="date-line" dir="rtl">
              {gregorianParts
                .flatMap((part, index) => (index < 2 ? [part, "/"] : [part]))
                .map((part, index) => <span key={`${part}-${index}`}>{part}</span>)}
            </div>
            {savedSettings.settings.showHijriDate !== false &&
              <div className="hijri-line" dir="rtl">{hijriDisplay(now, savedSettings.settings)}</div>}
            {!region && <div className="selected-region-label">اختر المنطقة من الضبط</div>}
            {savedSettings.notice && <div role="status" className="selected-region-label">{savedSettings.notice}</div>}
            {region && !dashboard.times && <div role="alert">لا توجد مواقيت لهذه المنطقة اليوم.</div>}
          </div>}
          <div className="countdown-pair">
            <div className="countdown-card">
              <OrnamentalFrame className="countdown-card__ornament" />
              <div className="countdown-label">{dashboard.nextPrayer
                ? `الوقت المتبقي لصلاة ${dashboard.nextPrayer.label}` : "الوقت المتبقي للصلاة التالية"}</div>
              <div className="countdown-value">{countdownText(dashboard.nextPrayer?.adhanAt, now)}</div>
            </div>
            <div className="countdown-card">
              <OrnamentalFrame className="countdown-card__ornament" />
              <div className="countdown-label">{dashboard.iqama
                ? `الوقت المتبقي لإقامة صلاة ${dashboard.iqama.iqamaLabel}` : "الوقت المتبقي للإقامة"}</div>
              <div className="countdown-value">{countdownText(dashboard.iqama?.iqamaAt, now)}</div>
            </div>
          </div>
        </section>
        <section className="prayer-list" aria-label="مواقيت الصلاة">
          {prayers.map((prayer) => (
            <div className={`prayer-row ${activePrayer === prayer.id ? "active" : ""}`} key={prayer.id}>
              <span className="prayer-name">{prayer.name}</span>
              <span className="prayer-time">{dashboard.times
                ? formatPrayerTime(dashboard.times[prayer.id as PrayerId]) : "--:--"}</span>
              <span className="prayer-icon"><PrayerSymbol kind={prayer.icon} /></span>
            </div>
          ))}
        </section>
      </div>
      <div ref={ribbonRef} className="bottom-ribbon">
        <OrnamentalFrame className="bottom-ribbon__ornament" />
        <NewsTicker
          scrollingEnabled={savedSettings.settings.tickerScrollingEnabled ?? false}
          speed={savedSettings.settings.tickerSpeed ?? 32}
        />
      </div>
    </main>
    </div>
  );
}

function Lantern() {
  return (
    <svg viewBox="0 0 44 88" aria-hidden="true">
      <path d="M22 0v16" className="lantern-hanger" />
      <path d="M14 15h16l-3 6h-10l-3-6Zm-2 8h20l-3 8v34l-7 8-7-8V31l-3-8Z" className="lantern-body" />
      <path d="M12 31h20M14 61h16M18 22v45m8-45v45" className="lantern-detail" />
      <circle cx="22" cy="45" r="5" className="lantern-glow" />
      <path d="M19 75h6l-3 8-3-8Z" className="lantern-cap" />
    </svg>
  );
}
