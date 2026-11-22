package com.example.prayer_times

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != AdhanAlarmScheduler.ACTION_ADHAN_ALARM) return

        val prayerId = intent.getStringExtra(AdhanAlarmScheduler.EXTRA_PRAYER_ID) ?: return
        val version = intent.getLongExtra(AdhanAlarmScheduler.EXTRA_VERSION, -1L)
        if (!AdhanAlarmScheduler.isCurrentSchedule(context, version, prayerId)) {
            AdhanAlarmScheduler.scheduleNext(context)
            return
        }

        val playbackIntent = Intent(context, AdhanPlaybackService::class.java).apply {
            action = AdhanPlaybackService.ACTION_PLAY
            putExtra(AdhanAlarmScheduler.EXTRA_PRAYER_ID, prayerId)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(playbackIntent)
            } else {
                context.startService(playbackIntent)
            }
        } catch (error: Exception) {
            Log.e("PrayerTimesAdhan", "Could not start background adhan playback.", error)
        } finally {
            AdhanAlarmScheduler.scheduleNext(context)
        }
    }
}
