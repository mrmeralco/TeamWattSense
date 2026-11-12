package com.example.wattwise

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
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
                preferences.edit()
                    .putString("todayDate", data["todayDate"] as? String ?: "")
                    .putString("yesterdayDate", data["yesterdayDate"] as? String ?: "")
                    .putBoolean("todayAvailable", data["todayAvailable"] as? Boolean ?: false)
                    .putBoolean("yesterdayAvailable", data["yesterdayAvailable"] as? Boolean ?: false)
                    .putBoolean("differenceLower", data["differenceLower"] as? Boolean ?: false)
                    .putString("todayTotal", data["todayTotal"] as? String ?: "—")
                    .putString("yesterdayTotal", data["yesterdayTotal"] as? String ?: "—")
                    .putString("difference", data["difference"] as? String ?: "Comparison unavailable")
                    .putInt("todayProgress", data["todayProgress"] as? Int ?: 500)
                    .putInt("yesterdayProgress", data["yesterdayProgress"] as? Int ?: 500)
                    .apply()

                val manager = AppWidgetManager.getInstance(this)
                val provider = ComponentName(this, WattWiseWidgetProvider::class.java)
                manager.getAppWidgetIds(provider).forEach { appWidgetId ->
                    WattWiseWidgetProvider.updateAppWidget(this, manager, appWidgetId)
                }
                result.success(null)
            }
    }

    companion object {
        const val WIDGET_CHANNEL = "com.example.wattwise/widget"
        const val WIDGET_PREFERENCES = "wattwise_widget"
    }
}
