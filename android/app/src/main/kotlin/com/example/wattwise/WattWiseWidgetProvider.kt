package com.example.wattwise

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class WattWiseWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val preferences = context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE
            )
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
            val isExpanded = minWidth >= 220
            val layout = if (isExpanded) R.layout.wattwise_widget_large else R.layout.wattwise_widget_small
            val views = RemoteViews(context.packageName, layout)
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val todayKey = dateFormat.format(Date())
            val yesterdayCalendar = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, -1)
            }
            val yesterdayKey = dateFormat.format(yesterdayCalendar.time)
            val todayAvailable = preferences.getBoolean("todayAvailable", false) &&
                preferences.getString("todayDate", "") == todayKey
            val yesterdayAvailable = preferences.getBoolean("yesterdayAvailable", false) &&
                preferences.getString("yesterdayDate", "") == yesterdayKey
            val todayTotal = if (todayAvailable) preferences.getString("todayTotal", "—") else "—"
            val yesterdayTotal = if (yesterdayAvailable) preferences.getString("yesterdayTotal", "—") else "—"
            val difference = if (todayAvailable && yesterdayAvailable) {
                preferences.getString("difference", "Comparison unavailable")
            } else {
                "Comparison unavailable"
            }
            val differenceLower = preferences.getBoolean("differenceLower", false)

            views.setTextViewText(R.id.widget_today_total, todayTotal)
            views.setTextViewText(R.id.widget_yesterday_total, yesterdayTotal)
            views.setTextViewText(
                R.id.widget_today_status,
                if (todayAvailable) "TODAY" else "TODAY • NO LOG"
            )
            views.setTextViewText(
                R.id.widget_yesterday_status,
                if (yesterdayAvailable) "YESTERDAY" else "YESTERDAY • NO LOG"
            )
            if (isExpanded) {
                views.setTextViewText(R.id.widget_difference, "Difference: $difference")
                views.setTextColor(
                    R.id.widget_difference,
                    context.getColor(if (differenceLower) R.color.widget_mint else R.color.widget_neutral)
                )
                views.setProgressBar(
                    R.id.widget_today_progress,
                    1000,
                    if (todayAvailable && yesterdayAvailable) preferences.getInt("todayProgress", 500) else 500,
                    false
                )
                views.setProgressBar(
                    R.id.widget_yesterday_progress,
                    1000,
                    if (todayAvailable && yesterdayAvailable) preferences.getInt("yesterdayProgress", 500) else 500,
                    false
                )
                views.setTextViewText(
                    R.id.widget_usage_note,
                    "Based on your saved appliance usage"
                )
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
