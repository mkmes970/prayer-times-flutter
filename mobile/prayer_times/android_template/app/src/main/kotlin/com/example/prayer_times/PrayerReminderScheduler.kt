package com.example.prayer_times

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/** One persisted, chained alarm, independent of the adhan playback service. */
internal object PrayerReminderScheduler {
    const val ACTION = "com.example.prayertimes.action.PRAYER_REMINDER"
    private const val PREFS = "PrayerApproachingReminder"
    private const val REQUEST_ALARM = 5330
    private const val REQUEST_OPEN = 5331
    private val prayerIds = setOf("fajrSecond", "dhuhr", "asr", "maghrib", "isha")
    private val alarmUri = Uri.parse("prayer-times://reminder/next")

    fun sync(context: Context, config: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean("enabled", config.optBoolean("enabled", false))
            .putLong("correction", config.optLong("clockOffsetSeconds", 0L))
            .putString("events", (config.optJSONArray("reminders") ?: JSONArray()).toString())
            .putLong("version", prefs.getLong("version", 0L) + 1L)
            .apply()
        // A changed region/timetable must not leave an old reminder visible.
        PrayerReminderNotification.cancel(context)
        scheduleNext(context)
    }

    private data class Event(
        val key: String,
        val prayerId: String,
        val at: Long,
        val adhanAt: Long,
    )

    private fun events(raw: String?): List<Event> {
        val array = try {
            JSONArray(raw ?: "[]")
        } catch (error: Exception) {
            Log.e("PrayerReminder", "Saved reminder schedule is invalid.", error)
            return emptyList()
        }
        return (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            val id = item.optString("prayerId")
            if (id !in prayerIds) return@mapNotNull null
            val key = item.optString("key")
            val at = parse(item.optString("at")) ?: return@mapNotNull null
            val adhanAt = parse(item.optString("adhanAt")) ?: return@mapNotNull null
            if (key.isBlank() || adhanAt - at != 10L * 60L * 1000L) {
                return@mapNotNull null
            }
            Event(key, id, at, adhanAt)
        }
    }

    fun scheduleNext(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        pending(context, PendingIntent.FLAG_NO_CREATE)?.let {
            manager.cancel(it)
            it.cancel()
        }
        if (!prefs.getBoolean("enabled", false)) return
        val correction = prefs.getLong("correction", 0L) * 1000L
        val now = System.currentTimeMillis() + correction
        val delivered = prefs.getStringSet("delivered", emptySet()) ?: emptySet()
        val next = events(prefs.getString("events", null))
            .filter { it.at >= now && it.key !in delivered }
            .minByOrNull { it.at } ?: return
        val operation = PendingIntent.getBroadcast(
            context,
            REQUEST_ALARM,
            intent(context).apply {
                putExtra("version", prefs.getLong("version", 0L))
                putExtra("event_key", next.key)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val at = (next.at - correction).coerceAtLeast(System.currentTimeMillis() + 1L)
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                manager.canScheduleExactAlarms()
            ) {
                val showIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.let {
                        PendingIntent.getActivity(
                            context, REQUEST_OPEN, it,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                        )
                    } ?: operation
                manager.setAlarmClock(AlarmManager.AlarmClockInfo(at, showIntent), operation)
            } else {
                scheduleInexact(manager, at, operation)
            }
        } catch (_: SecurityException) {
            // Access can change between the permission check and setAlarmClock.
            scheduleInexact(manager, at, operation)
        }
    }

    fun onAlarm(context: Context, received: Intent) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        try {
            if (!prefs.getBoolean("enabled", false) ||
                received.getLongExtra("version", -1L) != prefs.getLong("version", 0L)
            ) return
            val event = events(prefs.getString("events", null))
                .firstOrNull { it.key == received.getStringExtra("event_key") } ?: return
            val now = System.currentTimeMillis() + prefs.getLong("correction", 0L) * 1000L
            val delivered = (prefs.getStringSet("delivered", emptySet()) ?: emptySet()).toMutableSet()
            if (now < event.at || event.key in delivered) return
            delivered.add(event.key)
            // Persist delivery before notifying, including after a delayed alarm.
            prefs.edit().putStringSet("delivered", delivered.sorted().takeLast(64).toSet()).apply()
            // Never send a misleading "10 minutes" alert at/after adhan, or
            // replay missed alerts after a long suspension or time change.
            if (now < event.adhanAt && now - event.at < 60_000L) {
                PrayerReminderNotification.show(context, event.prayerId, event.adhanAt - now)
            }
        } finally {
            scheduleNext(context)
        }
    }

    private fun scheduleInexact(manager: AlarmManager, at: Long, operation: PendingIntent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, operation)
        } else {
            manager.set(AlarmManager.RTC_WAKEUP, at, operation)
        }
    }

    private fun intent(context: Context) =
        Intent(context, PrayerReminderReceiver::class.java).apply {
            action = ACTION
            data = alarmUri
        }

    private fun pending(context: Context, flags: Int): PendingIntent? =
        PendingIntent.getBroadcast(
            context, REQUEST_ALARM, intent(context),
            flags or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun parse(value: String): Long? = try {
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.ROOT).apply {
            isLenient = false
            timeZone = TimeZone.getDefault()
        }.parse(value)?.time
    } catch (_: Exception) {
        null
    }
}
