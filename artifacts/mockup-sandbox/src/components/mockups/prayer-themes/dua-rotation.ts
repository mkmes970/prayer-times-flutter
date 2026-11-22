import content from "../../../../../../mobile/prayer_times/assets/data/dua-ticker.json" with { type: "json" };
import hadiths600 from "../../../../../../mobile/prayer_times/assets/data/pdf-hadiths-600.json" with { type: "json" };

export type DuaGroup = { readonly author?: string; readonly texts: readonly string[] };

export const duaIntervalMs = content.interval_seconds * 1000;
export const duaGroups: readonly DuaGroup[] = [
  ...content.supplications.map((text) => ({ texts: [text] })),
  ...content.independent_quotes.map((text) => ({ texts: [text] })),
  ...content.author_groups.flatMap(group =>
    group.texts.map(text => ({ author: group.author, texts: [text] }))),
  ...hadiths600.entries.map(entry => ({ texts: [entry.text] })),
];

/** Every individual text joins the same shuffled, non-repeating cycle. */
export class DuaRotation {
  private remaining: number[] = [];
  private groupIndex = -1;
  private quoteIndex = 0;

  constructor(
    private readonly groups: readonly DuaGroup[] = duaGroups,
    private readonly random: () => number = Math.random,
  ) {
    if (!groups.length || groups.some((group) => !group.texts.length)) {
      throw new Error("قائمة نصوص الشريط فارغة");
    }
    this.startNextGroup();
  }

  get group() { return this.groups[this.groupIndex]!; }
  get textIndex() { return this.quoteIndex; }
  get current() {
    const text = this.group.texts[this.quoteIndex]!;
    return this.group.author ? `قال ${this.group.author}: ${text}` : text;
  }

  next() {
    if (this.quoteIndex + 1 < this.group.texts.length) {
      this.quoteIndex++;
    } else {
      this.startNextGroup();
    }
    return this.current;
  }

  private startNextGroup() {
    if (!this.remaining.length) {
      this.remaining = this.groups.map((_, index) => index);
      for (let i = this.remaining.length - 1; i > 0; i--) {
        const j = Math.floor(this.random() * (i + 1));
        [this.remaining[i], this.remaining[j]] = [this.remaining[j]!, this.remaining[i]!];
      }
      const last = this.remaining.length - 1;
      if (last > 0 && this.remaining[last] === this.groupIndex) {
        [this.remaining[0], this.remaining[last]] = [this.remaining[last]!, this.remaining[0]!];
      }
    }
    this.groupIndex = this.remaining.pop()!;
    this.quoteIndex = 0;
  }
}
