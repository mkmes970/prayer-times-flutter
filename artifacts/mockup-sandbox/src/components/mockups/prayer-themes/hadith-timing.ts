export const normalInformationSeconds = 5;

// Keep these thresholds in sync with the native hadith-timing policy.
export function hadithDurationSeconds(parts: object): number {
  return readingDuration(parts, 20, 60);
}

export function adhanDurationSeconds(parts: object): number {
  return readingDuration(parts, 15, 50);
}

function readingDuration(parts: object, minimum: number, maximum: number): number {
  const plain = Object.values(parts).filter((part): part is string => typeof part === "string").join(" ")
    .replace(/[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]/g, "");
  const characters = (plain.match(/[A-Za-z0-9\u0621-\u064a\u0660-\u0669]/g) ?? []).length;
  return Math.min(maximum, minimum + Math.max(0, Math.ceil(characters / 150) - 1) * 5);
}
