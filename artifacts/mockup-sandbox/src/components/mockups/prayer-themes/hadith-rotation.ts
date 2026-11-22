export type HadithEntry = {
  number?: number;
  text: string;
  narrator?: string;
  introduction?: string;
  source?: string;
  sourceNumber?: number;
  explanation?: string;
};

export class HadithRotation {
  private readonly all: HadithEntry[];
  private readonly others: HadithEntry[];
  private readonly nonRamadan: HadithEntry[];
  private allBag: HadithEntry[] = [];
  private otherBag: HadithEntry[] = [];
  private fridayBag: HadithEntry[] = [];
  private ramadanBag: HadithEntry[] = [];
  private nonRamadanBag: HadithEntry[] = [];
  private weights: Array<"friday" | "ramadan" | "other"> = [];
  private showingFriday = false;
  private showingRamadan = false;
  private selected: HadithEntry;

  constructor(
    readonly ordered: HadithEntry[],
    readonly randomHadiths: HadithEntry[],
    readonly fridayHadiths: HadithEntry[] = [],
    readonly ramadanHadiths: HadithEntry[] = [],
  ) {
    this.nonRamadan = [...ordered, ...randomHadiths];
    this.others = [...this.nonRamadan, ...ramadanHadiths];
    this.all = [...this.others, ...fridayHadiths];
    if (!this.all.length) throw new Error("Hadith catalogue is empty.");
    this.selected = this.draw();
  }

  get isFridayMode() {
    return this.showingFriday;
  }

  get current(): HadithEntry {
    return this.selected;
  }

  get currentIsFridayHadith() {
    return this.fridayHadiths.includes(this.selected);
  }

  selectForPreview(entry: HadithEntry) {
    if (!this.all.includes(entry)) throw new Error("Unknown preview hadith.");
    this.selected = entry;
  }

  setFridayMode(enabled: boolean) {
    const shouldShowFriday = enabled && this.fridayHadiths.length > 0;
    if (this.showingFriday === shouldShowFriday) return;
    this.showingFriday = shouldShowFriday;
    this.weights = [];
    this.selected = this.draw();
  }

  setRamadanMode(enabled: boolean) {
    const shouldShowRamadan = enabled && this.ramadanHadiths.length > 0;
    if (this.showingRamadan === shouldShowRamadan) return;
    this.showingRamadan = shouldShowRamadan;
    this.weights = [];
    this.selected = this.draw();
  }

  next(): HadithEntry {
    this.selected = this.draw();
    return this.current;
  }

  private draw(): HadithEntry {
    if (this.showingRamadan) {
      if (this.showingFriday) {
        if (!this.weights.length) {
          this.weights = this.shuffle([
            "friday", "friday",
            "ramadan", "ramadan",
            "other", "other", "other",
          ]);
        }
        const category = this.weights.pop();
        if (category === "friday") return this.takeFrom(this.fridayBag, this.fridayHadiths);
        if (category === "ramadan") return this.takeFrom(this.ramadanBag, this.ramadanHadiths);
        return this.takeFrom(this.nonRamadanBag, this.nonRamadan);
      }
      if (!this.weights.length) {
        this.weights = this.shuffle([
          "ramadan", "ramadan", "other", "other", "other",
        ]);
      }
      return this.weights.pop() === "ramadan"
        ? this.takeFrom(this.ramadanBag, this.ramadanHadiths)
        : this.takeFrom(this.nonRamadanBag, this.nonRamadan);
    }
    if (this.showingFriday) {
      if (!this.others.length) return this.takeFrom(this.fridayBag, this.fridayHadiths);
      // Three Friday entries and two general entries per shuffled block of five.
      if (!this.weights.length) this.weights = this.shuffle([
        "friday", "friday", "friday", "other", "other",
      ]);
      if (this.weights.pop() === "friday") {
        if (!this.fridayBag.length) this.fridayBag = this.shuffle([...this.fridayHadiths]);
        return this.fridayBag.pop()!;
      }
      if (!this.otherBag.length) this.otherBag = this.shuffle([...this.others]);
      return this.otherBag.pop()!;
    }
    if (!this.allBag.length) this.allBag = this.shuffle([...this.all]);
    return this.allBag.pop()!;
  }

  private takeFrom(bag: HadithEntry[], entries: HadithEntry[]) {
    if (!entries.length) throw new Error("Hadith selection category is empty.");
    if (!bag.length) bag.push(...this.shuffle([...entries]));
    return bag.pop()!;
  }

  private shuffle<T>(items: T[]): T[] {
    for (let index = items.length - 1; index > 0; index--) {
      const other = Math.floor(Math.random() * (index + 1));
      [items[index], items[other]] = [items[other], items[index]];
    }
    return items;
  }
}
