package com.example.prayer_times

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

class AdhanPlaybackService : Service() {
    private var player: MediaPlayer? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopPlayback()
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val prayerId =
            intent?.getStringExtra(AdhanAlarmScheduler.EXTRA_PRAYER_ID) ?: run {
                stopSelf(startId)
                return START_NOT_STICKY
            }
        stopPlayer()
        startAsForeground(prayerId)
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putString(KEY_CURRENT_PRAYER, prayerId)
            .apply()

        try {
            val audioPlayer = MediaPlayer()
            player = audioPlayer
            audioPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            audioPlayer.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            audioPlayer.setDataSource(
                this,
                Uri.parse("android.resource://$packageName/${R.raw.adhan}"),
            )
            audioPlayer.setOnPreparedListener { mediaPlayer ->
                try {
                    mediaPlayer.start()
                } catch (error: Exception) {
                    Log.e(TAG, "Adhan playback could not start.", error)
                    stopPlayback()
                }
            }
            audioPlayer.setOnCompletionListener { stopPlayback() }
            audioPlayer.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "Adhan playback failed: $what/$extra")
                stopPlayback()
                true
            }
            audioPlayer.prepareAsync()
        } catch (error: Exception) {
            Log.e(TAG, "Adhan audio resource could not be opened.", error)
            stopPlayback()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopPlayer()
        clearCurrentPrayer()
        removeForegroundNotification()
        super.onDestroy()
    }

    private fun startAsForeground(prayerId: String) {
        val label = when (prayerId) {
            "fajrSecond" -> "الفجر"
            "dhuhr" -> "الظهر"
            "asr" -> "العصر"
            "maghrib" -> "المغرب"
            "isha" -> "العشاء"
            else -> "الصلاة"
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                7421,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val stopIntent = PendingIntent.getService(
            this,
            7422,
            Intent(this, AdhanPlaybackService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("مواقيت الصلاة")
            .setContentText("يُرفع أذان $label")
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .setSound(null)
            .addAction(android.R.drawable.ic_media_pause, "إيقاف الأذان", stopIntent)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notification.flags = notification.flags or Notification.FLAG_NO_CLEAR
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "تشغيل الأذان",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "إشعار صامت أثناء تشغيل تسجيل الأذان"
            setSound(null, null)
            enableVibration(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun stopPlayback() {
        stopPlayer()
        clearCurrentPrayer()
        removeForegroundNotification()
        stopSelf()
    }

    private fun removeForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun stopPlayer() {
        val activePlayer = player ?: return
        player = null
        try {
            if (activePlayer.isPlaying) activePlayer.stop()
        } catch (_: IllegalStateException) {
            // Player may still be preparing when a prayer is muted.
        }
        try {
            activePlayer.reset()
            activePlayer.release()
        } catch (_: IllegalStateException) {
            // The player may already have released its native resources.
        }
    }

    private fun clearCurrentPrayer() {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .remove(KEY_CURRENT_PRAYER)
            .apply()
    }

    companion object {
        const val ACTION_PLAY = "com.example.prayertimes.action.PLAY_ADHAN"
        const val ACTION_STOP = "com.example.prayertimes.action.STOP_ADHAN"
        const val PREFS_NAME = "PrayerAdhanPlayback"
        const val KEY_CURRENT_PRAYER = "current_prayer"
        private const val TAG = "PrayerTimesAdhan"
        private const val CHANNEL_ID = "prayer_times_adhan_playback"
        private const val NOTIFICATION_ID = 5319
    }
}
