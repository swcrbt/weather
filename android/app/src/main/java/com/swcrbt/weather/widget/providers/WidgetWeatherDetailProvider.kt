package com.swcrbt.weather.widget.providers

import android.content.Context
import android.widget.RemoteViews
import com.swcrbt.weather.R
import com.swcrbt.weather.widget.WeatherHomeWidgetProvider
import com.swcrbt.weather.widget.WidgetBundle

/**
 * 5x2 尺寸天气详情小部件提供者
 * 显示：时间、农历、温度、AQI、降水预警、5天预报
 */
class WidgetWeatherDetailProvider : WeatherHomeWidgetProvider() {

    override fun buildViews(context: Context, bundle: WidgetBundle): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_weather_detail)
        
        // 设置地点
        bundle.current?.let { current ->
            views.setTextViewText(R.id.widget_location, current.location)
            views.setTextViewText(R.id.widget_temperature, current.temperature)
            
            // 设置天气图标
            current.icon?.let { iconPath ->
                // 加载天气图标
                val iconRes = resolveWeatherIcon(context, iconPath)
                views.setImageViewResource(R.id.widget_weather_icon, iconRes)
            }
        }
        
        // 设置AQI（如果有）
        bundle.aqi?.let { aqi ->
            views.setTextViewText(R.id.widget_aqi, "${aqi.value} ${aqi.level}")
            views.setInt(R.id.widget_aqi_background, "setBackgroundResource", 
                resolveAqiBackground(aqi.value))
        }
        
        // 设置降水预警（如果有）
        bundle.precipitationAlert?.let { alert ->
            views.setTextViewText(R.id.widget_precipitation_alert, alert)
            views.setViewVisibility(R.id.widget_precipitation_alert, android.view.View.VISIBLE)
        } ?: run {
            views.setViewVisibility(R.id.widget_precipitation_alert, android.view.View.GONE)
        }
        
        // 设置更新时间
        views.setTextViewText(R.id.widget_update_time, bundle.updateTime ?: "--:--")
        
        // 设置5天预报
        bundle.forecast?.let { forecast ->
            for (i in 0 until minOf(5, forecast.size)) {
                val day = forecast[i]
                val dayIndex = i + 1
                
                // 设置日期标签
                val labelId = context.resources.getIdentifier(
                    "widget_day${dayIndex}_label", "id", context.packageName
                )
                views.setTextViewText(labelId, day.label)
                
                // 设置天气图标
                val iconId = context.resources.getIdentifier(
                    "widget_day${dayIndex}_icon", "id", context.packageName
                )
                val iconRes = resolveWeatherIcon(context, day.icon)
                views.setImageViewResource(iconId, iconRes)
                
                // 设置温度
                val tempId = context.resources.getIdentifier(
                    "widget_day${dayIndex}_temp", "id", context.packageName
                )
                views.setTextViewText(tempId, "${day.tempMin}° ${day.tempMax}°")
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
    
    /**
     * 根据天气图标路径解析对应的资源ID
     */
    private fun resolveWeatherIcon(context: Context, iconPath: String): Int {
        // 根据图标路径返回对应的 drawable 资源
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
    
    /**
     * 根据AQI值返回对应的背景资源
     */
    private fun resolveAqiBackground(aqi: Int): Int {
        return when {
            aqi <= 50 -> R.drawable.aqi_good_background
            aqi <= 100 -> R.drawable.aqi_moderate_background
            aqi <= 150 -> R.drawable.aqi_unhealthy_sensitive_background
            aqi <= 200 -> R.drawable.aqi_unhealthy_background
            aqi <= 300 -> R.drawable.aqi_very_unhealthy_background
            else -> R.drawable.aqi_hazardous_background
        }
    }
}
