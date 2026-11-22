"""Convert the verified source into the app's seven-column schedule format."""
import json
from pathlib import Path

source = json.loads(Path("generated-artifacts/baggara-prayer-times.json").read_text())
months = []
for month in source["months"]:
    days = []
    for row in month["days"]:
        hour, minute = map(int, row["fajr"].split(":"))
        first = hour * 60 + minute - 15
        days.append({
            "day": row["day"],
            "fajr_first": f"{first // 60:02d}:{first % 60:02d}",
            "fajr_second": row["fajr"],
            **{key: row[key] for key in ("sunrise", "dhuhr", "asr", "maghrib", "isha")},
        })
    months.append({"month": month["month"], "month_name": month["name"], "days": days})
bundle = {"name": source["title"], "months": months}
Path("mobile/prayer_times/assets/data/baggara-prayer-times.json").write_text(
    json.dumps(bundle, ensure_ascii=False, indent=2) + "\n"
)
print("Baggara bundle: 366 days; first Fajr 15 minutes before source Fajr.")
