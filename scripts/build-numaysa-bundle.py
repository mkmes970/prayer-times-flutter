"""Build Numaysa's recurring schedule from the transcribed monthly photographs.

The CSV retains the six photographed columns (12-hour clocks). Only the two
user-confirmed Fajr resolutions and the requested first-Fajr offset apply.
No interpolation, astronomical calculation or other region's data is used.
"""

import calendar
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "mobile/prayer_times/test/fixtures/numaysa-source.csv"
OUTPUT = ROOT / "mobile/prayer_times/assets/data/numaysa-prayer-times.json"
TITLE = "مواقيت الصلاة لقرية النميصة"
MONTH_NAMES = (
    "كانون الثاني", "شباط", "آذار", "نيسان", "أيار", "حزيران",
    "تموز", "آب", "أيلول", "تشرين الأول", "تشرين الثاني", "كانون الأول",
)
SOURCE_FIELDS = ("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")
CONFIRMED_FAJR = {(5, 3): "3:53", (12, 13): "5:47"}


def minutes(value):
    hour, minute = map(int, value.split(":"))
    if not 1 <= hour <= 12 or not 0 <= minute <= 59:
        raise ValueError(f"Invalid source time: {value}")
    return hour * 60 + minute


def clock(value):
    return f"{value // 60:02d}:{value % 60:02d}"


def build():
    months = [
        {"month": month, "month_name": name, "days": []}
        for month, name in enumerate(MONTH_NAMES, 1)
    ]
    seen = set()
    with SOURCE.open(encoding="utf-8", newline="") as stream:
        for row in csv.DictReader(stream):
            month, day = int(row["month"]), int(row["day"])
            if not 1 <= month <= 12:
                raise ValueError(f"Invalid month: {month}")
            if not 1 <= day <= calendar.monthrange(2000, month)[1]:
                raise ValueError(f"Invalid date: {month}/{day}")
            if (month, day) in seen:
                raise ValueError(f"Duplicate date: {month}/{day}")
            seen.add((month, day))
            times = {field: minutes(row[field]) for field in SOURCE_FIELDS}
            times["fajr"] = minutes(
                CONFIRMED_FAJR.get((month, day), row["fajr"])
            )
            # Dhuhr 11:xx is before noon; 12:xx is noon. The later
            # afternoon/evening columns use PM, as on the photographs.
            ordered = [
                times["fajr"] - 15,
                times["fajr"],
                times["sunrise"],
                times["dhuhr"],
                times["asr"] + 12 * 60,
                times["maghrib"] + 12 * 60,
                times["isha"] + 12 * 60,
            ]
            if ordered != sorted(set(ordered)):
                raise ValueError(f"Non-increasing times on {month}/{day}")
            months[month - 1]["days"].append({
                "day": day,
                "fajr_first": clock(times["fajr"] - 15),
                "fajr_second": clock(times["fajr"]),
                **{
                    field: clock(times[field])
                    for field in SOURCE_FIELDS if field != "fajr"
                },
            })
    for month in months:
        month["days"].sort(key=lambda row: row["day"])
        expected = calendar.monthrange(2000, month["month"])[1]
        if [row["day"] for row in month["days"]] != list(range(1, expected + 1)):
            raise ValueError(f"Incomplete month: {month['month']}")
    if len(seen) != 366:
        raise ValueError(f"Expected 366 days, got {len(seen)}")
    return {"name": TITLE, "months": months}


if __name__ == "__main__":
    OUTPUT.write_text(
        json.dumps(build(), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("Numaysa: 366 days; approved Fajr corrections; first Fajr −15 minutes.")
