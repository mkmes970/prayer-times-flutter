import { useEffect, useState } from "react";
import "./prayer-alert-preview.css";
import { previewAlertState } from "./prayer-alert-preview-timing";
import type { BrowserPrayerAlert } from "./browser-prayer-schedule";
import { prayerAnnouncementSeconds } from "./browser-prayer-schedule";
import noPhoneSign from "./no-phone.png?inline";
import { PostPrayerAdhkar } from "./PostPrayerAdhkar";
import { OrnamentalFrame } from "./OrnamentalFrame";

type AlertKind = "adhan" | "iqama";
type PrayerKey = "dhuhr" | "asr" | "maghrib" | "isha" | "fajrSecond";
type AlertPhase = "countdown" | "announcement";

export const prayerAlertLabels: Record<PrayerKey, string> = {
  dhuhr: "الظهر",
  asr: "العصر",
  maghrib: "المغرب",
  isha: "العشاء",
  fajrSecond: "الفجر الثاني",
};

const validPrayers = Object.keys(prayerAlertLabels) as PrayerKey[];
const validAlerts: AlertKind[] = ["adhan", "iqama"];
const announcementDuration: Record<AlertKind, number> = {
  adhan: 15,
  iqama: prayerAnnouncementSeconds,
};

function readPreviewSettings() {
  const params = new URLSearchParams(window.location.search);
  const alert = params.get("alert");
  const prayer = params.get("prayer");
  if (!validAlerts.includes(alert as AlertKind) || !validPrayers.includes(prayer as PrayerKey)) {
    return null;
  }

  const parsedSeconds = Number(params.get("seconds"));
  const seconds = params.has("seconds") && Number.isInteger(parsedSeconds)
    ? Math.max(0, Math.min(30, parsedSeconds))
    : 30;

  return {
    alert: alert as AlertKind,
    prayer: prayer as PrayerKey,
    seconds,
    fridayException: params.get("friday") === "true" &&
      prayer === "dhuhr" && alert === "iqama",
  };
}

const previewSettings = readPreviewSettings();

export function PrayerAlertPreview({ activeAlert, clock }: {
  activeAlert?: BrowserPrayerAlert | null;
  clock?: string;
} = {}) {
  const [state, setState] = useState<{
    phase: AlertPhase;
    remaining: number;
  } | null>(() => {
    if (!previewSettings || previewSettings.fridayException) return null;
    return previewSettings.seconds > 0
      ? { phase: "countdown", remaining: previewSettings.seconds }
      : { phase: "announcement", remaining: 0 };
  });

  useEffect(() => {
    if (!previewSettings || previewSettings.fridayException) return;

    const start = Date.now();
    const countdownDeadline = start + previewSettings.seconds * 1000;
    const announcementDeadline = countdownDeadline +
      announcementDuration[previewSettings.alert] * 1000;
    let phaseTimeout: number | undefined;
    let removeTimeout: number | undefined;

    const update = () => {
      const now = Date.now();
      setState(previewAlertState(
        now, countdownDeadline, announcementDuration[previewSettings.alert] * 1000,
      ));
    };

    update();
    const interval = window.setInterval(update, 100);
    phaseTimeout = window.setTimeout(update, Math.max(0, countdownDeadline - Date.now()));
    removeTimeout = window.setTimeout(() => {
      window.clearInterval(interval);
      setState(null);
    }, Math.max(0, announcementDeadline - Date.now()));
    return () => {
      window.clearInterval(interval);
      window.clearTimeout(phaseTimeout);
      window.clearTimeout(removeTimeout);
    };
  }, []);

  if (new URLSearchParams(window.location.search).get("activity") === "blackout") {
    const friday = new URLSearchParams(window.location.search).get("friday") === "true";
    return <AlertContents title={friday ? "استمع للخطبة بارك الله فيك" : "يرجى إغلاق الهاتف"} remaining={null} kind="blackout" clock={clock} />;
  }
  const params = new URLSearchParams(window.location.search);
  if (params.get("activity") === "khutbah") return <AlertContents title="استمع للخطبة" remaining={null} kind="khutbah" />;
  if (params.get("activity") === "dhikr") {
    const prayer = params.get("prayer") as PrayerKey;
    if (!validPrayers.includes(prayer)) return null;
    const rawElapsed = Number(params.get("elapsed") ?? 0);
    const elapsed = Number.isFinite(rawElapsed) ? Math.max(0, Math.min(479, rawElapsed)) : 0;
    const startsAt = Date.now() - elapsed * 1000;
    const preview: BrowserPrayerAlert = {
      title: "أذكار بعد الصلاة", kind: "dhikr", remaining: 480 - elapsed,
      startsAt, endsAt: startsAt + 480000, prayerId: prayer,
    };
    return <AlertContents title={preview.title} remaining={preview.remaining} kind="dhikr" activity={preview} />;
  }
  if (!previewSettings) return activeAlert
    ? <AlertContents title={activeAlert.title} remaining={activeAlert.remaining} kind={activeAlert.kind} clock={clock} activity={activeAlert} showPhone={activeAlert.showPhone} />
    : null;
  if (previewSettings.fridayException || !state) return null;

  const prayerName = prayerAlertLabels[previewSettings.prayer];
  const title = state.phase === "countdown"
    ? previewSettings.alert === "adhan"
      ? `الوقت المتبقي لأذان ${prayerName}`
      : "الوقت المتبقي لإقامة الصلاة"
    : previewSettings.alert === "adhan"
      ? `حان موعد أذان ${prayerName}`
      : "الصلاة قائمة";

  const showPhone = state.phase === "countdown" && (previewSettings.alert === "iqama" ||
    (params.get("friday") === "true" && previewSettings.prayer === "dhuhr"));
  return <AlertContents title={title} remaining={state.phase === "countdown" ? state.remaining : null} showPhone={showPhone} />;
}

