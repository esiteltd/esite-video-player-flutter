package com.esite.player.esite_flutter_player

import android.content.Context
import android.view.View
import androidx.media3.ui.PlayerView
import io.flutter.plugin.platform.PlatformView

class ESitePlayerPlatformView(
    context: Context,
    private val nativePlayer: NativePlayer
) : PlatformView {

    private val playerView: PlayerView = PlayerView(context).apply {
        useController = true
        player = nativePlayer.getPlayer()
    }

    override fun getView(): View = playerView

    override fun dispose() {
        playerView.player = null
    }
}
