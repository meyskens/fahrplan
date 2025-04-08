package dev.maartje.fahrplan

import android.os.Bundle
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import dev.maartje.fahrplan.cpp.Cpp

class MainActivity: FlutterActivity() {
    private val CHANNEL = "dev.maartje.fahrplan/channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Notifications.createNotificationChannels(this)
    }

     override fun onDestroy() {
        super.onDestroy()
        BackgroundService.stopService(this@MainActivity, null)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Cpp.init()

        GeneratedPluginRegistrant.registerWith(flutterEngine);
         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "decodeLC3") {
                val data = call.argument<ByteArray>("data")
                if (data != null) {
                    val decodedData = Cpp.decodeLC3(data)
                    result.success(decodedData)
                } else {
                    result.error("INVALID_ARGUMENT", "Data is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(binaryMessenger, "dev.maartje.fahrplan/background_service").apply {
            setMethodCallHandler { method, result ->
                if (method.method == "startService") {
                    val callbackRawHandle = method.arguments as Long
                    BackgroundService.startService(this@MainActivity, callbackRawHandle)
                    result.success(null)
                } else if (method.method == "stopService") {
                    println("inside kotlin hello2")
                    val callbackRawHandle = method.arguments as Long
                    BackgroundService.stopService(this@MainActivity, callbackRawHandle)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(binaryMessenger, "dev.maartje.fahrplan/app_retain").apply {
            setMethodCallHandler { method, result ->
                if (method.method == "sendToBackground") {
                    moveTaskToBack(true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

}
