/** Keep the mosque display horizontal even when the device orientation is locked. */
export function landscapeDisplaySize(width: number, height: number) {
  const portrait = height > width;
  return {
    width: portrait ? height : width,
    height: portrait ? width : height,
    rotation: portrait ? 90 : 0,
  };
}

type LockableOrientation = ScreenOrientation & {
  lock?: (orientation: "landscape") => Promise<void>;
};

/** Must run from a click: browsers forbid entering fullscreen on page load. */
export async function enterPrayerFullscreen(element: HTMLElement): Promise<string | null> {
  try {
    if (!document.fullscreenElement) {
      if (!document.fullscreenEnabled || !element.requestFullscreen) {
        return "المتصفح لا يسمح بملء الشاشة هنا؛ يبقى عرض التطبيق أفقيًا داخل النافذة.";
      }
      await element.requestFullscreen();
    }
  } catch {
    return "لم يسمح المتصفح بملء الشاشة؛ يبقى العرض أفقيًا دون تفعيل التدوير التلقائي.";
  }
  const orientation = screen.orientation as LockableOrientation | undefined;
  if (orientation?.lock) {
    // CSS rotation remains active if an iframe/browser/device refuses this API.
    try { await orientation.lock("landscape"); } catch { /* Already covered by the viewport fallback. */ }
  }
  return null;
}
