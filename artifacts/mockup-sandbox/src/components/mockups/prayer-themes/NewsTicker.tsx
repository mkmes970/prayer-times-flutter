import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { DuaRotation } from "./dua-rotation";
import { englishDigits } from "./english-digits";

export function NewsTicker({
  scrollingEnabled = false,
  speed = 32,
}: {
  scrollingEnabled?: boolean;
  speed?: number;
}) {
  const rotation = useRef<DuaRotation | null>(null);
  const deck = rotation.current ??= new DuaRotation();
  return scrollingEnabled
    ? <ScrollingTicker rotation={deck} speed={speed} />
    : <TimedTicker rotation={deck} />;
}

function TimedTicker({ rotation }: { rotation: DuaRotation }) {
  const [text, setText] = useState(() => rotation.current);
  useEffect(() => {
    let timer: number | undefined;
    const resume = () => {
      window.clearInterval(timer);
      if (!document.hidden) {
        timer = window.setInterval(() => setText(rotation.next()), 10_000);
      }
    };
    resume();
    document.addEventListener("visibilitychange", resume);
    return () => {
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", resume);
    };
  }, [rotation]);
  return <div className="news-ticker-static" dir="rtl">{englishDigits(text)}</div>;
}

/** A bounded queue, not a huge repeated DOM or a timer-driven text swap. */
function ScrollingTicker({ rotation, speed }: {
  rotation: DuaRotation;
  speed: number;
}) {
  const track = useRef<HTMLDivElement>(null);
  const speedRef = useRef(speed);
  speedRef.current = speed;
  useLayoutEffect(() => {
    const element = track.current!;
    const viewport = element.parentElement!;
    let offset = 0;
    let width = 0;
    let previous: number | undefined;
    let frame = 0;
    let disposed = false;
    const append = () => {
      const item = document.createElement("span");
      item.className = "news-ticker-item";
      const text = document.createElement("bdi");
      text.dir = "rtl";
      text.textContent = englishDigits(rotation.current);
      const separator = document.createElement("span");
      separator.className = "news-ticker-separator";
      separator.textContent = "﴿ ۞ ﴾";
      item.append(text, separator);
      element.append(item);
      rotation.next();
      width += item.offsetWidth;
    };
    const fill = () => {
      while (width - offset < viewport.clientWidth + 120) append();
    };
    // The first item is at the right end; new items join on the left.
    const paint = () => {
      element.style.transform = `translate3d(${offset - width}px,0,0)`;
    };
    const tick = (now: number) => {
      if (disposed) return;
      if (!document.hidden) {
        if (previous !== undefined) offset += (now - previous) * speedRef.current / 1000;
        previous = now;
        while (element.firstElementChild &&
          offset >= (element.firstElementChild as HTMLElement).offsetWidth) {
          const first = element.firstElementChild as HTMLElement;
          const removed = first.offsetWidth;
          offset -= removed;
          width -= removed;
          first.remove();
        }
        fill();
        paint();
      } else previous = undefined;
      frame = requestAnimationFrame(tick);
    };
    const measure = () => {
      width = Array.from(element.children)
        .reduce((sum, child) => sum + (child as HTMLElement).offsetWidth, 0);
      fill();
      paint();
    };
    const visibility = () => { previous = undefined; };
    const observer = new ResizeObserver(measure);
    observer.observe(viewport);
    fill();
    paint();
    frame = requestAnimationFrame(tick);
    document.addEventListener("visibilitychange", visibility);
    void document.fonts.ready.then(() => { if (!disposed) measure(); });
    return () => {
      disposed = true;
      cancelAnimationFrame(frame);
      observer.disconnect();
      document.removeEventListener("visibilitychange", visibility);
      element.replaceChildren();
    };
  }, [rotation]);
  return <div className="news-ticker-viewport" dir="ltr">
    <div ref={track} className="news-ticker-track" />
  </div>;
}
