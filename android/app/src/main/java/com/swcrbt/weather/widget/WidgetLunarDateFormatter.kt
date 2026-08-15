package com.swcrbt.weather.widget

import android.icu.util.Calendar
import android.icu.util.ChineseCalendar
import android.os.Build
import java.util.Date

/** Formats an exact Chinese lunar month/day using Android ICU when available. */
object WidgetLunarDateFormatter {
    private val monthNames =
        arrayOf("正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月")
    private val dayNames =
        arrayOf(
            "初一",
            "初二",
            "初三",
            "初四",
            "初五",
            "初六",
            "初七",
            "初八",
            "初九",
            "初十",
            "十一",
            "十二",
            "十三",
            "十四",
            "十五",
            "十六",
            "十七",
            "十八",
            "十九",
            "二十",
            "廿一",
            "廿二",
            "廿三",
            "廿四",
            "廿五",
            "廿六",
            "廿七",
            "廿八",
            "廿九",
            "三十",
        )

    fun format(epochMillis: Long = System.currentTimeMillis()): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return null
        return try {
            val calendar = ChineseCalendar(Date(epochMillis))
            val month = calendar.get(Calendar.MONTH)
            val day = calendar.get(Calendar.DAY_OF_MONTH)
            if (month !in monthNames.indices || day !in 1..dayNames.size) return null
            val leap = calendar.get(Calendar.IS_LEAP_MONTH) == 1
            buildString {
                if (leap) append('闰')
                append(monthNames[month])
                append(dayNames[day - 1])
            }
        } catch (_: Exception) {
            null
        }
    }
}
