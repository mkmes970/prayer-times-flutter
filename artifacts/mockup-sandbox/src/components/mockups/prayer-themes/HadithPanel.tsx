import { useLayoutEffect, useRef } from "react";
import type { HadithEntry } from "./hadith-rotation";
import { recitationParts } from "./recitation-colors";
import { OrnamentalFrame } from "./OrnamentalFrame";
import { englishDigits } from "./english-digits";

export function HadithPanel({ entry, evening = false }: { entry: HadithEntry; evening?: boolean }) {
  const contentRef = useRef<HTMLDivElement>(null);
  const coloredBody = recitationParts(entry.text, evening).map((part, index) =>
    <span key={index} style={{ color: part.recitation ? "#d00000" : "#000" }}>{englishDigits(part.text)}</span>);
  const long = entry.text.includes("\n") || entry.text.length + (entry.source?.length ?? 0) > 180;

  useLayoutEffect(() => {
    const content = contentRef.current;
    if (!content) return;
    const fit = () => {
      const text = content.querySelector<HTMLElement>(".hadith-long-text")!;
      const footer = content.querySelector<HTMLElement>(".hadith-long-source");
      if (content.clientWidth === 0 || content.clientHeight === 0) return;
      let low = 1;
      let high = long ? 36 : 48;
      for (let i = 0; i < 12; i++) {
        const size = (low + high) / 2;
        text.style.fontSize = `${size}px`;
        // Measure natural (unshrunk) content, including narrator and source.
        // Leave room for Arabic ascenders/descenders and rounding on Android.
        const height = text.getBoundingClientRect().height +
          (footer?.getBoundingClientRect().height ?? 0) + (footer ? 4 : 0);
        if (height <= content.clientHeight - 8 &&
            text.scrollWidth <= content.clientWidth &&
            (!footer || footer.scrollWidth <= content.clientWidth)) low = size;
        else high = size;
      }
      text.style.fontSize = `${low}px`;
    };
    fit();
    const observer = new ResizeObserver(fit);
    observer.observe(content);
    const fontsChanged = () => fit();
    document.fonts.addEventListener("loadingdone", fontsChanged);
    let disposed = false;
    void document.fonts.ready.then(() => { if (!disposed) fit(); });
    return () => {
      disposed = true;
      observer.disconnect();
      document.fonts.removeEventListener("loadingdone", fontsChanged);
    };
  }, [entry.number, entry.source, entry.text, entry.narrator, entry.introduction, long]);

  return (
    <div className={`hadith-panel hadith-panel-long ${long ? "" : "hadith-panel-short"}`} dir="rtl" aria-label="حديث نبوي">
        <OrnamentalFrame className="hadith-ornamental-frame" />
        <div className="hadith-long-content" ref={contentRef}>
          <div className="hadith-long-text">
            {[entry.narrator, entry.introduction].filter(Boolean).map((text, index) =>
              <span key={`prefix-${index}`} style={{ color: "#000" }}>{englishDigits(text!)}{"\n\n"}</span>)}
            {coloredBody}
          </div>
          {entry.source && (
            <div className="hadith-long-source">
              <span className="hadith-divider" />
              <span>{englishDigits(entry.source)}</span>
            </div>
          )}
        </div>
    </div>
  );
}
