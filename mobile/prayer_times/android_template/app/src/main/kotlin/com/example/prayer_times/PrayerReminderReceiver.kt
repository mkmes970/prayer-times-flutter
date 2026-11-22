package com.example.prayer_times

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PrayerReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != PrayerReminderScheduler.ACTION) return
        PrayerReminderScheduler.onAlarm(context, intent)
    }
}
