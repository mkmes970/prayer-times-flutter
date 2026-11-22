"""Build the approved, yearless Zab timetable from its photographic transcription.

The source retains second Fajr, Dhuhr, Asr and Maghrib. The user's approved
15/80/80-minute rules derive first Fajr, sunrise and Isha respectively.
"""

import calendar
import json
from pathlib import Path

from build_tal_ali import MONTHS, formatted, minutes

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).with_name("zab-source.txt")
OUTPUT = ROOT / "mobile/prayer_times/assets/data/zab-prayer-times.json"


def build():
    months = []
    for line in SOURCE.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        if line.startswith("@"):
            month = int(line[1:])
            assert month == len(months) + 1
            months.append({
                "month": month, "month_name": MONTHS[month - 1], "days": [],
            })
            continue
        fajr, dhuhr, asr, maghrib = line.split()
        f = minutes(fajr)
        d = minutes(dhuhr, int(dhuhr) // 100 == 12)
        a, m = minutes(asr, True), minutes(maghrib, True)
        times = [f - 15, f, f + 80, d, a, m, m + 80]
        assert all(x < y for x, y in zip(times, times[1:])), line
        day = {"day": len(months[-1]["days"]) + 1}
        day.update(zip(
            ["fajr_first", "fajr_second", "sunrise", "dhuhr",
             "asr", "maghrib", "isha"],
            map(formatted, times),
        ))
        months[-1]["days"].append(day)
    assert len(months) == 12
    for month in months:
        # Calendar shape only: no source year is assigned to this annual table.
        assert len(month["days"]) == calendar.monthrange(2028, month["month"])[1]
    return {"name": "مواقيت الصلاة لناحية الزاب وضواحيها", "months": months}


if __name__ == "__main__":
    result = build()
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{OUTPUT.relative_to(ROOT)}: "
          f"{sum(len(m['days']) for m in result['months'])} days")
