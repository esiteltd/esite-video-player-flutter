package com.esite.player.esite_flutter_player

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class EsSiteFlutterPlayerPlugin : FlutterPlugin {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var player: NativePlayer

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "esite_flutter_player/methods")
        player = NativePlayer(context)

        binding.platformViewRegistry.registerViewFactory(
            "esite_flutter_player/view",
            ESitePlayerViewFactory(player)
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as Map<String, Any>
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
    }
}
