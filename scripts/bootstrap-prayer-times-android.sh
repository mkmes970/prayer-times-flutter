#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/mobile/prayer_times"
cd "$APP_DIR"

flutter create \
  --platforms=android \
  --org com.example \
  --project-name prayer_times \
  --no-pub \
  .

mkdir -p android/app/src/main/kotlin/com/example/prayer_times
# Keep the generated scaffold compatible with the locked Android plugins.
# package_info_plus/wakelock_plus require AGP 8.12.1, Kotlin 2.2 and Gradle 8.13.
cp "$APP_DIR/android_template/settings.gradle.kts" android/settings.gradle.kts
cp "$APP_DIR/android_template/gradle/wrapper/gradle-wrapper.properties" \
   android/gradle/wrapper/gradle-wrapper.properties
cp "$APP_DIR/android_template/app/src/main/AndroidManifest.xml" \
  android/app/src/main/AndroidManifest.xml
cp "$APP_DIR/android_template/app/src/main/kotlin/com/example/prayer_times/MainActivity.kt" \
  android/app/src/main/kotlin/com/example/prayer_times/MainActivity.kt
cp "$APP_DIR/android_template/app/src/main/kotlin/com/example/prayer_times/BootReceiver.kt" \
  android/app/src/main/kotlin/com/example/prayer_times/BootReceiver.kt
cp "$APP_DIR/android_template/app/src/main/kotlin/com/example/prayer_times/AdhanAlarmScheduler.kt" \
  android/app/src/main/kotlin/com/example/prayer_times/AdhanAlarmScheduler.kt
cp "$APP_DIR/android_template/app/src/main/kotlin/com/example/prayer_times/AdhanAlarmReceiver.kt" \
  android/app/src/main/kotlin/com/example/prayer_times/AdhanAlarmReceiver.kt
cp "$APP_DIR/android_template/app/src/main/kotlin/com/example/prayer_times/AdhanPlaybackService.kt" \
  android/app/src/main/kotlin/com/example/prayer_times/AdhanPlaybackService.kt
cp "$APP_DIR/android_template/app/src/main/kotlin/com/example/prayer_times/PrayerSummaryNotificationManager.kt" \
  android/app/src/main/kotlin/com/example/prayer_times/PrayerSummaryNotificationManager.kt
cp "$APP_DIR/android_template/app/src/main/kotlin/com/example/prayer_times/PrayerSummaryReceiver.kt" \
  android/app/src/main/kotlin/com/example/prayer_times/PrayerSummaryReceiver.kt
for source in PrayerReminderScheduler PrayerReminderNotification PrayerReminderReceiver; do
  cp "$APP_DIR/android_template/app/src/main/kotlin/com/example/prayer_times/$source.kt" \
    "android/app/src/main/kotlin/com/example/prayer_times/$source.kt"
done
# Copy after flutter create so its default Flutter icon cannot replace ours.
cp -R "$APP_DIR/android_template/app/src/main/res/." android/app/src/main/res/
echo "Android project files are ready in $APP_DIR/android."