function AlertContents({ title, remaining, kind, clock, activity, showPhone = false }: {
  title: string; remaining: number | null; kind?: BrowserPrayerAlert["kind"]; clock?: string;
  activity?: BrowserPrayerAlert; showPhone?: boolean;
}) {
  if (kind === "blackout") return (
    <section className="prayer-alert-preview prayer-activity-blackout" role="dialog" aria-modal="true" aria-label={title}>
      <OrnamentalFrame className="prayer-alert-preview__ornament" />
      <div className="prayer-blackout-clock" dir="ltr" data-testid="prayer-blackout-clock">{clock}</div>
      <div className="prayer-blackout-reminder">
        <div className="prayer-phone-reminder">{title === "استمع للخطبة بارك الله فيك" ? title : "يرجى إغلاق الهاتف"}</div>
        <img className="prayer-no-phone-sign" src={noPhoneSign} alt="علامة منع استخدام الهاتف" />
      </div>
    </section>
  );
  if (kind === "dhikr" || kind === "khutbah") return (
    <section className={`prayer-alert-preview prayer-activity-period${kind === "dhikr" ? " prayer-activity-period--dhikr" : ""}`} role="dialog" aria-modal="true" aria-label={title}>
      <OrnamentalFrame className="prayer-alert-preview__ornament" />
      <section className="prayer-alert-preview__content">
        <h1 className="prayer-alert-preview__title">{kind === "dhikr" ? "اذكار بعد الصلاة" : title}</h1>
        {kind === "dhikr" ? activity?.prayerId && activity.endsAt
          ? <PostPrayerAdhkar prayerId={activity.prayerId} startsAt={activity.startsAt} endsAt={activity.endsAt} />
          : <p role="alert">تعذر تحديد أذكار هذه الصلاة.</p>
          : null}
        {kind === "dhikr" && <div className="prayer-activity-remaining" dir="rtl">
          {kind === "dhikr" ? "العودة للواجهة بعد" : "باقي الفترة المعروضة"}{" "}
          <span dir="ltr">{Math.floor((remaining ?? 0) / 60)}:{String((remaining ?? 0) % 60).padStart(2, "0")}</span>
        </div>}
      </section>
    </section>
  );
  return (
    <section className={`prayer-alert-preview${showPhone ? " prayer-alert-with-phone" : ""}`} dir="rtl" role="dialog" aria-modal="true" aria-label="تنبيه موعد الصلاة">
      <OrnamentalFrame className="prayer-alert-preview__ornament" />
      <section className="prayer-alert-preview__content">
        <h1
          className="prayer-alert-preview__title"
          aria-live="polite"
          aria-atomic="true"
        >
          {title}
        </h1>
        {remaining !== null && (
          <div
            className="prayer-alert-preview__countdown"
            dir="ltr"
            data-testid="prayer-alert-countdown"
          >
            {remaining}
          </div>
        )}
        {showPhone && <>
          <div className="prayer-phone-reminder">يرجى إغلاق الهاتف</div>
          <img className="prayer-no-phone-sign" src={noPhoneSign} alt="علامة منع استخدام الهاتف" />
        </>}
      </section>
    </section>
  );
}
