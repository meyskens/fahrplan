package dev.maartje.fahrplan

import android.app.Application

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        registerActivityLifecycleCallbacks(LifecycleDetector.activityLifecycleCallbacks)
    }
}