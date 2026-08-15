package com.swcrbt.weather.widget

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import org.json.JSONArray
import org.json.JSONObject

data class WidgetCurrent(
    val location: String,
    val temperature: String,
    val condition: String,
    val icon: String?,
)

data class WidgetAqi(
    val value: Int,
    val level: String,
    val severity: Int,
)

data class WidgetForecastDay(
    val label: String,
    val date: String,
    val icon: String?,
    val tempMin: String,
    val tempMax: String,
)

data class WidgetSettings(
    val timeformat: String,
    val themeMode: String,
    val backgroundColorLight: String?,
    val backgroundColorDark: String?,
    val textColorLight: String?,
    val textColorDark: String?,
    val useDarkPalette: Boolean,
)

data class WidgetBundle(
    val current: WidgetCurrent?,
    val aqi: WidgetAqi?,
    val precipitationAlert: String?,
    val date: String?,
    val calendarDate: String?,
    val timeZoneId: String?,
    val dateEpochMillis: Long?,
    val updateTime: String?,
    val forecast: List<WidgetForecastDay>,
    val settings: WidgetSettings,
) {
    val hasData: Boolean get() = current != null
}

object WidgetDataBridge {

    /** Loads widget weather payload and appearance settings from HomeWidget prefs. */
    fun load(
        context: Context,
        prefs: SharedPreferences,
        configuration: Configuration = context.resources.configuration,
    ): WidgetBundle {
        val settings = readSettings(context, prefs, configuration)
        val json = prefs.getString("widget_bundle", null) ?: return emptyBundle(settings)

        return try {
            val root = JSONObject(json)
            WidgetBundle(
                current = parseCurrent(root.optJSONObject("current")),
                aqi = parseAqi(root.optJSONObject("aqi")),
                precipitationAlert = root.optNonBlankString("precipitationAlert"),
                date = root.optNonBlankString("date"),
                calendarDate = root.optNonBlankString("calendarDate"),
                timeZoneId = root.optNonBlankString("timeZoneId"),
                dateEpochMillis = root.optLongOrNull("dateEpochMillis"),
                updateTime = root.optNonBlankString("updateTime"),
                forecast = parseForecast(root.optJSONArray("forecast")),
                settings = settings,
            )
        } catch (_: Exception) {
            emptyBundle(settings)
        }
    }

    private fun emptyBundle(settings: WidgetSettings) =
        WidgetBundle(
            current = null,
            aqi = null,
            precipitationAlert = null,
            date = null,
            calendarDate = null,
            timeZoneId = null,
            dateEpochMillis = null,
            updateTime = null,
            forecast = emptyList(),
            settings = settings,
        )

    private fun readSettings(
        context: Context,
        prefs: SharedPreferences,
        configuration: Configuration,
    ): WidgetSettings {
        // Theme mode comes from Flutter; palette slot follows device when mode is `system`.
        val themeMode = prefs.getString("widget_theme_mode", "system") ?: "system"
        return WidgetSettings(
            timeformat = prefs.getString("timeformat", "24") ?: "24",
            themeMode = themeMode,
            backgroundColorLight = prefs.getString("background_color_light", null),
            backgroundColorDark = prefs.getString("background_color_dark", null),
            textColorLight = prefs.getString("text_color_light", null),
            textColorDark = prefs.getString("text_color_dark", null),
            useDarkPalette = WidgetPalette.useDarkPalette(themeMode, configuration),
        )
    }

    private fun parseCurrent(currentObj: JSONObject?): WidgetCurrent? {
        if (currentObj == null) return null
        return WidgetCurrent(
            location = currentObj.optString("location", ""),
            temperature = currentObj.optString("temperature", "--°"),
            condition = currentObj.optString("condition", ""),
            icon = currentObj.optNonBlankString("icon"),
        )
    }

    private fun parseAqi(aqiObj: JSONObject?): WidgetAqi? {
        if (aqiObj == null || !aqiObj.has("value")) return null
        return WidgetAqi(
            value = aqiObj.optInt("value"),
            level = aqiObj.optString("level", ""),
            severity = aqiObj.optInt("severity", 0).coerceIn(0, 5),
        )
    }

    private fun parseForecast(forecastArray: JSONArray?): List<WidgetForecastDay> {
        if (forecastArray == null) return emptyList()
        return buildList {
            for (index in 0 until minOf(5, forecastArray.length())) {
                val day = forecastArray.optJSONObject(index) ?: continue
                add(
                    WidgetForecastDay(
                        label = day.optString("label", ""),
                        date = day.optString("date", ""),
                        icon = day.optNonBlankString("icon"),
                        tempMin = day.optString("tempMin", "--°"),
                        tempMax = day.optString("tempMax", "--°"),
                    ),
                )
            }
        }
    }

    private fun JSONObject.optLongOrNull(key: String): Long? =
        if (!has(key) || isNull(key)) null else optLong(key)

    private fun JSONObject.optNonBlankString(key: String): String? =
        if (!has(key) || isNull(key)) null else optString(key).takeIf(String::isNotBlank)
}
