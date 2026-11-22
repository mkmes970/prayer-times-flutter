package com.example.prayer_times

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.SystemClock
import android.os.Build
import android.Manifest
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal object PrayerSummaryNotificationManager {
    private const val PREFS_NAME = "PrayerSummaryNotification"
    private const val KEY_CONFIG = "config"
    private const val CHANNEL_ID = "prayer_times_daily_summary"
    private const val NOTIFICATION_ID = 5320
    private const val REQUEST_REFRESH = 5321
    private const val ACTION_REFRESH =
        "com.example.prayertimes.action.REFRESH_PRAYER_SUMMARY"
    private const val DATE_TIME_PATTERN = "yyyy-MM-dd'T'HH:mm:ss"
    private const val DATE_PATTERN = "yyyy-MM-dd"

    fun sync(context: Context, config: JSONObject): Boolean {
        ensureChannel(context)
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!config.optBoolean("enabled", false)) {
            preferences.edit().remove(KEY_CONFIG).apply()
            cancelRefresh(context)
            notificationManager(context).cancel(NOTIFICATION_ID)
            return true
        }

        preferences.edit().putString(KEY_CONFIG, config.toString()).apply()
        if (!notificationsAllowed(context)) {
            cancelRefresh(context)
            notificationManager(context).cancel(NOTIFICATION_ID)
            return false
        }
        refresh(context)
        return true
    }

    fun notificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        val manager = notificationManager(context)
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return manager.getNotificationChannel(CHANNEL_ID)?.importance !=
                NotificationManager.IMPORTANCE_NONE
        }
        return true
    }

    fun refresh(context: Context) {
        ensureChannel(context)
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_CONFIG, null) ?: return
        val config = try {
            JSONObject(raw)
        } catch (_: Exception) {
            cancelRefresh(context)
            notificationManager(context).cancel(NOTIFICATION_ID)
            return
        }
        if (!config.optBoolean("enabled", false)) {
            cancelRefresh(context)
            notificationManager(context).cancel(NOTIFICATION_ID)
            return
        }
        if (!notificationsAllowed(context)) {
            cancelRefresh(context)
            notificationManager(context).cancel(NOTIFICATION_ID)
            return
        }

        val correctionMillis =
            config.optLong("clockOffsetSeconds", 0L) * 1000L
        val correctedNow = System.currentTimeMillis() + correctionMillis
        val states = config.optJSONArray("states") ?: JSONArray()
        val orderedStates = (0 until states.length())
            .mapNotNull { index ->
                val state = states.optJSONObject(index) ?: return@mapNotNull null
                val at = parseLocalTime(state.optString("at"))
                    ?: return@mapNotNull null
                state to at
            }
            .sortedBy { it.second }
        var activeState: JSONObject? = null
        var nextStateAt: Long? = null
        for ((state, at) in orderedStates) {
            if (at <= correctedNow) {
                activeState = state
            } else if (nextStateAt == null) {
                nextStateAt = at
            }
        }

        val correctedTarget = activeState?.optString("target")
            ?.takeIf { it.isNotBlank() }
            ?.let(::parseLocalTime)
        val activeStateIsCurrent =
            correctedTarget == null || correctedTarget > correctedNow
        val displayState = activeState.takeIf { activeStateIsCurrent }
        val regionName = config.optString("regionName", "مواقيت الصلاة")
        val currentDate = formatDate(correctedNow)
        val schedule = findDailySchedule(config, currentDate)
        val label = displayState?.optString("label")
            ?.takeIf { it.isNotBlank() }
            ?: if (schedule == null) {
                "لا توجد مواقيت مسجلة ليوم $currentDate"
            } else {
                "لا يوجد عداد صلاة حالي"
            }
        val target = correctedTarget
            ?.takeIf { activeStateIsCurrent }
            ?.minus(correctionMillis)

        try {
            notificationManager(context).notify(
                NOTIFICATION_ID,
                buildNotification(context, regionName, label, schedule, target),
            )
        } catch (_: SecurityException) {
            cancelRefresh(context)
            return
        }

        if (nextStateAt != null) scheduleRefresh(context, nextStateAt)
        else cancelRefresh(context)
    }

    private fun findDailySchedule(config: JSONObject, date: String): JSONObject? {
        val today = config.optJSONObject("todaySchedule")
        if (today?.optString("date") == date) {
            today.optJSONObject("times")?.let { return it }
        }
        val schedules = config.optJSONArray("dailySchedules")
        if (schedules == null) return null
        for (index in 0 until schedules.length()) {
            val item = schedules.optJSONObject(index) ?: continue
            if (item.optString("date") == date) return item.optJSONObject("times")
        }
        return null
    }

    private fun buildNotification(
        context: Context,
        regionName: String,
        label: String,
        schedule: JSONObject?,
        targetMillis: Long?,
    ): Notification {
        val scheduleText = scheduleText(schedule)
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context,
                NOTIFICATION_ID,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(regionName)
            .setContentText(scheduleText.replace('\n', ' ' ))
            .setStyle(Notification.BigTextStyle().bigText("$scheduleText\n$label"))
            .setCategory(Notification.CATEGORY_STATUS)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setContentIntent(contentIntent)
            .setDefaults(0)
            .setSound(null)
            .setVibrate(null)

        val compact = RemoteViews(
            context.packageName,
            R.layout.prayer_summary_notification_compact,
        )
        val expanded = RemoteViews(
            context.packageName,
            R.layout.prayer_summary_notification_expanded,
        )
        bindSchedule(compact, schedule)
        bindSchedule(expanded, schedule)
        bindCountdown(compact, label, targetMillis)
        bindCountdown(expanded, label, targetMillis)
        builder.setShowWhen(false)
        if (Build.VERSION.SDK_INT >= 24) {
            builder
                .setCustomContentView(compact)
                .setCustomBigContentView(expanded)
                .setStyle(Notification.DecoratedCustomViewStyle())
        } else {
            builder.setStyle(Notification.BigTextStyle().bigText("$scheduleText\n$label"))
        }
        return builder.build()
    }

    private fun scheduleText(times: JSONObject?): String {
        val labels = listOf(
            "fajrSecond" to "الفجر الثاني",
            "dhuhr" to "الظهر",
            "asr" to "العصر",
            "maghrib" to "المغرب",
            "isha" to "العشاء",
        )
        val rows = labels.mapNotNull { (id, label) ->
            val time = times?.optString(id)
                ?.takeIf { it.isNotBlank() && it != "null" }
                ?: "—"
            "$label: $time"
        }
        return rows.joinToString("\n")
    }

    private fun bindSchedule(remoteViews: RemoteViews, times: JSONObject?) {
        val entries = listOf(
            "fajrSecond" to Pair(R.id.prayer_fajr_name, R.id.prayer_fajr_time),
            "dhuhr" to Pair(R.id.prayer_dhuhr_name, R.id.prayer_dhuhr_time),
            "asr" to Pair(R.id.prayer_asr_name, R.id.prayer_asr_time),
            "maghrib" to Pair(R.id.prayer_maghrib_name, R.id.prayer_maghrib_time),
            "isha" to Pair(R.id.prayer_isha_name, R.id.prayer_isha_time),
        )
        val labels = mapOf(
            "fajrSecond" to "الفجر الثاني",
            "dhuhr" to "الظهر",
            "asr" to "العصر",
            "maghrib" to "المغرب",
            "isha" to "العشاء",
        )
        entries.forEach { (id, views) ->
            val time = times?.optString(id)
                ?.takeIf { it.isNotBlank() && it != "null" }
                ?: "—"
            remoteViews.setTextViewText(views.first, labels.getValue(id))
            remoteViews.setTextViewText(views.second, time)
        }
    }

    private fun bindCountdown(
        remoteViews: RemoteViews,
        label: String,
        targetMillis: Long?,
    ) {
        remoteViews.setTextViewText(R.id.prayer_countdown_label, label)
        val now = System.currentTimeMillis()
        val target = targetMillis?.takeIf { it > now }
        if (target != null && Build.VERSION.SDK_INT >= 24) {
            val elapsedTarget = SystemClock.elapsedRealtime() + (target - now)
            remoteViews.setChronometer(
                R.id.prayer_countdown_value,
                elapsedTarget,
                null,
                true,
            )
            remoteViews.setChronometerCountDown(R.id.prayer_countdown_value, true)
        } else {
            remoteViews.setTextViewText(
                R.id.prayer_countdown_value,
                targetMillis?.let { formatRemaining(it - now) } ?: "--:--:--",
            )
        }
    }

    private fun formatRemaining(durationMillis: Long): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val hours = totalSeconds / 3600L
        val minutes = (totalSeconds % 3600L) / 60L
        val seconds = totalSeconds % 60L
        return String.format(Locale.ROOT, "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "مواقيت الصلاة اليومية",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "عرض صامت لمواقيت اليوم والعداد إلى الصلاة أو الإقامة"
            setSound(null, null)
            enableVibration(false)
            enableLights(false)
            setShowBadge(false)
        }
        notificationManager(context).createNotificationChannel(channel)
    }

    private fun scheduleRefresh(context: Context, correctedAtMillis: Long) {
        val correction = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_CONFIG, null)
            ?.let { runCatching { JSONObject(it).optLong("clockOffsetSeconds", 0L) }.getOrNull() }
            ?: 0L
        val triggerAtMillis = correctedAtMillis - correction * 1000L
        if (triggerAtMillis <= System.currentTimeMillis()) {
            refresh(context)
            return
        }

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val operation = refreshPendingIntent(context, PendingIntent.FLAG_UPDATE_CURRENT)
            ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                alarmManager.canScheduleExactAlarms()
            ) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    operation,
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    operation,
                )
            } else {
                @Suppress("DEPRECATION")
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, operation)
            }
        } catch (_: SecurityException) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    operation,
                )
            }
        }
    }

    private fun cancelRefresh(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        refreshPendingIntent(context, PendingIntent.FLAG_NO_CREATE)?.let {
            alarmManager.cancel(it)
            it.cancel()
        }
    }

    private fun refreshPendingIntent(context: Context, flags: Int): PendingIntent? {
        val intent = Intent(context, PrayerSummaryReceiver::class.java).apply {
            action = ACTION_REFRESH
            data = Uri.parse("prayer-times://summary/refresh")
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_REFRESH,
            intent,
            flags or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun parseLocalTime(value: String): Long? = try {
        val formatter = SimpleDateFormat(DATE_TIME_PATTERN, Locale.ROOT).apply {
            isLenient = false
            timeZone = TimeZone.getDefault()
        }
        formatter.parse(value)?.time
    } catch (_: Exception) {
        null
    }

    private fun formatDate(timeMillis: Long): String {
        val formatter = SimpleDateFormat(DATE_PATTERN, Locale.ROOT).apply {
            timeZone = TimeZone.getDefault()
        }
        return formatter.format(Date(timeMillis))
    }

    private fun notificationManager(context: Context): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
