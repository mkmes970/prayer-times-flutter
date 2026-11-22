"""Extract the supplied PDF text glyphs, not substitute hadiths from elsewhere.

The PDFs use multi-letter Arabic glyphs. Reversing plain extracted strings
corrupts these ligatures (e.g. أبي becomes أيب). Keep each glyph's Unicode
expansion intact and reconstruct each physical line from right to left.
Optional vowel marks/tatweel are normalized away, not words or narrations.
"""
import hashlib
import json
import re
import unicodedata
import sys
from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "mobile/prayer_times/assets/data"
REVIEW = ROOT / "generated-artifacts/hadith-pdf-review"
SYMBOLS = {
    "\uf072": "صلى الله عليه وسلم",
    "\uf049": "رضي الله عنه",
    "\uf04c": "رضي الله عنهما",
    "\uf065": "صلى الله عليه وسلم",
    "\uf074": "رضي الله عنه",
    "\uf04a": "رضي الله عنها",
    "\uf04b": "رضي الله عنهم",
    "\uf020": " ",
}


def clean(text):
    text = unicodedata.normalize("NFKC", text)
    for source, replacement in SYMBOLS.items():
        text = text.replace(source, f" {replacement} ")
    text = "".join(c for c in text if not unicodedata.combining(c) and c != "ـ")
    # The 100-book's Allah ligature maps to االله in its embedded font.
    text = text.replace("االله", "الله")
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"\s+([،؛:.؟»])", r"\1", text)
    text = re.sub(r"(رضي الله عن(?:هما|هم|هن|ها|ه))(?=[\u0621-\u064a])", r"\1 ", text)
    return text


def glyphs(page):
    result = []
    for span in page.get_texttrace():
        raw = "".join(chr(c[0]) for c in span["chars"])
        if raw.isspace() and len(raw) > 2:
            continue  # The 100-book overlays space-only strings on its letters.
        previous = None
        for code, gid, origin, _bbox in span["chars"]:
            if gid == -1 and previous is not None:
                previous["text"] += chr(code)
            else:
                previous = dict(x=origin[0], y=origin[1], text=chr(code),
                                font=span["font"])
                result.append(previous)
        if span["font"] == "KFGQPCUthmanTahaNaskh":
            # The regular font's ToUnicode drops the second letter of these
            # two ligatures. Its bold counterpart has the same glyph IDs and
            # correct expansions; verified against the rendered source.
            groups = []
            for code, gid, origin, _bbox in span["chars"]:
                if gid != -1:
                    groups.append((gid, origin))
            for gid, origin in groups:
                if gid in (433, 502, 275):
                    for c in reversed(result):
                        if c["font"] == span["font"] and c["x"] == origin[0] and c["y"] == origin[1]:
                            c["text"] = {433: "بر", 502: "ضر", 275: ""}[gid]
                            break
    return result


def lines(chars):
    rows = []
    # Baselines differ slightly between typefaces. Ignore separately-positioned
    # optional marks rather than attaching them to a possibly incorrect letter.
    for c in sorted(chars, key=lambda c: c["y"]):
        c = dict(c, text=clean(c["text"]))
        if not c["text"]:
            continue
        if not rows or abs(rows[-1][0] - c["y"]) > 2:
            rows.append((c["y"], []))
        rows[-1][1].append(c)
    result = []
    for y, row in rows:
        row.sort(key=lambda c: -c["x"])
        # Digits are LTR within an Arabic line.
        i = 0
        while i < len(row):
            if row[i]["text"].isdigit():
                j = i + 1
                while j < len(row) and row[j]["text"].isdigit():
                    j += 1
                row[i:j] = reversed(row[i:j])
                i = j
            else:
                i += 1
        # Keep the source spaces: clean() above strips single-space glyphs,
        # so restore word boundaries using the original space glyphs below.
        original_spaces = [c for c in chars if c["text"] == " " and abs(c["y"]-y) <= 2]
        combined = [(c["x"], c["text"]) for c in row] + [(c["x"], " ") for c in original_spaces]
        combined.sort(key=lambda item: -item[0])
        # Sorting individual digit tuples again would undo LTR restoration.
        text = "".join(s for _, s in combined)
        text = re.sub(r"[0-9٠-٩]+", lambda m: m[0][::-1], text)
        result.append((y, clean(text)))
    return [(y, text) for y, text in result if text]


