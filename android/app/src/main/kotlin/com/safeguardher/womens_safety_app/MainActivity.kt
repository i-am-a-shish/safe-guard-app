package com.safeguardher.womens_safety_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // SmsPlugin is registered in GeneratedPluginRegistrant for background service.
        // Also add here for the main engine.
        try {
            flutterEngine.plugins.add(SmsPlugin())
        } catch (_: Exception) {
            // Already registered – safe to ignore
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "safeguard_her_service",
                "Safety Monitor",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "SafeGuardHer background safety monitoring service"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}
