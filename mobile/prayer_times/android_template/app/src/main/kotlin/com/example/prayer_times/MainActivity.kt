package com.example.prayer_times

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Settings
import java.util.TimeZone
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.prayertimes/device"
    private var pendingAdhanRequest: PendingAdhanRequest? = null
    private var pendingPrayerSummaryPermissionResult: MethodChannel.Result? = null

    private data class PendingAdhanRequest(
        val enabled: Boolean,
        val prayerIds: Set<String>,
        val events: JSONArray,
        val requestPermissions: Boolean,
        val result: MethodChannel.Result,
        var notificationPermissionRequested: Boolean = false,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceTimeZoneId" -> result.success(TimeZone.getDefault().id)
                    "setAutoStartEnabled" -> {
                        val enabled = call.arguments as? Boolean
                        if (enabled == null) {
                            result.error("invalid_argument", "Expected a boolean value.", null)
                            return@setMethodCallHandler
                        }
                        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            .edit()
                            .putBoolean("flutter.autoStartEnabled", enabled)
                            .apply()
                        result.success(null)
                    }
                    "syncAdhanSchedule" -> handleAdhanSchedule(call.arguments, result)
                    "requestPrayerSummaryPermission" ->
                        requestPrayerSummaryPermission(result)
                    "arePrayerSummaryNotificationsAllowed" ->
                        result.success(
                            PrayerSummaryNotificationManager.notificationsAllowed(this),
                        )
                    "syncPrayerSummary" -> handlePrayerSummary(call.arguments, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestPrayerSummaryPermission(result: MethodChannel.Result) {
        if (pendingPrayerSummaryPermissionResult != null || pendingAdhanRequest != null) {
            result.error(
                "request_in_progress",
                "Another notification permission request is already open.",
                null,
            )
            return
        }
        if (
            Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingPrayerSummaryPermissionResult = result
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_PRAYER_SUMMARY_PERMISSION,
            )
            return
        }
        result.success(PrayerSummaryNotificationManager.notificationsAllowed(this))
    }

    private fun handlePrayerSummary(arguments: Any?, result: MethodChannel.Result) {
        val payloadJson = arguments as? String
        if (payloadJson == null) {
            result.error("invalid_argument", "Expected prayer summary data.", null)
            return
        }
        try {
            val json = JSONObject(payloadJson)
            result.success(PrayerSummaryNotificationManager.sync(this, json))
        } catch (error: Exception) {
            result.error(
                "prayer_summary_failed",
                "Could not update prayer summary: ${error.message}",
                null,
            )
        }
    }

    private fun handleAdhanSchedule(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *>
        if (values == null) {
            result.error("invalid_argument", "Expected an adhan settings object.", null)
            return
        }
        val enabled = values["enabled"] as? Boolean ?: false
        val requestPermissions = values["requestPermissions"] as? Boolean ?: false
        val prayerIds = (values["activePrayerIds"] as? List<*>)
            ?.mapNotNull { it as? String }
            ?.toSet()
            ?: emptySet()
        val events = JSONArray()
        (values["events"] as? List<*>)
            ?.filterIsInstance<Map<*, *>>()
            ?.forEach { event ->
                val json = JSONObject()
                event.forEach { (key, value) ->
                    if (key is String && value != null) json.put(key, value)
                }
                events.put(json)
            }

        val request = PendingAdhanRequest(
            enabled = enabled,
            prayerIds = prayerIds,
            events = events,
            requestPermissions = requestPermissions,
            result = result,
        )
        if (!enabled) {
            persistAdhanSchedule(request)
            return
        }
        if (pendingAdhanRequest != null) {
            result.error("request_in_progress", "An adhan permission request is already open.", null)
            return
        }
        pendingAdhanRequest = request
        requestNotificationPermissionOrContinue(request)
    }

    private fun requestNotificationPermissionOrContinue(request: PendingAdhanRequest) {
        if (
            request.requestPermissions &&
            Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            request.notificationPermissionRequested = true
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_NOTIFICATION_PERMISSION,
            )
            return
        }
        requestExactAlarmPermissionOrSave(request)
    }

    private fun requestExactAlarmPermissionOrSave(request: PendingAdhanRequest) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            if (!request.requestPermissions) {
                failAdhanRequest(
                    "exact_alarm_permission_required",
                    "اسمح للتطبيق بالتنبيهات الدقيقة حتى يعمل الأذان في وقته.",
                )
                return
            }
            try {
                val settingsIntent = Intent(
                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                    Uri.parse("package:$packageName"),
                )
                startActivityForResult(settingsIntent, REQUEST_EXACT_ALARM_PERMISSION)
            } catch (error: Exception) {
                failAdhanRequest(
                    "exact_alarm_permission_required",
                    "تعذر فتح إعداد صلاحية التنبيهات الدقيقة: ${error.message}",
                )
            }
            return
        }
        persistAdhanSchedule(request)
    }

    private fun persistAdhanSchedule(request: PendingAdhanRequest) {
        try {
            AdhanAlarmScheduler.saveAndSchedule(
                this,
                request.enabled,
                request.prayerIds,
                request.events,
            )
            if (pendingAdhanRequest === request) pendingAdhanRequest = null
            request.result.success(null)
        } catch (error: Exception) {
            if (pendingAdhanRequest === request) pendingAdhanRequest = null
            request.result.error(
                "schedule_failed",
                "تعذر ضبط منبه الأذان: ${error.message ?: error.javaClass.simpleName}",
                null,
            )
        }
    }

    private fun failAdhanRequest(code: String, message: String) {
        val request = pendingAdhanRequest ?: return
        pendingAdhanRequest = null
        request.result.error(code, message, null)
    }

    @Deprecated("Deprecated in Android, kept for exact-alarm settings callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_EXACT_ALARM_PERMISSION) return
        val request = pendingAdhanRequest ?: return
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            alarmManager.canScheduleExactAlarms()
        ) {
            persistAdhanSchedule(request)
        } else {
            failAdhanRequest(
                "exact_alarm_permission_required",
                "لم تُمنح صلاحية التنبيهات الدقيقة؛ لم يتم جدولة الأذان.",
            )
        }
    }

    @Deprecated("Deprecated in Android, kept for the notification permission callback.")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_PRAYER_SUMMARY_PERMISSION) {
            val pending = pendingPrayerSummaryPermissionResult
            pendingPrayerSummaryPermissionResult = null
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            pending?.success(granted && PrayerSummaryNotificationManager.notificationsAllowed(this))
            return
        }
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) return
        val request = pendingAdhanRequest ?: return
        requestExactAlarmPermissionOrSave(request)
    }

    companion object {
        private const val REQUEST_NOTIFICATION_PERMISSION = 6401
        private const val REQUEST_EXACT_ALARM_PERMISSION = 6402
        private const val REQUEST_PRAYER_SUMMARY_PERMISSION = 6403
    }
}