def extract_600(path):
    entries = []
    for pi, page in enumerate(fitz.open(path)):
        if not 6 <= pi <= 108:
            continue
        chars = glyphs(page)
        borders = sorted({round(d["rect"].y0, 1) for d in page.get_drawings()
                          if d["rect"].width > 400 and d["rect"].height < 2
                          and 60 < d["rect"].y0 < 780})
        boundaries = []
        for y in borders:
            if not boundaries or y - boundaries[-1] > 3:
                boundaries.append(y)
        if not boundaries:
            assert "حديث" in page.get_text() and len(page.get_text()) < 130, pi+1
            continue  # Level title pages contain no hadiths.
        assert len(boundaries) >= 2, (pi+1, boundaries)
        for top, bottom in zip(boundaries, boundaries[1:]):
            cell = [c for c in chars if top < c["y"] < bottom and 46 < c["x"] < 503]
            text = " ".join(t for _, t in lines(cell))
            if not text or text == "الحديث":
                continue
            number_chars = [c for c in chars if top < c["y"] < bottom and 505 < c["x"] < 541]
            number_text = "".join(c["text"] for c in sorted(number_chars, key=lambda c:c["x"]))
            number_text = re.sub(r"\s", "", number_text)
            if number_text.isdigit():
                number = int(number_text)
                assert number == len(entries)+1, (pi+1, number, len(entries))
                entries.append(dict(number=number, text=text, pages=[pi+1]))
            else:
                assert entries, (pi+1, text)
                entries[-1]["text"] += " " + text
                if pi+1 not in entries[-1]["pages"]:
                    entries[-1]["pages"].append(pi+1)
    assert len(entries) == 600, len(entries)
    for entry in entries:
        entry["text"] = entry["text"].replace("البخار ي", "البخاري")
    return entries


def extract_100(path):
    entries = []
    for pi, page in enumerate(fitz.open(path)):
        if pi < 2:
            continue
        for _, text in lines([c for c in glyphs(page) if 44 < c["y"] < 266]):
            match = re.match(r"^([0-9٠-٩][0-9٠-٩ ]{0,5})\s*[-–]\s*(.*)", text)
            if match:
                digits = match[1].replace(" ", "")
                number = int(digits)
                if number != len(entries)+1 and int(digits[::-1]) == len(entries)+1:
                    number = int(digits[::-1])
                if number != len(entries)+1:
                    raise ValueError((pi+1, number, len(entries), text))
                entries.append(dict(number=number, text=match[2], pages=[pi+1]))
            elif entries:
                entries[-1]["text"] += " " + text
                if pi+1 not in entries[-1]["pages"]:
                    entries[-1]["pages"].append(pi+1)
        if len(entries) == 100:
            break
    assert len(entries) == 100, len(entries)
    for entry in entries:
        entry["text"] = entry["text"].replace("))", "«").replace("((", "»")
    # Font ligature defects confirmed against the rendered pages, not
    # editorial corrections to the author's wording.
    fixes = {
        23: [("أبى (،", "أبى »،"), ("قال: ) من", "قال: « من")],
        31: [("والحمد الله", "والحمد لله")],
        40: [("أحد الله إلا", "أحد لله إلا")],
        81: [("باالشمال", "بالشمال")],
    }
    for number, replacements in fixes.items():
        for before, after in replacements:
            assert before in entries[number-1]["text"], (number, before)
            entries[number-1]["text"] = entries[number-1]["text"].replace(before, after)
    return entries


def main():
    REVIEW.mkdir(parents=True, exist_ok=True)
    for count, file, extract in [
        (600, "600_حديث_1792290728370.pdf", extract_600),
        (100, "Noor-Book.com_100_حديث_صحيح_للحفظ_من_قصار_الأحاديث_3__1792290728442.pdf", extract_100),
    ]:
        entries = extract(ROOT / "attached_assets" / file)
        value = dict(title=f"أحاديث الملف المرفق: {count} حديث", source_file=file,
                     extraction="Source glyph reconstruction; narrator and attribution retained; optional vowel marks normalized.",
                     entries=entries)
        value["source_sha256"] = hashlib.sha256(
            (ROOT / "attached_assets" / file).read_bytes()).hexdigest()
        assert [e["number"] for e in entries] == list(range(1, count+1))
        assert all("«" in e["text"] and
                   any(source in e["text"] for source in ["متفق عليه", "البخاري", "مسلم", "رواه مالك"])
                   for e in entries)
        assert all(not any(0xE000 <= ord(c) <= 0xF8FF or c == "\ufffd" for c in e["text"])
                   for e in entries)
        target = (DATA / f"pdf-hadiths-{count}.json" if "--write" in sys.argv
                  else REVIEW / f"pdf-hadiths-{count}-draft.json")
        target.write_text(json.dumps(value, ensure_ascii=False, indent=2)+"\n")
        print(count, "entries", len(entries), "last", entries[-1])


if __name__ == "__main__":
    main()
