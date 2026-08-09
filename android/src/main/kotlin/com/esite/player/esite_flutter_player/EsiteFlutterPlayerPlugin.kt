package com.esite.player.esite_flutter_player

import android.app.Activity
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
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
                "launchPlayer", "initialize" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as Map<String, Any>
                    launchPlayer(args)
                    result.success(null)
                }
                "dispose" -> {
                    PlayerActivity.current?.commandClose()
                    result.success(null)
                }
                else -> handlePlayerCommand(call, result)
            }
        }
    }

    /**
     * Transport commands are routed to the live [PlayerActivity]. When no
     * player is on screen the call fails with NO_PLAYER rather than silently
     * doing nothing, so Dart can tell "ignored" from "applied".
     */
    private fun handlePlayerCommand(call: MethodCall, result: MethodChannel.Result) {
        val player = PlayerActivity.current
        if (player == null) {
            result.error("NO_PLAYER", "No player is currently active", null)
            return
        }

        when (call.method) {
            "play" -> { player.commandPlay(); result.success(null) }
            "pause" -> { player.commandPause(); result.success(null) }
            "seekTo" -> {
                val positionMs = (call.argument<Number>("positionMs") ?: 0).toLong()
                player.commandSeekTo(positionMs)
                result.success(null)
            }
            "seekForward" -> {
                val offsetMs = (call.argument<Number>("offsetMs") ?: 0).toLong()
                player.commandSeekForward(offsetMs)
                result.success(null)
            }
            "seekBackward" -> {
                val offsetMs = (call.argument<Number>("offsetMs") ?: 0).toLong()
                player.commandSeekBackward(offsetMs)
                result.success(null)
            }
            "setPlaybackSpeed" -> {
                val speed = (call.argument<Number>("speed") ?: 1.0).toFloat()
                player.commandSetSpeed(speed)
                result.success(null)
            }
            "setVolume" -> {
                val volume = (call.argument<Number>("volume") ?: 1.0).toFloat()
                player.commandSetVolume(volume)
                result.success(null)
            }
            "getVolume" -> result.success(player.commandGetVolume())
            "setMuted" -> {
                player.commandSetMuted(call.argument<Boolean>("muted") ?: false)
                result.success(null)
            }
            "isMuted" -> result.success(player.commandIsMuted())
            "getAvailableVideoTracks" -> result.success(player.commandGetAvailableVideoTracks())
            "setVideoTrack" -> {
                val trackId = call.argument<String>("trackId")
                if (trackId == null) {
                    result.error("INVALID_ARGS", "trackId is required", null)
                } else {
                    player.commandSetVideoTrack(trackId)
                    result.success(null)
                }
            }
            "setSubtitleEnabled" -> {
                player.commandSetSubtitleEnabled(call.argument<Boolean>("enabled") ?: false)
                result.success(null)
            }
            "isSubtitleEnabled" -> result.success(player.commandIsSubtitleEnabled())
            "hasNext" -> result.success(player.commandHasNext())
            "hasPrevious" -> result.success(player.commandHasPrevious())
            "next" -> { player.commandNext(); result.success(null) }
            "previous" -> { player.commandPrevious(); result.success(null) }
            else -> result.notImplemented()
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
