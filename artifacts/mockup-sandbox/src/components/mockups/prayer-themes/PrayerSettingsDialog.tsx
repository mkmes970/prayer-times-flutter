import { useEffect, useMemo, useRef, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import {
  adhanPrayers,
  browserRegions,
  emptyBrowserSettings,
  prayerKeys,
  timesForRegion,
} from "./browser-prayer-schedule";
import type { BrowserPrayerSettings, PrayerId } from "./browser-prayer-schedule";
import {
  addBrowserRegion,
  browserDateKey,
  deleteBrowserRegion,
  exportBrowserBackup,
  hashBrowserPin,
  hijriMonthNames,
  importBrowserBackup,
  prayerLabels,
  renameBrowserRegion,
  restoreBrowserDefaults,
  setBrowserPrayerDay,
  verifyBrowserPin,
} from "./browser-prayer-preferences";
import "./prayer-settings-dialog.css";

interface PrayerSettingsDialogProps {
  initialSettings: BrowserPrayerSettings;
  onSave: (value: BrowserPrayerSettings) => string | null;
  onClose: () => void;
  storageNotice?: string;
}

type NumericFields = Record<string, string>;
const accentChoices = ["#17432e", "#31546c", "#6a4724"];
const dateKeyToday = () => browserDateKey();
const dateForKey = (key: string) => new Date(`${key}T12:00:00+03:00`);
const asTime = (minutes: number) =>
  `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
const isDateKey = (value: string) =>
  /^\d{4}-\d{2}-\d{2}$/.test(value) && new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value;
function normalized(settings: BrowserPrayerSettings): BrowserPrayerSettings {
  return {
    ...structuredClone(emptyBrowserSettings),
    ...settings,
    iqamaMinutes: { ...emptyBrowserSettings.iqamaMinutes, ...settings.iqamaMinutes },
    prayerDurationMinutes: { ...emptyBrowserSettings.prayerDurationMinutes, ...settings.prayerDurationMinutes },
    regions: settings.regions ?? [],
    removedRegionIds: settings.removedRegionIds ?? [],
  };
}

function minuteInputs(settings: BrowserPrayerSettings): NumericFields {
  const all: NumericFields = {};
  for (const { id } of adhanPrayers) {
    all[`iqama:${id}`] = settings.iqamaMinutes[id]?.toString() ?? "";
    all[`duration:${id}`] = settings.prayerDurationMinutes?.[id]?.toString() ?? "";
  }
  all.dhikr = settings.postPrayerDhikrMinutes?.toString() ?? "";
  all.khutbah = settings.fridayKhutbahMinutes?.toString() ?? "";
  return all;
}

function Section({ title, detail, children, id }: { title: string; detail?: string; children: ReactNode; id: string }) {
  return (
    <section className="ps-section" aria-labelledby={`${id}-heading`} data-testid={`section-${id}`}>
      <div className="ps-section-heading">
        <span className="ps-section-mark" aria-hidden="true" />
        <div>
          <h3 id={`${id}-heading`}>{title}</h3>
          {detail && <p>{detail}</p>}
        </div>
      </div>
      {children}
    </section>
  );
}

function SwitchField({ label, checked, onChange, testId, detail }: {
  label: string; checked: boolean; onChange: (value: boolean) => void; testId: string; detail?: string;
}) {
  return (
    <label className="ps-switch-row">
      <span className="ps-switch-copy">
        <strong>{label}</strong>
        {detail && <small>{detail}</small>}
      </span>
      <input
        type="checkbox"
        role="switch"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
        data-testid={testId}
      />
    </label>
  );
}

export function PrayerSettingsDialog({ initialSettings, onSave, onClose, storageNotice }: PrayerSettingsDialogProps) {
  const [draft, setDraft] = useState(() => normalized(initialSettings));
  const [minutes, setMinutes] = useState(() => minuteInputs(normalized(initialSettings)));
  const [date, setDate] = useState(dateKeyToday);
  const [timesDirty, setTimesDirty] = useState(false);
  const [times, setTimes] = useState<Record<PrayerId, string>>(() => {
    const now = dateForKey(dateKeyToday());
    const values = timesForRegion(initialSettings.regionId, now, initialSettings);
    return Object.fromEntries(prayerKeys.map((key) => [key, values ? asTime(values[key]) : ""])) as Record<PrayerId, string>;
  });
  const [error, setError] = useState<string | null>(null);
  const [regionName, setRegionName] = useState("");
  const [importText, setImportText] = useState("");
  const [pinInput, setPinInput] = useState("");
  const [pinConfirm, setPinConfirm] = useState("");
  const [unlocked, setUnlocked] = useState(!initialSettings.pin);
  const [pinBusy, setPinBusy] = useState(false);
  const [dialogMode, setDialogMode] = useState<"none" | "set-pin" | "change-region">("none");
  const [renameValue, setRenameValue] = useState("");
  const [showImportText, setShowImportText] = useState(false);
  const dialogRef = useRef<HTMLDivElement>(null);
  const initialFocusRef = useRef<HTMLInputElement | HTMLSelectElement | null>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;
  const regions = useMemo(() => browserRegions(draft), [draft]);
  const selectedRegion = regions.find((region) => region.id === draft.regionId) ?? null;
  const selectedIsBuiltin = selectedRegion ? !draft.regions?.some((region) => region.id === selectedRegion.id) : false;

  useEffect(() => {
    previousFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const oldOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    initialFocusRef.current?.focus();
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        onCloseRef.current();
        return;
      }
      if (event.key !== "Tab" || !dialogRef.current) return;
      const items = Array.from(dialogRef.current.querySelectorAll<HTMLElement>(
        'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
      )).filter((element) => element.getAttribute("aria-hidden") !== "true" && element.offsetParent !== null);
      if (!items.length) {
        event.preventDefault();
        dialogRef.current.focus();
      } else if (event.shiftKey && (document.activeElement === items[0] || !dialogRef.current.contains(document.activeElement))) {
        event.preventDefault();
        items[items.length - 1].focus();
      } else if (!event.shiftKey && (document.activeElement === items[items.length - 1] || !dialogRef.current.contains(document.activeElement))) {
        event.preventDefault();
        items[0].focus();
      }
    };
    document.addEventListener("keydown", handleKey);
    return () => {
      document.removeEventListener("keydown", handleKey);
      document.body.style.overflow = oldOverflow;
      previousFocusRef.current?.focus();
    };
  }, []);

  useEffect(() => {
    const values = timesForRegion(draft.regionId, dateForKey(date), draft);
    setTimes(Object.fromEntries(prayerKeys.map((key) => [key, values ? asTime(values[key]) : ""])) as Record<PrayerId, string>);
    setTimesDirty(false);
  }, [date, draft.regionId]);

  const patch = (updates: Partial<BrowserPrayerSettings>) => setDraft((current) => ({ ...current, ...updates }));
  const updateMinute = (key: string, value: string) => {
    setMinutes((current) => ({ ...current, [key]: value }));
    setError(null);
  };
  const save = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError(null);
    if (regions.length > 0 && (!draft.regionId || !regions.some((region) => region.id === draft.regionId))) {
      setError("يرجى اختيار منطقة صالحة قبل الحفظ.");
      initialFocusRef.current?.focus();
      return;
    }
    const iqamaMinutes: Partial<Record<(typeof adhanPrayers)[number]["id"], number>> = {};
    const prayerDurationMinutes: Partial<Record<(typeof adhanPrayers)[number]["id"], number>> = {};
    for (const prayer of adhanPrayers) {
      const rawIqama = minutes[`iqama:${prayer.id}`].trim();
      const rawDuration = minutes[`duration:${prayer.id}`].trim();
      if (rawIqama && (!/^\d+$/.test(rawIqama) || Number(rawIqama) < 1 || Number(rawIqama) > 60)) {
        setError(`مدة انتظار إقامة ${prayer.label} يجب أن تكون عدداً صحيحاً من 1 إلى 60 دقيقة، أو تُترك فارغة.`);
        document.getElementById(`prayer-settings-iqama-${prayer.id}`)?.focus();
        return;
      }
      if (rawDuration && (!/^\d+$/.test(rawDuration) || Number(rawDuration) > 360)) {
        setError(`مدة صلاة ${prayer.label} يجب أن تكون عدداً صحيحاً من 0 إلى 360 دقيقة، أو تُترك فارغة.`);
        document.getElementById(`prayer-settings-duration-${prayer.id}`)?.focus();
        return;
      }
      if (rawIqama) iqamaMinutes[prayer.id] = Number(rawIqama);
      if (rawDuration) prayerDurationMinutes[prayer.id] = Number(rawDuration);
    }
    const parseLongMinute = (key: string, label: string) => {
      const raw = minutes[key].trim();
      if (!raw) return null;
      if (!/^\d+$/.test(raw) || Number(raw) > 360) throw new Error(`${label}: أدخل عدداً صحيحاً من 0 إلى 360 دقيقة أو اتركه فارغاً.`);
      return Number(raw);
    };
    let complete: BrowserPrayerSettings;
    try {
      complete = {
        ...draft,
        preferencesVersion: 2,
        iqamaMinutes,
        prayerDurationMinutes,
        postPrayerDhikrMinutes: parseLongMinute("dhikr", "مدة الأذكار"),
        fridayKhutbahMinutes: parseLongMinute("khutbah", "مدة خطبة الجمعة"),
      };
      if (timesDirty && draft.regionId) complete = setBrowserPrayerDay(complete, draft.regionId, date, times);
    } catch (reason) {
      setError((reason as Error).message);
      return;
    }
    const saveError = onSave(complete);
    if (saveError !== null) setError(saveError);
  };

  const addRegion = () => {
    try {
      const next = addBrowserRegion(draft, regionName);
      setDraft(next);
      setRegionName("");
      setError(null);
    } catch (reason) { setError((reason as Error).message); }
  };
  const renameRegion = () => {
    if (!selectedRegion) return;
    try {
      setDraft(renameBrowserRegion(draft, selectedRegion.id, renameValue));
      setDialogMode("none");
      setError(null);
    } catch (reason) { setError((reason as Error).message); }
  };
  const deleteRegion = () => {
    if (!selectedRegion || !window.confirm(`سيتم حذف «${selectedRegion.name}» وكل المواقيت المحفوظة فيها من المسودة. متابعة؟`)) return;
    const nextRegions = regions.filter((region) => region.id !== selectedRegion.id);
    setDraft(deleteBrowserRegion(draft, selectedRegion.id));
    if (!nextRegions.length) setError("أضيفي منطقة أو اختاري منطقة متاحة قبل الحفظ.");
  };
  const handleImport = (text: string) => {
    if (!text.trim()) {
      setError("ألصق محتوى JSON أو اختر ملفاً أولاً.");
      return;
    }
    if (!window.confirm("سيستبدل هذا الاستيراد إعدادات المسودة الحالية أو يضيف جدول المنطقة. لن يُعتمد شيء حتى تضغط حفظ الإعدادات. متابعة؟")) return;
    try {
      const imported = importBrowserBackup(text, draft);
      setDraft(imported);
      setMinutes(minuteInputs(imported));
      setImportText("");
      setShowImportText(false);
      setError(null);
    } catch (reason) { setError((reason as Error).message); }
  };
  const changeTime = (id: PrayerId, value: string) => {
    const next = { ...times, [id]: value };
    setTimes(next);
    setTimesDirty(true);
    if (prayerKeys.every((key) => /^\d{2}:\d{2}$/.test(next[key]))) {
      try {
        setDraft((current) => setBrowserPrayerDay(current, current.regionId!, date, next));
        setError(null);
      } catch { /* Keep incomplete/out-of-order editor values local until corrected. */ }
    }
  };
  const updatePin = async () => {
    if (!/^\d{4,8}$/.test(pinInput)) {
      setError("رمز PIN من 4 إلى 8 أرقام.");
      return;
    }
    if (pinInput !== pinConfirm) {
      setError("رمزا PIN غير متطابقين.");
      return;
    }
    setPinBusy(true);
    try {
      patch({ pin: await hashBrowserPin(pinInput) });
      setPinInput("");
      setPinConfirm("");
      setDialogMode("none");
      setError(null);
    } catch (reason) { setError((reason as Error).message); }
    finally { setPinBusy(false); }
  };
  const unlock = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPinBusy(true);
    try {
      const ok = draft.pin ? await verifyBrowserPin(pinInput, draft.pin) : true;
      if (ok) {
        setUnlocked(true);
        setPinInput("");
        setError(null);
      } else setError("رمز PIN غير صحيح. حاول مرة أخرى.");
    } catch {
      setError("تعذر التحقق من رمز PIN في هذا المتصفح.");
    } finally {
      setPinBusy(false);
    }
  };

  return (
    <div className="prayer-settings-backdrop" data-testid="dialog-prayer-settings-backdrop"
      onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <div className="prayer-settings-dialog" ref={dialogRef} role="dialog" aria-modal="true"
        aria-labelledby="prayer-settings-title" aria-describedby="prayer-settings-description" tabIndex={-1} dir="rtl">
        {!unlocked ? (
          <div className="ps-pin-gate">
            <header className="prayer-settings-header">
              <div><p className="prayer-settings-eyebrow">مواقيت الصلاة</p><h2 id="prayer-settings-title">الضبط</h2></div>
              <button className="prayer-settings-close" type="button" onClick={onClose} aria-label="الخروج من شاشة PIN" data-testid="button-close-prayer-settings">×</button>
            </header>
            <p id="prayer-settings-description" className="prayer-settings-intro">أدخل رمز الحماية المحلي لفتح الضبط.</p>
            <form onSubmit={unlock}>
              <label className="ps-field">رمز PIN
                <input ref={(element) => { initialFocusRef.current = element; }} type="password" inputMode="numeric" autoComplete="current-password"
                  maxLength={8} value={pinInput} onChange={(event) => setPinInput(event.target.value.replace(/\D/g, ""))}
                  data-testid="input-pin-unlock" />
              </label>
              {error && <p className="prayer-settings-error" role="alert" data-testid="error-prayer-settings">{error}</p>}
              <div className="prayer-settings-actions">
                <button type="button" className="prayer-settings-cancel" onClick={onClose} data-testid="button-cancel-prayer-settings">خروج</button>
                <button type="submit" className="prayer-settings-save" disabled={pinBusy} data-testid="button-unlock-settings">{pinBusy ? "جارٍ التحقق…" : "فتح الضبط"}</button>
              </div>
            </form>
            <p className="prayer-settings-browser-note">حماية محلية على هذا المتصفح؛ ليست تسجيل دخول لحساب.</p>
          </div>
        ) : (
          <>
            <header className="prayer-settings-header">
              <div>
                <p className="prayer-settings-eyebrow">مواقيت الصلاة</p>
                <h2 id="prayer-settings-title">الضبط</h2>
              </div>
              <button className="prayer-settings-close" type="button" onClick={onClose} aria-label="إغلاق الإعدادات" data-testid="button-close-prayer-settings">
                <svg viewBox="0 0 20 20" aria-hidden="true"><path d="m5 5 10 10M15 5 5 15" /></svg>
              </button>
            </header>
            <p id="prayer-settings-description" className="prayer-settings-intro">إعدادات مواقيت الصلاة والعرض المحفوظة في هذا المتصفح.</p>
            <div className="ps-top-actions">
              <button type="button" className="prayer-settings-cancel" onClick={onClose} data-testid="button-cancel-prayer-settings-top">إلغاء</button>
              <button type="submit" form="prayer-settings-form" className="prayer-settings-save" data-testid="button-save-prayer-settings-top">حفظ الإعدادات</button>
            </div>
            <form id="prayer-settings-form" onSubmit={save} noValidate>
              <div className="ps-form-content">
                <Section id="hadith" title="عرض الأحاديث">
                  <SwitchField label="تفعيل الأحاديث" detail="عند إيقافه تبقى الشاشة الرئيسية ظاهرة. الشريط السفلي يعمل في الحالتين." checked={draft.hadithEnabled ?? false} onChange={(value) => patch({ hadithEnabled: value })} testId="switch-hadith-enabled" />
                </Section>
                <Section id="ticker" title="الشريط السفلي">
                  <SwitchField
                    label="تفعيل تمرير الشريط السفلي"
                    detail="عند الإيقاف، يظهر حديث أو دعاء أو ذكر ثابتًا ويتغير كل 10 ثوانٍ."
                    checked={draft.tickerScrollingEnabled ?? false}
                    onChange={(value) => patch({ tickerScrollingEnabled: value })}
                    testId="switch-ticker-scrolling"
                  />
                  {draft.tickerScrollingEnabled && (
                    <label className="ps-field">سرعة تمرير الشريط السفلي
                      <span className="ps-range-line">
                        <input type="range" min={8} max={80} step={2}
                          value={draft.tickerSpeed ?? 32}
                          onChange={(event) => patch({ tickerSpeed: Number(event.target.value) })}
                          data-testid="input-ticker-speed"
                        />
                        <output>{(draft.tickerSpeed ?? 32) <= 28
                          ? "بطيئة" : (draft.tickerSpeed ?? 32) >= 60 ? "سريعة" : "متوسطة"}</output>
                      </span>
                      <span className="ps-range-hint"><span>بطيئة</span><span>سريعة</span></span>
                    </label>
                  )}
                </Section>
                <Section id="identity" title="اسم المسجد والعرض" detail="اسم التطبيق ثابت، ويمكن تخصيص الاسم الظاهر للمسجد.">
                  <div className="ps-fixed-title"><span>اسم التطبيق</span><strong>مواقيت الصلاة</strong><small>اسم ثابت</small></div>
                  <label className="ps-field">اسم المسجد
                    <input value={draft.mosqueName ?? ""} maxLength={100} onChange={(event) => patch({ mosqueName: event.target.value })}
                      data-testid="input-mosque-name" />
                  </label>
                </Section>

                <Section id="regions" title="مواقيت الصلاة حسب المنطقة" detail="اختر منطقة أو أنشئ منطقة مخصصة ثم حرّر مواقيتها بالتاريخ.">
                  <label className="ps-field">المنطقة الحالية
                    <select ref={(element) => { initialFocusRef.current = element; }} value={draft.regionId ?? ""}
                      onChange={(event) => patch({ regionId: event.target.value || null })} data-testid="select-prayer-region">
                      <option value="">اختر المنطقة</option>
                      {regions.map((region) => <option key={region.id} value={region.id}>{region.name}</option>)}
                    </select>
                  </label>
                  <div className="ps-region-actions">
                    <button type="button" className="ps-button ps-secondary" disabled={!selectedRegion} onClick={() => { setRenameValue(selectedRegion?.name ?? ""); setDialogMode("change-region"); }} data-testid="button-rename-region">تغيير الاسم</button>
                    <button type="button" className="ps-button ps-danger" disabled={!selectedRegion} onClick={deleteRegion} data-testid="button-delete-region">حذف المنطقة</button>
                  </div>
                  <div className="ps-inline-add">
                    <label className="ps-field">اسم منطقة جديدة
                      <input value={regionName} onChange={(event) => setRegionName(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); addRegion(); } }} data-testid="input-new-region-name" />
                    </label>
                    <button type="button" className="ps-button ps-primary" onClick={addRegion} data-testid="button-add-region">إضافة منطقة</button>
                  </div>
                  {selectedIsBuiltin && <p className="ps-hint">يمكن تغيير اسم المنطقة المضمّنة في هذه المسودة؛ حذفها يخفيها من قائمة المناطق.</p>}
                </Section>

                <Section id="times" title="تعديل مواقيت يوم محدد" detail="الأوقات بنظام 24 ساعة، وتُحفظ لكل تاريخ ميلادي في جدول المنطقة.">
                  <label className="ps-field">التاريخ الميلادي
                    <input type="date" value={date} onChange={(event) => { if (isDateKey(event.target.value)) setDate(event.target.value); }} data-testid="input-prayer-date" />
                  </label>
                  {!selectedRegion ? <p className="ps-callout">اختر منطقة أولاً لتعديل مواقيتها.</p> : (
                    <>
                      <div className="ps-time-grid">
                        {prayerKeys.map((id) => (
                          <label className="ps-time-field" key={id}>
                            <span>{prayerLabels[id]}</span>
                            <input aria-label={`وقت ${prayerLabels[id]} بنظام 24 ساعة`} type="time" step={60} value={times[id]}
                              onChange={(event) => changeTime(id, event.target.value)} data-testid={`input-prayer-time-${id}`} />
                          </label>
                        ))}
                      </div>
                      <p className="ps-hint">التعديل محفوظ في المسودة فور اكتمال الأوقات السبعة وبترتيبها الصحيح؛ لن يعتمد حتى الضغط على حفظ.</p>
                    </>
                  )}
                </Section>

                <Section id="backup" title="استيراد وتصدير البيانات" detail="يدعم استيراد جدول منطقة أو نسخة JSON من المتصفح أو التطبيق الأصلي.">
                  <div className="ps-backup-actions">
                    <label className="ps-button ps-secondary ps-file-button">اختيار ملف JSON
                      <input type="file" accept=".json,application/json,text/plain" onChange={(event) => {
                        const file = event.target.files?.[0];
                        if (file) void file.text().then(handleImport).catch(() => setError("تعذر قراءة الملف."));
                        event.target.value = "";
                      }} data-testid="input-import-json" />
                    </label>
                    <button type="button" className="ps-button ps-primary" onClick={() => exportBrowserBackup(initialSettings)} data-testid="button-export-backup">تصدير نسخة كاملة محفوظة</button>
                  </div>
                  <button type="button" className="ps-text-button" onClick={() => setShowImportText((shown) => !shown)} aria-expanded={showImportText} data-testid="button-toggle-json-paste">
                    {showImportText ? "إخفاء لصق JSON" : "لصق محتوى JSON بدلاً من الملف"}
                  </button>
                  {showImportText && <div className="ps-paste-box">
                    <label className="ps-field">محتوى JSON
                      <textarea rows={6} value={importText} onChange={(event) => setImportText(event.target.value)} data-testid="textarea-import-json" />
                    </label>
                    <button type="button" className="ps-button ps-secondary" onClick={() => handleImport(importText)} data-testid="button-import-json">استيراد بعد التأكيد</button>
                  </div>}
                  <p className="ps-hint">ملف النسخة يتضمن الإعدادات والمناطق والمواقيت. PIN يُصدّر كقيمة مشفّرة فقط ولا تُصدّر أرقام PIN الخام.</p>
                </Section>

                <Section id="iqama" title="مدة الانتظار قبل الإقامة" detail="بالدقائق، من 1 إلى 60؛ اترك الحقل فارغاً لتعطيل فترة الانتظار.">
                  <div className="ps-minute-grid">
                    {adhanPrayers.map((prayer) => <label className="ps-minute-field" key={prayer.id} htmlFor={`prayer-settings-iqama-${prayer.id}`}>
                      <span>{prayer.label}</span><span className="ps-number-unit">
                        <input id={`prayer-settings-iqama-${prayer.id}`} type="number" min={1} max={60} step={1} inputMode="numeric" placeholder="—"
                          value={minutes[`iqama:${prayer.id}`]} onChange={(event) => updateMinute(`iqama:${prayer.id}`, event.target.value)}
                          data-testid={`input-iqama-${prayer.id}`} />
                        <small>دقيقة</small>
                      </span>
                    </label>)}
                  </div>
                  <p className="ps-callout">يوم الجمعة لا توجد إقامة للظهر. تبدأ دقيقة «استمع للخطبة» ثم شاشة سوداء لبقية مدة الخطبة، وبعدها الأذكار مباشرة.</p>
                </Section>

                <Section id="prayer-length" title="مدة الصلاة" detail="بالدقائق، من 0 إلى 360؛ الفراغ يعطّل مدة الصلاة لهذه الفترة.">
                  <div className="ps-minute-grid">
                    {adhanPrayers.map((prayer) => <label className="ps-minute-field" key={prayer.id} htmlFor={`prayer-settings-duration-${prayer.id}`}>
                      <span>{prayer.label}</span><span className="ps-number-unit">
                        <input id={`prayer-settings-duration-${prayer.id}`} type="number" min={0} max={360} step={1} inputMode="numeric" placeholder="—"
                          value={minutes[`duration:${prayer.id}`]} onChange={(event) => updateMinute(`duration:${prayer.id}`, event.target.value)}
                          data-testid={`input-prayer-duration-${prayer.id}`} />
                        <small>دقيقة</small>
                      </span>
                    </label>)}
                  </div>
                  <p className="ps-hint">مدة صلاة الظهر هنا لباقي أيام الأسبوع؛ يوم الجمعة تُستخدم مدة الخطبة ثم الأذكار مباشرة.</p>
                </Section>

                <Section id="after-prayer" title="الأذكار وخطبة الجمعة" detail="المدد الفارغة تعطل الفقرة المقابلة.">
                  <div className="ps-duration-pair">
                    <label className="ps-field">مدة الأذكار بعد الصلاة
                      <span className="ps-number-unit"><input type="number" min={0} max={360} step={1} inputMode="numeric" placeholder="—" value={minutes.dhikr}
                        onChange={(event) => updateMinute("dhikr", event.target.value)} data-testid="input-dhikr-duration" /><small>دقيقة</small></span>
                    </label>
                    <label className="ps-field">مدة خطبة الجمعة
                      <span className="ps-number-unit"><input type="number" min={0} max={360} step={1} inputMode="numeric" placeholder="—" value={minutes.khutbah}
                        onChange={(event) => updateMinute("khutbah", event.target.value)} data-testid="input-khutbah-duration" /><small>دقيقة</small></span>
                    </label>
                  </div>
                  <p className="ps-callout">مثال الجمعة: مدة الخطبة 20 دقيقة تشمل دقيقة «استمع للخطبة» و19 دقيقة للشاشة السوداء، ثم الأذكار حسب مدتها المضبوطة.</p>
                </Section>

                <Section id="hijri" title="التاريخ الهجري" detail="يمكن إخفاء التاريخ، تصحيح اليوم يدوياً، أو تطبيق إزاحة من −3 إلى +3 أيام.">
                  <SwitchField label="إظهار التاريخ الهجري" checked={draft.showHijriDate ?? true} onChange={(value) => patch({ showHijriDate: value })} testId="switch-show-hijri" />
                  <div className="ps-hijri-controls">
                    <label className="ps-field">اليوم
                      <select value={draft.hijriManualDate?.day ?? ""} onChange={(event) => {
                        const day = Number(event.target.value);
                        patch({ hijriManualDate: day ? { day, month: draft.hijriManualDate?.month ?? 1, anchor: draft.hijriManualDate?.anchor ?? browserDateKey() } : null });
                      }} data-testid="select-hijri-day">
                        <option value="">تلقائي</option>{Array.from({ length: 30 }, (_, i) => <option key={i + 1} value={i + 1}>{i + 1}</option>)}
                      </select>
                    </label>
                    <label className="ps-field">الشهر الهجري
                      <select value={draft.hijriManualDate?.month ?? ""} onChange={(event) => {
                        const month = Number(event.target.value);
                        patch({ hijriManualDate: month ? { day: draft.hijriManualDate?.day ?? 1, month, anchor: draft.hijriManualDate?.anchor ?? browserDateKey() } : null });
                      }} data-testid="select-hijri-month">
                        <option value="">تلقائي</option>{hijriMonthNames.map((name, i) => <option key={name} value={i + 1}>{name}</option>)}
                      </select>
                    </label>
                  </div>
                  <p className="ps-hint">تاريخ الارتكاز: {draft.hijriManualDate?.anchor ?? browserDateKey()}.</p>
                  <button type="button" className="ps-button ps-secondary" onClick={() => patch({ hijriManualDate: null })} data-testid="button-reset-hijri">إعادة التاريخ إلى الحساب التلقائي</button>
                  <label className="ps-field ps-offset-field">إزاحة التاريخ
                    <span className="ps-range-line"><input type="range" min={-3} max={3} step={1} value={draft.hijriOffsetDays ?? 0}
                      onChange={(event) => patch({ hijriOffsetDays: Number(event.target.value) })} data-testid="input-hijri-offset" /><output>{draft.hijriOffsetDays ?? 0} يوم</output></span>
                  </label>
                </Section>

                <Section id="appearance" title="المظهر والخط" detail="تُطبّق القيم على واجهة العرض في المتصفح.">
                  <SwitchField label="استخدام خط النظام" checked={draft.systemFont ?? false} onChange={(value) => patch({ systemFont: value })} testId="switch-system-font" />
                  <label className="ps-field">حجم الخط <span className="ps-range-line"><input type="range" min={0.8} max={1.4} step={0.1} value={draft.fontScale ?? 1}
                    onChange={(event) => patch({ fontScale: Number(event.target.value) })} data-testid="input-font-scale" /><output>{(draft.fontScale ?? 1).toFixed(1)}×</output></span></label>
                  <label className="ps-field">حجم الساعة <span className="ps-range-line"><input type="range" min={0.8} max={1.3} step={0.1} value={draft.clockScale ?? 1}
                    onChange={(event) => patch({ clockScale: Number(event.target.value) })} data-testid="input-clock-scale" /><output>{(draft.clockScale ?? 1).toFixed(1)}×</output></span></label>
                  <fieldset className="ps-colors"><legend>لون الواجهة</legend>
                    {accentChoices.map((color) => <label key={color} className="ps-color-choice">
                      <input type="radio" name="accent-color" value={color} checked={(draft.accentColor ?? "#17432e") === color}
                        onChange={() => patch({ accentColor: color })} data-testid={`radio-accent-${color.slice(1)}`} />
                      <span style={{ backgroundColor: color }} aria-hidden="true" /><small>{color}</small>
                    </label>)}
                  </fieldset>
                </Section>

                <Section id="device" title="خيارات الجهاز والمتصفح" detail="قد يتطلب إبقاء الشاشة أو ملء الشاشة موافقة المستخدم وبقاء التبويب ظاهراً.">
                  <SwitchField label="إبقاء الشاشة مستيقظة" detail="يدعم المتصفح ذلك بعد منح الإذن؛ قد يتوقف عند إخفاء التبويب." checked={draft.keepAwake ?? true} onChange={(value) => patch({ keepAwake: value })} testId="switch-keep-awake" />
                  <SwitchField label="وضع ملء الشاشة" detail="قد يحتاج المتصفح إلى تفاعل مباشر من المستخدم." checked={draft.immersiveMode ?? false} onChange={(value) => patch({ immersiveMode: value })} testId="switch-immersive-mode" />
                  <label className="ps-switch-row ps-disabled-row">
                    <span className="ps-switch-copy"><strong>التشغيل عند بدء الجهاز</strong><small>متاح في تطبيق Android فقط؛ لا يستطيع المتصفح بدء التشغيل عند إقلاع الجهاز.</small></span>
                    <input type="checkbox" disabled aria-label="غير متاح في المتصفح" data-testid="switch-auto-start-disabled" />
                  </label>
                </Section>

                <Section id="security" title="حماية الضبط برمز PIN" detail="حماية محلية على هذا المتصفح، وليست تسجيل دخول لحساب.">
                  <p className="ps-hint">{draft.pin ? "الحماية مفعّلة لهذا المتصفح." : "لا يوجد رمز PIN محلي حالياً."} النسخ الاحتياطية لا تزامن الإعدادات مع APK.</p>
                  <div className="ps-region-actions">
                    <button type="button" className="ps-button ps-secondary" onClick={() => { setDialogMode("set-pin"); setPinInput(""); setPinConfirm(""); }} data-testid="button-manage-pin">{draft.pin ? "تغيير PIN" : "تعيين PIN"}</button>
                    {draft.pin && <button type="button" className="ps-button ps-danger" onClick={() => {
                      if (window.confirm("إزالة حماية PIN من المسودة؟ لن تُعتمد الإزالة حتى تحفظ الإعدادات.")) patch({ pin: null });
                    }} data-testid="button-remove-pin">إزالة PIN</button>}
                  </div>
                </Section>

                <Section id="reset" title="إعادة الضبط" detail="يعيد التوقيتات والأسماء والمظهر وPIN إلى القيم الافتراضية، مع إبقاء المناطق ومواقيتها.">
                  <button type="button" className="ps-button ps-danger ps-reset-button" onClick={() => {
                    if (!window.confirm("ستُعاد إعدادات التوقيتات والأسماء والمظهر وPIN. ستبقى المناطق والجداول كما هي. لن يُعتمد التغيير حتى الضغط على حفظ الإعدادات. متابعة؟")) return;
                    const reset = restoreBrowserDefaults(draft);
                    setDraft(reset);
                    setMinutes(minuteInputs(reset));
                    setError(null);
                  }} data-testid="button-restore-defaults">إعادة الإعدادات الافتراضية</button>
                </Section>
                {storageNotice && <p className="prayer-settings-storage" role="status" data-testid="status-prayer-settings-storage">{storageNotice}</p>}
                {error && <p className="prayer-settings-error" role="alert" data-testid="error-prayer-settings">{error}</p>}
              </div>
              <footer className="prayer-settings-actions ps-sticky-actions">
                <button type="button" className="prayer-settings-cancel" onClick={onClose} data-testid="button-cancel-prayer-settings">إلغاء</button>
                <button type="submit" className="prayer-settings-save" data-testid="button-save-prayer-settings">حفظ الإعدادات</button>
              </footer>
              <p className="prayer-settings-browser-note">تُحفظ الإعدادات على هذا المتصفح فقط، ولا تغيّر إعدادات تطبيق APK أو تزامنها معه.</p>
            </form>
            {dialogMode === "change-region" && <div className="ps-modal-scrim" role="presentation">
              <div className="ps-small-modal" role="dialog" aria-modal="true" aria-labelledby="ps-rename-title">
                <h3 id="ps-rename-title">تغيير اسم المنطقة</h3>
                <label className="ps-field">اسم المنطقة<input autoFocus value={renameValue} onChange={(event) => setRenameValue(event.target.value)} data-testid="input-rename-region" /></label>
                <div className="ps-region-actions">
                  <button type="button" className="ps-button ps-secondary" onClick={() => setDialogMode("none")} data-testid="button-cancel-rename">إلغاء</button>
                  <button type="button" className="ps-button ps-primary" onClick={renameRegion} data-testid="button-confirm-rename">حفظ الاسم</button>
                </div>
              </div>
            </div>}
            {dialogMode === "set-pin" && <div className="ps-modal-scrim" role="presentation">
              <div className="ps-small-modal" role="dialog" aria-modal="true" aria-labelledby="ps-pin-title">
                <h3 id="ps-pin-title">{draft.pin ? "تغيير رمز PIN" : "حماية الضبط"}</h3>
                <label className="ps-field">رمز جديد من 4 إلى 8 أرقام<input type="password" inputMode="numeric" autoFocus maxLength={8} value={pinInput}
                  onChange={(event) => setPinInput(event.target.value.replace(/\D/g, ""))} data-testid="input-pin-new" /></label>
                <label className="ps-field">تأكيد الرمز<input type="password" inputMode="numeric" maxLength={8} value={pinConfirm}
                  onChange={(event) => setPinConfirm(event.target.value.replace(/\D/g, ""))} data-testid="input-pin-confirm" /></label>
                <div className="ps-region-actions">
                  <button type="button" className="ps-button ps-secondary" onClick={() => setDialogMode("none")} data-testid="button-cancel-pin">إلغاء</button>
                  <button type="button" className="ps-button ps-primary" disabled={pinBusy} onClick={() => void updatePin()} data-testid="button-save-pin">{pinBusy ? "جارٍ الحفظ…" : "حفظ PIN"}</button>
                </div>
              </div>
            </div>}
          </>
        )}
      </div>
    </div>
  );
}
