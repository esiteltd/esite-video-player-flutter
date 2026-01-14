package com.esite.player.esite_flutter_player

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ESitePlayerViewFactory(
    private val player: NativePlayer
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return ESitePlayerPlatformView(context, player)
    }
}
