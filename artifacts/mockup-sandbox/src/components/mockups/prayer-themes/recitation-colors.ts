export type RecitationPart = { text: string; recitation: boolean };

/** Color-only segmentation: joining the parts always reproduces the source. */
export function recitationParts(text: string, evening = false): RecitationPart[] {
  if (evening) return text.split(/(?<=\n)/).map(line => ({
    text: line,
    recitation: !/^(من |لم يضره|كانت له|حُطَّتْ|مائة حسنة)/.test(line.trimStart()),
  }));
  const quoted = /«[\s\S]*?»|\(\([\s\S]*?\)\)/g;
  const parts: RecitationPart[] = [];
  let offset = 0;
  for (const match of text.matchAll(quoted)) {
    if (match.index > offset) parts.push({ text: text.slice(offset, match.index), recitation: false });
    parts.push({ text: match[0], recitation: true });
    offset = match.index + match[0].length;
  }
  if (parts.length) {
    if (offset < text.length) parts.push({ text: text.slice(offset), recitation: false });
    return parts;
  }
  // Locate the reporting colon without removing any marks from displayed text.
  let plain = "";
  const positions: number[] = [];
  for (let index = 0; index < text.length; index++) {
    if (/[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]/.test(text[index])) continue;
    plain += text[index]; positions.push(index);
  }
  const report = /(?:رسول الله|النبي|صلى الله عليه وسلم|ﷺ)[^:\n]{0,150}:/.exec(plain);
  const colon = report ? positions[report.index + report[0].length - 1] : text.indexOf(":");
  if (colon >= 0) return [
    { text: text.slice(0, colon + 1), recitation: false },
    { text: text.slice(colon + 1), recitation: true },
  ];
  return [{ text, recitation: !/^ع[َ]?ن/.test(text) }];
}
