package com.example.wattwise

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "updateWidget") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val data = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                val preferences = getSharedPreferences(WIDGET_PREFERENCES, Context.MODE_PRIVATE)
                val todayKwh = (data["todayKwh"] as? Number)?.toDouble() ?: 0.0
                val yesterdayKwh = (data["yesterdayKwh"] as? Number)?.toDouble() ?: 0.0
                preferences.edit()
                    .putString("todayDate", data["todayDate"] as? String ?: "")
                    .putString("yesterdayDate", data["yesterdayDate"] as? String ?: "")
                    .putBoolean("todayAvailable", data["todayAvailable"] as? Boolean ?: false)
                    .putBoolean("yesterdayAvailable", data["yesterdayAvailable"] as? Boolean ?: false)
                    .putBoolean("comparisonAvailable", data["comparisonAvailable"] as? Boolean ?: false)
                    .putFloat("todayKwh", todayKwh.toFloat())
                    .putFloat("yesterdayKwh", yesterdayKwh.toFloat())
                    .putFloat("differenceKwh", (data["differenceKwh"] as? Number)?.toFloat() ?: 0f)
                    .putBoolean("differenceLower", data["differenceLower"] as? Boolean ?: false)
                    .putString("todayValue", data["todayValue"] as? String ?: "—")
                    .putString("yesterdayValue", data["yesterdayValue"] as? String ?: "—")
                    .putString("todayTotal", data["todayTotal"] as? String ?: "—")
                    .putString("yesterdayTotal", data["yesterdayTotal"] as? String ?: "—")
                    .putInt("todayProgress", data["todayProgress"] as? Int ?: 500)
                    .putInt("yesterdayProgress", data["yesterdayProgress"] as? Int ?: 500)
                    .apply()

                val manager = AppWidgetManager.getInstance(this)
                val provider = ComponentName(this, WattWiseWidgetProvider::class.java)
                manager.getAppWidgetIds(provider).forEach { appWidgetId ->
                    WattWiseWidgetProvider.updateAppWidget(this, manager, appWidgetId)
                }
                maybeNotifyUsageComparison(preferences)
                result.success(null)
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST &&
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        ) {
            maybeNotifyUsageComparison(
                getSharedPreferences(WIDGET_PREFERENCES, Context.MODE_PRIVATE)
            )
        }
    }

    private fun maybeNotifyUsageComparison(preferences: android.content.SharedPreferences) {
        val date = preferences.getString("todayDate", "") ?: return
        val yesterdayDate = preferences.getString("yesterdayDate", "") ?: return
        val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
        val todayKey = dateFormat.format(java.util.Date())
        val yesterdayKey = dateFormat.format(
            java.util.Calendar.getInstance().apply {
                add(java.util.Calendar.DAY_OF_YEAR, -1)
            }.time
        )
        if (date != todayKey || yesterdayDate != yesterdayKey ||
            !preferences.getBoolean("todayAvailable", false) ||
            !preferences.getBoolean("yesterdayAvailable", false)
        ) return

        val todayKwh = preferences.getFloat("todayKwh", 0f).toDouble()
        val yesterdayKwh = preferences.getFloat("yesterdayKwh", 0f).toDouble()
        if (yesterdayKwh <= 0 || todayKwh <= yesterdayKwh) return
        if (preferences.getString("usageAlertDate", "") == todayKey) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            if (!preferences.getBoolean("notificationPermissionRequested", false)) {
                preferences.edit().putBoolean("notificationPermissionRequested", true).apply()
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST
                )
            }
            return
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(
                NotificationChannel(
                    USAGE_NOTIFICATION_CHANNEL,
                    "Energy usage alerts",
                    NotificationManager.IMPORTANCE_DEFAULT
                )
            )
        }
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val title = "Today’s usage is beyond yesterday’s total"
        val body = "Today: ${preferences.getString("todayTotal", "—")} • Yesterday: ${preferences.getString("yesterdayTotal", "—")}"
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, USAGE_NOTIFICATION_CHANNEL)
        } else {
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.wattwise_notification_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
        notificationManager.notify(USAGE_NOTIFICATION_ID, notification)
        preferences.edit().putString("usageAlertDate", todayKey).apply()
    }

    companion object {
        const val WIDGET_CHANNEL = "com.example.wattwise/widget"
        const val WIDGET_PREFERENCES = "wattwise_widget"
        private const val NOTIFICATION_PERMISSION_REQUEST = 731
        private const val USAGE_NOTIFICATION_CHANNEL = "energy_usage_comparison"
        private const val USAGE_NOTIFICATION_ID = 731
    }
}
