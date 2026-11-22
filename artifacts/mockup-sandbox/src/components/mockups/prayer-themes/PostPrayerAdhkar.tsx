import { useLayoutEffect, useMemo, useRef } from "react";
import { adhkarBoardColumns, adhkarHasDetails, stretchAdhkarText } from "./post-prayer-adhkar";
import type { AdhanPrayerId } from "./browser-prayer-schedule";

export function PostPrayerAdhkar({ prayerId }: {
  prayerId: AdhanPrayerId; startsAt: number; endsAt: number;
}) {
  const columns = useMemo(() => adhkarBoardColumns(prayerId), [prayerId]);
  const boardRef = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const board = boardRef.current;
    if (!board) return;
    let frame = 0;
    let disposed = false;
    const fit = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        if (disposed || !board.clientHeight || !board.clientWidth) return;
        // Measure natural text height, not the scroll height of space-between
        // columns: Arabic glyph overhang can otherwise shrink the entire board.
        for (const column of Array.from(board.children) as HTMLElement[]) {
          let low = 1, high = board.clientWidth * .045;
          const fits = () => {
          const entries = Array.from(column.children) as HTMLElement[];
          const gap = parseFloat(getComputedStyle(column).rowGap) || 0;
          const usedHeight = entries.reduce((sum, entry) => sum + entry.offsetHeight, 0)
            + Math.max(0, entries.length - 1) * gap;
          return usedHeight <= column.clientHeight - 4 &&
            entries.every(entry => entry.scrollWidth <= column.clientWidth + 1);
          };
          for (let attempt = 0; attempt < 12; attempt++) {
            const size = (low + high) / 2;
            column.style.fontSize = `${size}px`;
            if (fits()) low = size; else high = size;
          }
          column.style.fontSize = `${low * .99}px`;
        }
      });
    };
    const observer = new ResizeObserver(fit);
    observer.observe(board);
    void document.fonts.ready.then(fit);
    fit();
    return () => {
      disposed = true;
      observer.disconnect();
      cancelAnimationFrame(frame);
    };
  }, [columns]);
  return (
    <div ref={boardRef} className="prayer-activity-dhikr prayer-dhikr-board" data-testid="post-prayer-adhkar" dir="rtl">
      {columns.map((pages, column) => (
        <div className="prayer-dhikr-column" key={column} data-testid={`adhkar-column-${column}`}>
          {pages.map((page, index) => (
            <section className="prayer-dhikr-entry" key={page.id} data-dhikr-id={page.id}
              style={{ color: (index + (column === 1 ? columns[0].length : 0)) % 2 === 0 ? "#008000" : "#d00000" }}>
              <p>
                <span className="prayer-dhikr-ornament" aria-hidden="true">۞ </span>
                {adhkarHasDetails(page) && <strong className="prayer-dhikr-detail">{stretchAdhkarText(page.title)}: </strong>}
                {(page.boardText ?? page.text).split("\n").map((line, index) => (
                  <span key={index} className={page.id === "tasbih" && index === 1 ? "prayer-dhikr-detail" : undefined}>
                    {index > 0 && <br />}{stretchAdhkarText(line, Boolean(page.boardText))}
                  </span>
                ))}
              </p>
              {adhkarHasDetails(page) && <p className="prayer-dhikr-note">({stretchAdhkarText(`${page.boardText ? "تُقرأ كاملة — " : ""}${page.note}`)})</p>}
            </section>
          ))}
        </div>
      ))}
    </div>
  );
}
