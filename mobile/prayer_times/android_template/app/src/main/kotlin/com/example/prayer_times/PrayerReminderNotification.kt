package com.example.prayer_times

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

/** Separate audible reminder; never changes the silent timetable channel. */
internal object PrayerReminderNotification {
    private const val CHANNEL_ID = "prayer_times_approaching_adhan"
    private const val NOTIFICATION_ID = 5332
    private val prayerNames = mapOf(
        "fajrSecond" to "الفجر",
        "dhuhr" to "الظهر",
        "asr" to "العصر",
        "maghrib" to "المغرب",
        "isha" to "العشاء",
    )

    fun cancel(context: Context) {
        manager(context).cancel(NOTIFICATION_ID)
    }

    fun show(context: Context, prayerId: String, remainingToAdhan: Long) {
        val name = prayerNames[prayerId] ?: return
        if (remainingToAdhan <= 0L) return
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return
        val manager = manager(context)
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "التنبيه قبل الأذان بعشر دقائق",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "تنبيه بنغمة إشعارات الهاتف عند اقتراب الصلاة"
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                enableVibration(true)
            }
            manager.createNotificationChannel(channel)
        }

        val text = "تبقّت 10 دقائق على أذان $name. تهيّأ للصلاة، تقبّل الله طاعتك."
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
                .setTimeoutAfter(remainingToAdhan)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
                .setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE)
                .setPriority(Notification.PRIORITY_HIGH)
        }
        builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("اقترب موعد صلاة $name")
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setAutoCancel(true)
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            builder.setContentIntent(PendingIntent.getActivity(
                context,
                NOTIFICATION_ID,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ))
        }
        try {
            manager.notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Permission may have been revoked since the delivery check.
        }
    }

    private fun manager(context: Context): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
