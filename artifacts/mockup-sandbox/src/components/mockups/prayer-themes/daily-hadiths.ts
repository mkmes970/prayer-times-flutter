import catalogue from "../../../../../../mobile/prayer_times/assets/data/daily-hadiths-from-images.json";
import type { HadithEntry } from "./hadith-rotation";

type ImageCatalogue = {
  narrators: Record<string, string>;
  reports: Record<string, string>;
  sources: Record<string, string>;
  entries: (string | number)[][];
};

export function parseImageHadithCatalogue(data: ImageCatalogue): HadithEntry[] {
  if (data.entries.length !== 200) {
    throw new Error("Image catalogue must contain 200 hadiths.");
  }
  return data.entries.map((row, index) => {
    const [sourceNumber, narratorId, reportId, body, sourceId, explanation] = row;
    if ((row.length !== 5 && row.length !== 6) ||
        sourceNumber !== index + 1 ||
        !Object.hasOwn(data.narrators, narratorId) ||
        !Object.hasOwn(data.reports, reportId) ||
        !Object.hasOwn(data.sources, sourceId) ||
        typeof body !== "string" || !body.trim()) {
      throw new Error(`Invalid image hadith ${index + 1}.`);
    }
    const prefix = `عن ${data.narrators[narratorId]}`;
    const report = data.reports[reportId];
    const narrative = reportId === "narrative" ||
      reportId === "womanNarrative" || reportId === "plain";
    return {
      sourceNumber: sourceNumber as number,
      text: report ? `${prefix} ${report}: ${narrative ? body : `«${body}»`}`
        : `${prefix} ${body}`,
      source: data.sources[sourceId],
      ...(typeof explanation === "string" ? { explanation } : {}),
    };
  });
}

export const dailyImageHadiths = parseImageHadithCatalogue(catalogue);
