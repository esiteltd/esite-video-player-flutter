package com.esite.player.esite_flutter_player

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class EsiteFlutterPlayerPlugin : FlutterPlugin, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var player: NativePlayer
    private lateinit var stateChannel: EventChannel
    private lateinit var drmChannel: EventChannel
    private lateinit var errorChannel: EventChannel
    private lateinit var securityManager: SecurityManager

    private var stateSink: EventChannel.EventSink? = null
    private var drmSink: EventChannel.EventSink? = null
    private var errorSink: EventChannel.EventSink? = null


    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "esite_flutter_player/methods")
        securityManager = SecurityManager()
        
        player = NativePlayer(
            context,
            onState = { state -> stateSink?.success(state) },
            onError = { code, msg ->
                errorSink?.success(mapOf("code" to code, "message" to msg))
            },
            onDrmEvent = { type, msg ->
                drmSink?.success(mapOf("type" to type, "message" to msg))
            },
            onPlaybackStarted = { securityManager.enableSecurity() },
            onPlaybackPaused = { securityManager.disableSecurity() }
        )

        binding.platformViewRegistry.registerViewFactory(
            "esite_flutter_player/view",
            ESitePlayerViewFactory(player)
        )
        stateChannel = EventChannel(
    binding.binaryMessenger,
    "esite_flutter_player/events/state"
)
drmChannel = EventChannel(
    binding.binaryMessenger,
    "esite_flutter_player/events/drm"
)
errorChannel = EventChannel(
    binding.binaryMessenger,
    "esite_flutter_player/events/error"
)

stateChannel.setStreamHandler(object : EventChannel.StreamHandler {
    override fun onListen(args: Any?, sink: EventChannel.EventSink) {
        stateSink = sink
    }

    override fun onCancel(args: Any?) {
        stateSink = null
    }
})

drmChannel.setStreamHandler(object : EventChannel.StreamHandler {
    override fun onListen(args: Any?, sink: EventChannel.EventSink) {
        drmSink = sink
    }

    override fun onCancel(args: Any?) {
        drmSink = null
    }
})

errorChannel.setStreamHandler(object : EventChannel.StreamHandler {
    override fun onListen(args: Any?, sink: EventChannel.EventSink) {
        errorSink = sink
    }

    override fun onCancel(args: Any?) {
        errorSink = null
    }
})

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as Map<String, Any>
                    val preventScreenshots = args["preventScreenshots"] as? Boolean ?: false
                    val preventScreenRecording = args["preventScreenRecording"] as? Boolean ?: false
                    securityManager.configure(preventScreenshots, preventScreenRecording)
                    player.initialize(args)
                    result.success(null)
                }
                "play" -> { player.play(); result.success(null) }
                "pause" -> { player.pause(); result.success(null) }
                "seekTo" -> {
                    val pos = call.argument<Int>("positionMs")!!
                    player.seekTo(pos.toLong())
                    result.success(null)
                }
                "setPlaybackSpeed" -> {
                    val speed = call.argument<Double>("speed")!!
                    player.setPlaybackSpeed(speed.toFloat())
                    result.success(null)
                }
                "seekForward" -> {
                    val offsetMs = call.argument<Int>("offsetMs")!!
                    player.seekForward(offsetMs.toLong())
                    result.success(null)
                }
                "seekBackward" -> {
                    val offsetMs = call.argument<Int>("offsetMs")!!
                    player.seekBackward(offsetMs.toLong())
                    result.success(null)
                }
                "setVolume" -> {
                    val volume = call.argument<Double>("volume")!!
                    player.setVolume(volume.toFloat())
                    result.success(null)
                }
                "setMuted" -> {
                    val muted = call.argument<Boolean>("muted")!!
                    player.setMuted(muted)
                    result.success(null)
                }
                "isMuted" -> {
                    result.success(player.isMuted())
                }
                "getVolume" -> {
                    result.success(player.getVolume().toDouble())
                }
                "getAvailableVideoTracks" -> {
                    result.success(player.getAvailableVideoTracks())
                }
                "setVideoTrack" -> {
                    val trackId = call.argument<String>("trackId")!!
                    player.setVideoTrack(trackId)
                    result.success(null)
                }
                "setSubtitleEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled")!!
                    player.setSubtitleEnabled(enabled)
                    result.success(null)
                }
                "isSubtitleEnabled" -> {
                    result.success(player.isSubtitleEnabled())
                }
                "hasNext" -> {
                    result.success(player.hasNext())
                }
                "hasPrevious" -> {
                    result.success(player.hasPrevious())
                }
                "next" -> {
                    player.next()
                    result.success(null)
                }
                "previous" -> {
                    player.previous()
                    result.success(null)
                }
                "dispose" -> {
                    player.dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        player.dispose()
        securityManager.disableSecurity()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        securityManager.setActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // Keep activity reference during config changes
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        securityManager.setActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        securityManager.clearActivity()
    }
}
