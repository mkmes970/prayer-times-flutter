import catalogue from "../../../../../../mobile/prayer_times/assets/data/post-prayer-adhkar.json" with { type: "json" };
import type { AdhanPrayerId } from "./browser-prayer-schedule";
import { englishDigits } from "./english-digits.ts";

/** Presentation only: remove vowel marks; never add tatweel to Quran. */
export function stretchAdhkarText(text: string, isQuran = false) {
  text = englishDigits(text);
  text = text.replace(/[\u0610-\u061a\u064b-\u0652\u0656-\u065f\u0670\u06d6-\u06ed]/g, "");
  if (isQuran) return text;
  return text.replace(/[\u0621-\u063a\u0641-\u064a\u064b-\u065f\u0670]+/g, word => {
    const plain = word.replace(/[\u064b-\u065f\u0670]/g, "");
    if (plain.includes("الله")) return word;
    const letters = word.match(/[\u0621-\u063a\u0641-\u064a][\u064b-\u065f\u0670]*/g) ?? [];
    return letters.map((letter, index) => {
      const next = letters[index + 1]?.[0];
      const connects = next && !"ءآأؤإاةدذرزوَى".includes(letter[0]) && next !== "ء";
      const lamAlif = letter[0] === "ل" && next && "اأإآ".includes(next);
      return letter + (connects && !lamAlif ? "ـ" : "");
    }).join("");
  });
}

export function adhkarForPrayer(prayerId: AdhanPrayerId) {
  const special = prayerId === "fajrSecond" || prayerId === "maghrib";
  return catalogue.entries
    .filter((entry) => !entry.prayers || entry.prayers.includes(prayerId))
    .map((entry) => ({
      ...entry,
      note: special && entry.fajrMaghribNote ? entry.fajrMaghribNote : entry.note,
      weight: entry.weight * (special && entry.fajrMaghribNote ? 3 : 1),
    }));
}

export function adhkarBoardColumns(prayerId: AdhanPrayerId) {
  const pages = adhkarForPrayer(prayerId);
  const order = ["istighfar-salam", "la-hawla", "la-mania", "tasbih",
    "tahlil-ten", "ayat-kursi", "ikhlas", "falaq", "nas", "fajr-dua"];
  const sorted = order.flatMap(id => pages.filter(page => page.id === id));
  const weights = sorted.map(adhkarBoardWeight);
  const total = weights.reduce((sum, weight) => sum + weight, 0);
  let before = 0, best = Infinity, split = 1;
  for (let index = 1; index < sorted.length; index++) {
    before += weights[index - 1];
    const difference = Math.abs(total - before * 2);
    if (difference < best) { best = difference; split = index; }
  }
  return [sorted.slice(0, split), sorted.slice(split)];
}

type BoardEntry = ReturnType<typeof adhkarForPrayer>[number];
export function adhkarHasDetails(page: BoardEntry) {
  return Boolean(page.boardText || page.id === "tahlil-ten" || page.id === "fajr-dua");
}
export function adhkarBoardWeight(page: BoardEntry) {
  const text = (page.boardText ?? page.text) +
    (adhkarHasDetails(page) ? page.title + page.note : "");
  return text.replace(/[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]/g, "").length +
    35 + (text.match(/\n/g)?.length ?? 0) * 20;
}
