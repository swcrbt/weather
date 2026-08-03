package com.swcrbt.weather.widget.providers

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import com.swcrbt.weather.MainActivity
import com.swcrbt.weather.R
import com.swcrbt.weather.widget.WeatherHomeWidgetProvider
import com.swcrbt.weather.widget.WidgetBundle
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver

/**
 * 5x2 尺寸天气详情小部件提供者
 * 显示：时间、农历、温度、AQI、降水预警、5天预报
 */
class WidgetWeatherDetailProvider : WeatherHomeWidgetProvider() {

    override fun buildViews(context: Context, bundle: WidgetBundle): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_weather_detail)

        bundle.current?.let { current ->
            views.setTextViewText(R.id.widget_location, current.location)
            views.setTextViewText(R.id.widget_temperature, current.temperature)

            current.icon?.let { iconPath ->
                val iconRes = resolveWeatherIcon(iconPath)
                views.setImageViewResource(R.id.widget_weather_icon, iconRes)
            }
        }

        // 设置刷新按钮点击事件
        val refreshIntent = createRefreshIntent(context)
        views.setOnClickPendingIntent(R.id.widget_refresh, refreshIntent)

        // 设置整体点击事件 - 打开应用
        val openAppIntent = createOpenAppIntent(context)
        views.setOnClickPendingIntent(R.id.widget_weather_detail, openAppIntent)

        return views
    }

    /** 根据天气图标路径解析对应的资源ID */
    private fun resolveWeatherIcon(iconPath: String): Int {
        return when {
            iconPath.contains("clear") -> R.drawable.sun
            iconPath.contains("cloud") && iconPath.contains("night") -> R.drawable.cloud_night
            iconPath.contains("cloud") -> R.drawable.cloud
            iconPath.contains("rain") -> R.drawable.rain
            iconPath.contains("snow") -> R.drawable.snow
            iconPath.contains("storm") -> R.drawable.storm
            else -> R.drawable.cloud
        }
    }

    private fun createOpenAppIntent(context: Context): PendingIntent {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            flags,
        )
    }

    private fun createRefreshIntent(context: Context): PendingIntent {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val intent = Intent(context, HomeWidgetBackgroundReceiver::class.java).apply {
            action = "es.antonborri.home_widget.action.BACKGROUND"
        }
        return PendingIntent.getBroadcast(context, 1, intent, flags)
    }
}
