export type PreviewAlertState = {
  phase: "countdown" | "announcement";
  remaining: number;
} | null;

export function previewAlertState(
  now: number, countdownDeadline: number, announcementMilliseconds: number,
): PreviewAlertState {
  if (now < countdownDeadline) {
    return { phase: "countdown", remaining: Math.ceil((countdownDeadline - now) / 1000) };
  }
  if (now < countdownDeadline + announcementMilliseconds) {
    return { phase: "announcement", remaining: 0 };
  }
  return null;
}
