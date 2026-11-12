package com.example.wattwise

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.SizeF
import android.util.TypedValue
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

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
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
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 130)
            val smallViews = RemoteViews(context.packageName, R.layout.wattwise_widget_small)
            val mediumViews = RemoteViews(context.packageName, R.layout.wattwise_widget_large)
            bindViews(context, smallViews, preferences, false)
            bindViews(context, mediumViews, preferences, true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val sizeVariants = RemoteViews(
                    mapOf(
                        SizeF(130f, 130f) to smallViews,
                        SizeF(250f, 140f) to mediumViews
                    )
                )
                appWidgetManager.updateAppWidget(appWidgetId, sizeVariants)
            } else {
                appWidgetManager.updateAppWidget(
                    appWidgetId,
                    if (minWidth >= 220) mediumViews else smallViews
                )
            }
        }

        private fun bindViews(
            context: Context,
            views: RemoteViews,
            preferences: android.content.SharedPreferences,
            medium: Boolean
        ) {
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
            val comparisonAvailable = todayAvailable && yesterdayAvailable
            val todayValue = if (todayAvailable) preferences.getString("todayValue", "—") else "—"
            val yesterdayValue = if (yesterdayAvailable) preferences.getString("yesterdayValue", "—") else "—"
            val todayTotal = if (todayAvailable) preferences.getString("todayTotal", "—") else "—"
            val yesterdayTotal = if (yesterdayAvailable) preferences.getString("yesterdayTotal", "—") else "—"
            val difference = preferences.getFloat("differenceKwh", 0f)
            val differenceLabel = when {
                !comparisonAvailable -> "Comparison unavailable"
                difference < 0 -> String.format(Locale.US, "%.1f kWh (Lower) ↓", difference)
                difference > 0 -> String.format(Locale.US, "+%.1f kWh (Higher) ↑", difference)
                else -> "0.0 kWh (Same)"
            }
            val todayProgress = if (comparisonAvailable || todayAvailable) {
                preferences.getInt("todayProgress", 500)
            } else {
                0
            }
            val yesterdayProgress = if (comparisonAvailable) {
                preferences.getInt("yesterdayProgress", 500)
            } else {
                0
            }

            if (medium) {
                views.setTextViewText(
                    R.id.widget_today_total,
                    if (todayAvailable) todayTotal else "—"
                )
                views.setTextViewText(
                    R.id.widget_yesterday_total,
                    if (yesterdayAvailable) yesterdayTotal else "—"
                )
                views.setTextViewText(R.id.widget_difference, "Difference: $differenceLabel")
                views.setProgressBar(R.id.widget_today_progress, 1000, todayProgress, false)
                views.setProgressBar(R.id.widget_yesterday_progress, 1000, yesterdayProgress, false)
            } else {
                views.setTextViewText(R.id.widget_today_value, todayValue)
                views.setTextViewText(
                    R.id.widget_yesterday_footer,
                    if (yesterdayAvailable) yesterdayValue else "—"
                )
                views.setTextViewText(
                    R.id.widget_today_footer,
                    if (todayAvailable) todayValue else "—"
                )
                views.setTextViewText(R.id.widget_difference, differenceLabel)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val todayHeight = (8f + 48f * todayProgress / 1000f).coerceAtMost(56f)
                    val yesterdayHeight = (8f + 48f * yesterdayProgress / 1000f).coerceAtMost(56f)
                    views.setViewVisibility(
                        R.id.widget_today_bar_fill,
                        if (comparisonAvailable) android.view.View.VISIBLE else android.view.View.GONE
                    )
                    views.setViewVisibility(
                        R.id.widget_yesterday_bar_fill,
                        if (comparisonAvailable) android.view.View.VISIBLE else android.view.View.GONE
                    )
                    views.setViewLayoutHeight(
                        R.id.widget_today_bar_fill,
                        todayHeight,
                        TypedValue.COMPLEX_UNIT_DIP
                    )
                    views.setViewLayoutHeight(
                        R.id.widget_yesterday_bar_fill,
                        yesterdayHeight,
                        TypedValue.COMPLEX_UNIT_DIP
                    )
                }
            }

            views.setTextColor(
                R.id.widget_difference,
                context.getColor(
                    when {
                        !comparisonAvailable -> R.color.widget_neutral
                        difference < 0 -> R.color.widget_mint
                        else -> R.color.widget_alert
                    }
                )
            )
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
        }
    }
}
