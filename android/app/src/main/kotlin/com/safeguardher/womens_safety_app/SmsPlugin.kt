package com.safeguardher.womens_safety_app

import android.content.Context
import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * SmsPlugin - Native Android SMS sender using SmsManager.
 * Registered in GeneratedPluginRegistrant so it works in ALL Flutter engines,
 * including the flutter_background_service isolate.
 *
 * Channel: com.safeguardher.womens_safety_app/sms
 * Methods:
 *   - sendSms(phoneNumber: String, message: String) -> bool
 */
class SmsPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    companion object {
        const val CHANNEL_NAME = "com.safeguardher.womens_safety_app/sms"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "sendSms" -> {
                val phoneNumber = call.argument<String>("phoneNumber")
                val message = call.argument<String>("message")

                if (phoneNumber.isNullOrBlank() || message.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "phoneNumber and message are required", null)
                    return
                }

                try {
                    sendSmsInternal(phoneNumber.trim(), message)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SMS_FAILED", e.message ?: "Failed to send SMS", e.toString())
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun sendSmsInternal(phoneNumber: String, message: String) {
        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+ : use applicationContext.getSystemService
            context.getSystemService(SmsManager::class.java)
                ?: throw Exception("SmsManager not available on this device")
        } else {
            // Android < 12 : use getDefault()
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }

        val parts = smsManager.divideMessage(message)
        if (parts.size == 1) {
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
        } else {
            // Long message: send as multipart SMS
            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
        }
    }
}
