package com.swcrbt.weather

import android.app.Application
import android.content.ComponentCallbacks
import android.content.pm.ApplicationInfo
import android.content.res.Configuration
import android.util.Log
import com.swcrbt.weather.widget.WidgetThemeRefreshCoordinator
import dev.fluttercommunity.workmanager.LoggingDebugHandler
import dev.fluttercommunity.workmanager.WorkmanagerDebug

class WeatherApplication : Application() {
    /** Refreshes home widgets when system theme or locale changes. */
    private val configurationCallbacks =
        object : ComponentCallbacks {
            override fun onConfigurationChanged(newConfig: Configuration) {
                WidgetThemeRefreshCoordinator.scheduleRefresh(this@WeatherApplication)
            }

            override fun onLowMemory() {}
        }

    override fun onCreate() {
        super.onCreate()
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            WorkmanagerDebug.setCurrent(LoggingDebugHandler())
            Log.i("WeatherApplication", "Workmanager debug logging enabled")
        }
        registerComponentCallbacks(configurationCallbacks)
    }
}
