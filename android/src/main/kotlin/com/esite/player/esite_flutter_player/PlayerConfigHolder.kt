package com.esite.player.esite_flutter_player

object PlayerConfigHolder {
    var config: Map<String, Any>? = null

    fun take(): Map<String, Any>? {
        val c = config
        config = null
        return c
    }
}
