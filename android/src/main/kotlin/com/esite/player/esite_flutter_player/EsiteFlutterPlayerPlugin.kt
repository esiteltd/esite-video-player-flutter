package com.esite.player.esite_flutter_player

import android.app.Activity
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class EsiteFlutterPlayerPlugin : FlutterPlugin, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var stateChannel: EventChannel
    private lateinit var drmChannel: EventChannel
    private lateinit var errorChannel: EventChannel

    private var activity: Activity? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "esite_flutter_player/methods")

        stateChannel = EventChannel(binding.binaryMessenger, "esite_flutter_player/events/state")
        drmChannel = EventChannel(binding.binaryMessenger, "esite_flutter_player/events/drm")
        errorChannel = EventChannel(binding.binaryMessenger, "esite_flutter_player/events/error")

        stateChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                PlayerEventBridge.stateSink = sink
            }
            override fun onCancel(args: Any?) {
                PlayerEventBridge.stateSink = null
            }
        })

        drmChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                PlayerEventBridge.drmSink = sink
            }
            override fun onCancel(args: Any?) {
                PlayerEventBridge.drmSink = null
            }
        })

        errorChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                PlayerEventBridge.errorSink = sink
            }
            override fun onCancel(args: Any?) {
                PlayerEventBridge.errorSink = null
            }
        })

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "launchPlayer" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as Map<String, Any>
                    launchPlayer(args)
                    result.success(null)
                }
                "initialize" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as Map<String, Any>
                    launchPlayer(args)
                    result.success(null)
                }
                "dispose" -> {
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchPlayer(args: Map<String, Any>) {
        val currentActivity = activity ?: return
        PlayerConfigHolder.config = args
        val intent = Intent(currentActivity, PlayerActivity::class.java)
        currentActivity.startActivity(intent)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        PlayerEventBridge.clear()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // Keep reference during config changes
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
