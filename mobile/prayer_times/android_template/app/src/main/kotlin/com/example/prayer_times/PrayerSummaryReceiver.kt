package com.example.prayer_times

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PrayerSummaryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action !=
            "com.example.prayertimes.action.REFRESH_PRAYER_SUMMARY"
        ) {
            return
        }
        PrayerSummaryNotificationManager.refresh(context)
    }
}
