# Recurring regional timetables

## Zab

Approved display name: **مواقيت الصلاة لناحية الزاب وضواحيها**.

Run `python scripts/schedules/build_zab.py` to generate
`mobile/prayer_times/assets/data/zab-prayer-times.json`.
The four columns in `zab-source.txt` are second Fajr, Dhuhr, Asr and Maghrib,
using the photographs' 12-hour notation. Output uses unambiguous 24-hour
storage, while the application's existing 12-hour display is unchanged.

User-approved rules and corrections:

- First Fajr = second Fajr minus 15 minutes.
- Sunrise = second Fajr plus 80 minutes.
- Isha = Maghrib plus 80 minutes; preserve source Maghrib otherwise.
- December 5 Maghrib: 16:54.
- December 7 Asr: 14:28, explicitly confirmed despite neighbouring 14:38.
- January 3 Dhuhr: 12:16 (missing colon in the photograph).
- March 31 sunrise is therefore 05:59 from second Fajr 04:39.

All 366 month/day entries are retained, including February 29. No source
year is inferred.

Photographs in `attached_assets/`, with filenames beginning
`IMG-20261030-WA` and suffixes `_179337083*.jpg`:

| Month | Photo number |
| --- | --- |
| 1 | 0052 |
| 2 | 0053 |
| 3 | 0051 |
| 4 | 0057 |
| 5 | 0061 |
| 6 | 0062 |
| 7 | 0059 |
| 8 | 0058 |
| 9 | 0055 |
| 10 | 0054 |
| 11 | 0060 |
| 12 | 0056 |

## Tal Ali

Approved display name: **مواقيت الصلاة لقرية تل علي**.

The compact transcription in `tal-ali-source.txt` contains one row for each
printed day, in month/day order. Its five columns are second Fajr, sunrise,
Dhuhr, Asr and Maghrib, in the source's 12-hour notation. Afternoon/evening is
determined by the column, not by guessing from a bare hour.

Run `python scripts/schedules/build_tal_ali.py` from the workspace root to
regenerate the bundled JSON. The output uses explicit 24-hour storage; the
existing application continues to display 12-hour times.

The user explicitly approved:

- The village name above, disregarding the printed Kirkuk footer.
- First Fajr exactly 20 minutes before second Fajr.
- Isha exactly 80 minutes after Maghrib.

Those two intervals are authoritative during generation. In particular,
November 17 and 18 print first Fajr as 05:01/05:02 against second Fajr
05:22/05:23; the approved rule yields first Fajr **05:02/05:03**.
Sunrise is independently transcribed, not derived from a fixed interval.
For example, July 11 is second Fajr 03:41 and sunrise 05:02.

The twelve images include February 29. All 366 dates are retained as a
yearless recurring schedule. A leap-year calendar is used only to validate
the day counts, not to assign a source year.

## Source image mapping

All images are under `attached_assets/`. The suffixes below uniquely identify
the supplied originals without depending on the Unicode direction marks in
their CamScanner filenames.

| Month | Image filename suffix |
|---|---|
| 1 | `1793355062547.jpg` |
| 2 | `1793355062504.jpg` |
| 3 | `1793355062428.jpg` |
| 4 | `1793355062455.jpg` |
| 5 | `1793355062578.jpg` |
| 6 | `1793355062643.jpg` |
| 7 | `1793355062615.jpg` |
| 8 | `1793355062477.jpg` |
| 9 | `1793355062629.jpg` |
| 10 | `1793355062564.jpg` |
| 11 | `1793355062598.jpg` |
| 12 | `1793355062656.jpg` |
