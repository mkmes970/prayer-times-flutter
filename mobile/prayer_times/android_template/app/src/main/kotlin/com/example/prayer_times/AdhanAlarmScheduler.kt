package com.example.prayer_times

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

internal object AdhanAlarmScheduler {
    const val PREFS_NAME = "PrayerAdhan"
    const val ACTION_ADHAN_ALARM = "com.example.prayertimes.action.ADHAN_ALARM"
    const val EXTRA_VERSION = "schedule_version"
    const val EXTRA_PRAYER_ID = "prayer_id"
    const val EXTRA_DATE = "prayer_date"
    const val EXTRA_HOUR = "prayer_hour"
    const val EXTRA_MINUTE = "prayer_minute"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PRAYERS = "enabled_prayers"
    private const val KEY_EVENTS = "events"
    private const val KEY_VERSION = "version"
    private const val REQUEST_ALARM = 5317
    private const val REQUEST_OPEN_APP = 5318
    private val allowedPrayerIds = setOf("fajrSecond", "dhuhr", "asr", "maghrib", "isha")

    fun saveAndSchedule(
        context: Context,
        enabled: Boolean,
        prayerIds: Set<String>,
        events: JSONArray,
    ) {
        val safePrayerIds = prayerIds.intersect(allowedPrayerIds)
        val effectiveEnabled = enabled && safePrayerIds.isNotEmpty() && events.length() > 0
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val previousPrayerIds = preferences.getStringSet(KEY_PRAYERS, emptySet()) ?: emptySet()
        val version = preferences.getLong(KEY_VERSION, 0L) + 1L
        preferences.edit()
            .putBoolean(KEY_ENABLED, effectiveEnabled)
            .putStringSet(KEY_PRAYERS, safePrayerIds)
            .putString(KEY_EVENTS, events.toString())
            .putLong(KEY_VERSION, version)
            .apply()

        val currentPrayer = context.getSharedPreferences(
            AdhanPlaybackService.PREFS_NAME,
            Context.MODE_PRIVATE,
        ).getString(AdhanPlaybackService.KEY_CURRENT_PRAYER, null)
        if (!effectiveEnabled || (currentPrayer != null && currentPrayer !in safePrayerIds)) {
            context.stopService(Intent(context, AdhanPlaybackService::class.java))
        }
        if (!effectiveEnabled || previousPrayerIds != safePrayerIds) {
            // Replacing the single pending alarm invalidates any old settings.
            cancelAlarm(context)
        }
        if (!scheduleNext(context) && effectiveEnabled) {
            preferences.edit().putBoolean(KEY_ENABLED, false).apply()
            cancelAlarm(context)
            throw SecurityException("Could not schedule the next exact prayer alarm.")
        }
    }

    fun scheduleNext(context: Context): Boolean {
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val operation = pendingAlarm(context, PendingIntent.FLAG_UPDATE_CURRENT) ?: return false
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(operation)
        if (!preferences.getBoolean(KEY_ENABLED, false)) return true

        val enabledPrayers = preferences.getStringSet(KEY_PRAYERS, emptySet()) ?: emptySet()
        val rawEvents = preferences.getString(KEY_EVENTS, null) ?: return false
        val now = System.currentTimeMillis()
        val version = preferences.getLong(KEY_VERSION, 0L)
        val next = try {
            val events = JSONArray(rawEvents)
            (0 until events.length())
                .mapNotNull { index -> events.optJSONObject(index) }
                .asSequence()
                .filter { event -> event.optString("prayerId") in enabledPrayers }
                .mapNotNull { event -> event.toAlarmTime() }
                .filter { event -> event.timeMillis > now }
                .minByOrNull { event -> event.timeMillis }
        } catch (error: Exception) {
            Log.e("PrayerTimesAdhan", "Saved prayer schedule could not be read.", error)
            null
        } ?: return false

        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            action = ACTION_ADHAN_ALARM
            data = ALARM_URI
            putExtra(EXTRA_VERSION, version)
            putExtra(EXTRA_PRAYER_ID, next.prayerId)
            putExtra(EXTRA_DATE, next.date)
            putExtra(EXTRA_HOUR, next.hour)
            putExtra(EXTRA_MINUTE, next.minute)
        }
        val nextAlarm = PendingIntent.getBroadcast(
            context,
            REQUEST_ALARM,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val openApp = PendingIntent.getActivity(
            context,
            REQUEST_OPEN_APP,
            context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(next.timeMillis, openApp),
                nextAlarm,
            )
            return true
        } catch (error: SecurityException) {
            Log.e("PrayerTimesAdhan", "Exact alarm permission is unavailable.", error)
            return false
        }
    }

    fun cancelAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val operation = pendingAlarm(context, PendingIntent.FLAG_NO_CREATE)
        if (operation != null) {
            alarmManager.cancel(operation)
            operation.cancel()
        }
    }

    fun isCurrentSchedule(context: Context, version: Long, prayerId: String): Boolean {
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return preferences.getBoolean(KEY_ENABLED, false) &&
            preferences.getLong(KEY_VERSION, -1L) == version &&
            prayerId in (preferences.getStringSet(KEY_PRAYERS, emptySet()) ?: emptySet())
    }

    private fun pendingAlarm(context: Context, flags: Int): PendingIntent? {
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            action = ACTION_ADHAN_ALARM
            data = ALARM_URI
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_ALARM,
            intent,
            flags or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private data class AlarmTime(
        val prayerId: String,
        val date: String,
        val hour: Int,
        val minute: Int,
        val timeMillis: Long,
    )

    private fun JSONObject.toAlarmTime(): AlarmTime? {
        val prayerId = optString("prayerId")
        if (prayerId !in allowedPrayerIds) return null
        val date = optString("date")
        val hour = optInt("hour", -1)
        val minute = optInt("minute", -1)
        val second = optInt("second", 0)
        if (hour !in 0..23 || minute !in 0..59 || second !in 0..59) return null
        val parser = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply {
            isLenient = false
            timeZone = TimeZone.getDefault()
        }
        val parsedDate = try {
            parser.parse(date) ?: return null
        } catch (_: Exception) {
            return null
        }
        val calendar = Calendar.getInstance().apply {
            time = parsedDate
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, second)
            set(Calendar.MILLISECOND, 0)
        }
        return AlarmTime(prayerId, date, hour, minute, calendar.timeInMillis)
    }

    private val ALARM_URI: Uri = Uri.parse("prayer-times://adhan/next")
}
