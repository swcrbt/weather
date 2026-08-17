package com.swcrbt.weather.widget.providers

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import com.swcrbt.weather.MainActivity
import com.swcrbt.weather.R
import com.swcrbt.weather.widget.WeatherHomeWidgetProvider
import com.swcrbt.weather.widget.WidgetBundle
import com.swcrbt.weather.widget.WidgetForecastDay
import com.swcrbt.weather.widget.WidgetIconHelper
import com.swcrbt.weather.widget.WidgetLunarDateFormatter
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import kotlin.math.roundToInt

/** 5x2 weather widget matching the detail layout with live cached data. */
class WidgetWeatherDetailProvider : WeatherHomeWidgetProvider() {

    override fun buildViews(context: Context, bundle: WidgetBundle): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_weather_detail)
        applyClockFormat(views, bundle.settings.timeformat, bundle.timeZoneId)
        bindCurrent(views, bundle)
        bindAqi(views, bundle)
        bindDate(views, bundle)
        bindPrecipitation(views, bundle.precipitationAlert)
        bindForecast(views, bundle.forecast)

        views.setTextViewText(R.id.widget_update_time, bundle.updateTime ?: "—")
        views.setOnClickPendingIntent(R.id.widget_refresh, createRefreshIntent(context))
        views.setOnClickPendingIntent(R.id.widget_weather_detail, createOpenAppIntent(context))
        return views
    }

    private fun bindCurrent(views: RemoteViews, bundle: WidgetBundle) {
        val current = bundle.current
        views.setTextViewText(R.id.widget_location, current?.location.orEmpty())
        views.setTextViewText(
            R.id.widget_temperature,
            temperatureWithDegreeOnly(current?.temperature ?: "--°"),
        )
        views.setTextViewText(R.id.widget_condition_description, current?.condition.orEmpty())
        views.setViewVisibility(R.id.widget_weather_icon, View.INVISIBLE)
        if (!current?.icon.isNullOrBlank()) {
            views.setViewVisibility(R.id.widget_weather_icon, View.VISIBLE)
            WidgetIconHelper.setIcon(views, R.id.widget_weather_icon, current?.icon)
        }
    }

    private fun bindAqi(views: RemoteViews, bundle: WidgetBundle) {
        val aqi = bundle.aqi
        if (aqi == null) {
            views.setViewVisibility(R.id.widget_aqi_background, View.GONE)
            return
        }
        views.setViewVisibility(R.id.widget_aqi_background, View.VISIBLE)
        views.setTextViewText(R.id.widget_aqi, "${aqi.value} ${aqi.level}")
        views.setViewVisibility(R.id.widget_aqi_icon, if (aqi.severity <= 1) View.VISIBLE else View.GONE)
        views.setTextColor(
            R.id.widget_aqi,
            if (aqi.severity == 0) Color.WHITE else Color.BLACK,
        )
        views.setInt(
            R.id.widget_aqi_background,
            "setBackgroundResource",
            resolveAqiBackground(aqi.severity),
        )
    }

    private fun bindDate(views: RemoteViews, bundle: WidgetBundle) {
        views.setTextViewText(R.id.widget_date, bundle.date.orEmpty())
        val lunar = bundle.dateEpochMillis?.let(WidgetLunarDateFormatter::format)
        views.setTextViewText(R.id.widget_lunar, lunar.orEmpty())
        views.setViewVisibility(R.id.widget_lunar, if (lunar == null) View.GONE else View.VISIBLE)
    }

    private fun bindPrecipitation(views: RemoteViews, alert: String?) {
        views.setTextViewText(R.id.widget_precipitation_alert, alert.orEmpty())
        views.setViewVisibility(
            R.id.widget_precipitation_alert,
            if (alert.isNullOrBlank()) View.INVISIBLE else View.VISIBLE,
        )
    }

    private fun bindForecast(views: RemoteViews, forecast: List<WidgetForecastDay>) {
        val labelIds =
            intArrayOf(
                R.id.widget_day1_label,
                R.id.widget_day2_label,
                R.id.widget_day3_label,
                R.id.widget_day4_label,
                R.id.widget_day5_label,
            )
        val iconIds =
            intArrayOf(
                R.id.widget_day1_icon,
                R.id.widget_day2_icon,
                R.id.widget_day3_icon,
                R.id.widget_day4_icon,
                R.id.widget_day5_icon,
            )
        val tempIds =
            intArrayOf(
                R.id.widget_day1_temp,
                R.id.widget_day2_temp,
                R.id.widget_day3_temp,
                R.id.widget_day4_temp,
                R.id.widget_day5_temp,
            )
        val columnIds =
            intArrayOf(
                R.id.widget_day1,
                R.id.widget_day2,
                R.id.widget_day3,
                R.id.widget_day4,
                R.id.widget_day5,
            )

        for (index in columnIds.indices) {
            val day = forecast.getOrNull(index)
            views.setViewVisibility(iconIds[index], View.INVISIBLE)
            views.setViewVisibility(columnIds[index], if (day == null) View.INVISIBLE else View.VISIBLE)
            if (day == null) continue
            views.setTextViewText(
                labelIds[index],
                styledPair(day.label, day.date, boldPrimary = true, separator = " "),
            )
            views.setTextViewText(
                tempIds[index],
                styledPair(
                    temperatureWithDegreeOnly(day.tempMin),
                    temperatureWithDegreeOnly(day.tempMax),
                    boldPrimary = false,
                    separator = "  ",
                ),
            )
            if (!day.icon.isNullOrBlank()) {
                views.setViewVisibility(iconIds[index], View.VISIBLE)
                WidgetIconHelper.setIcon(views, iconIds[index], day.icon)
            }
        }
    }

    private fun styledPair(
        primary: String,
        secondary: String,
        boldPrimary: Boolean,
        separator: String,
    ): CharSequence {
        if (secondary.isBlank()) return primary
        val secondaryStart = primary.length + separator.length
        return SpannableString("$primary$separator$secondary").apply {
            setSpan(
                ForegroundColorSpan(Color.WHITE),
                0,
                primary.length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
            if (boldPrimary) {
                setSpan(
                    StyleSpan(Typeface.BOLD),
                    0,
                    primary.length,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
            setSpan(
                ForegroundColorSpan(Color.argb(160, 255, 255, 255)),
                secondaryStart,
                length,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
            )
        }
    }

    private fun temperatureWithDegreeOnly(raw: String): String {
        if (raw.isBlank() || raw == "--°") return raw
        val number = Regex("""-?\d+(?:[.,]\d+)?""")
            .find(raw)
            ?.value
            ?.replace(',', '.')
            ?.toDoubleOrNull()
            ?: return raw
        return "${number.roundToInt()}°"
    }

    private fun applyClockFormat(
        views: RemoteViews,
        timeformat: String,
        timeZoneId: String?,
    ) {
        if (!timeZoneId.isNullOrBlank()) {
            views.setString(R.id.widget_time, "setTimeZone", timeZoneId)
        }
        views.setCharSequence(
            R.id.widget_time,
            "setFormat12Hour",
            if (timeformat == "12") "h:mm" else "HH:mm",
        )
        views.setCharSequence(
            R.id.widget_time,
            "setFormat24Hour",
            if (timeformat == "12") "h:mm a" else "HH:mm",
        )
    }

    private fun resolveAqiBackground(severity: Int): Int =
        when (severity) {
            0 -> R.drawable.aqi_good_background
            1 -> R.drawable.aqi_moderate_background
            2 -> R.drawable.aqi_unhealthy_sensitive_background
            3 -> R.drawable.aqi_unhealthy_sensitive_background
            4 -> R.drawable.aqi_moderate_background
            else -> R.drawable.aqi_good_background
        }

    private fun createOpenAppIntent(context: Context): PendingIntent =
        PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            pendingIntentFlags(),
        )

    private fun createRefreshIntent(context: Context): PendingIntent {
        val intent = Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
            action = "es.antonborri.home_widget.action.BACKGROUND"
            data = Uri.parse("weather://refresh")
        }
        return PendingIntent.getBroadcast(context, 1, intent, pendingIntentFlags())
    }

    private fun pendingIntentFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
}
