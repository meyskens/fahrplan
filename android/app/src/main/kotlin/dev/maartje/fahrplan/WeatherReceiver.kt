package dev.maartje.fahrplan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

class WeatherReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_GENERIC_WEATHER = "nodomain.freeyourgadget.gadgetbridge.ACTION_GENERIC_WEATHER"
        const val EXTRA_WEATHER_JSON = "WeatherJson"
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val TAG = "WeatherReceiver"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent != null && ACTION_GENERIC_WEATHER == intent.action) {
            val weatherJson = intent.getStringExtra(EXTRA_WEATHER_JSON)
            if (weatherJson != null) {
                saveWeatherData(context, weatherJson)
            } else {
                Log.e(TAG, "Weather data is missing in the intent")
            }
        }
    }

    private fun saveWeatherData(context: Context?, jsonData: String) {
        if (context != null) {
            val sharedPreferences: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val editor = sharedPreferences.edit()
            editor.putString("flutter." + EXTRA_WEATHER_JSON, jsonData)
            editor.apply()

            Log.d(TAG, "Weather data saved")
            // log shared preferences data
            val allEntries: Map<String, *> = sharedPreferences.all
            for ((key, value) in allEntries) {
                Log.d(TAG, "$key: $value")
            }
        } else {
            Log.e(TAG, "Context is null, cannot save weather data")
        }
    }
}