package com.swcrbt.weather.widget.providers

import android.content.Context
import android.widget.RemoteViews
import com.swcrbt.weather.widget.WeatherHomeWidgetProvider
import com.swcrbt.weather.widget.WidgetBinders
import com.swcrbt.weather.widget.WidgetBundle

/** Thin [WeatherHomeWidgetProvider] subclasses mapped to [WidgetBinders]. */
class WidgetMaterialYouForecast1x1Provider : WeatherHomeWidgetProvider() {
    override fun buildViews(context: Context, bundle: WidgetBundle): RemoteViews =
        WidgetBinders.materialYouForecast1x1(context, bundle)
}

class WidgetMaterialYouCurrentProvider : WeatherHomeWidgetProvider() {
    override fun buildViews(context: Context, bundle: WidgetBundle): RemoteViews =
        WidgetBinders.materialYouCurrent(context, bundle)
}

class WidgetClockDayHorizontalProvider : WeatherHomeWidgetProvider() {
    override fun buildViews(context: Context, bundle: WidgetBundle): RemoteViews =
        WidgetBinders.clockHorizontal(context, bundle)
}
