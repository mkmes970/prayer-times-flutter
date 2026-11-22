"""Build the bundled Tal Ali JSON from the reviewed photographic transcription.

No year is inferred. Printed times use 12-hour notation; the two user-approved
intervals derive first Fajr and Isha, while all other columns are transcribed.
"""

import calendar
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).with_name("tal-ali-source.txt")
OUTPUT = ROOT / "mobile/prayer_times/assets/data/tal-ali-prayer-times.json"
MONTHS = [
    "كانون الثاني", "شباط", "آذار", "نيسان", "أيار", "حزيران",
    "تموز", "آب", "أيلول", "تشرين الأول", "تشرين الثاني", "كانون الأول",
]


def minutes(value, pm=False):
    hour, minute = divmod(int(value), 100)
    assert 1 <= hour <= 12 and 0 <= minute < 60, value
    return (hour % 12 + (12 if pm else 0)) * 60 + minute


def formatted(value):
    return f"{value // 60:02}:{value % 60:02}"


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
        fajr, sunrise, dhuhr, asr, maghrib = line.split()
        f, s, a, m = (minutes(fajr), minutes(sunrise),
                      minutes(asr, True), minutes(maghrib, True))
        # Noon may be 11:xx AM or 12:xx PM, exactly as printed.
        d = minutes(dhuhr, int(dhuhr) // 100 == 12)
        times = [f - 20, f, s, d, a, m, m + 80]
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
        # A leap-year calendar validates the supplied February 29 without
        # assigning that year to this recurring, yearless source timetable.
        assert len(month["days"]) == calendar.monthrange(2028, month["month"])[1]
    return {"name": "مواقيت الصلاة لقرية تل علي", "months": months}


if __name__ == "__main__":
    result = build()
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{OUTPUT.relative_to(ROOT)}: "
          f"{sum(len(m['days']) for m in result['months'])} days")
