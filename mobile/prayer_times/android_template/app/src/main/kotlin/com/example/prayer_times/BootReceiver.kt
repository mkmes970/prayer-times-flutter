package com.example.prayer_times

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.AlarmManager

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        when (action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                AdhanAlarmScheduler.scheduleNext(context)
                PrayerSummaryNotificationManager.refresh(context)
                maybeLaunchApp(context)
            }
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> {
                AdhanAlarmScheduler.scheduleNext(context)
                PrayerSummaryNotificationManager.refresh(context)
            }
        }
    }

    private fun maybeLaunchApp(context: Context) {
        val enabled = context
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.autoStartEnabled", false)
        if (!enabled) return

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: return
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(launchIntent)
        } catch (error: Exception) {
            // Android and some TV vendors block starting an Activity from boot.
            Log.w("PrayerTimesBoot", "System blocked automatic app launch.", error)
        }
    }
}
