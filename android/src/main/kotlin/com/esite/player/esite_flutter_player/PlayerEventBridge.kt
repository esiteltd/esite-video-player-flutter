package com.esite.player.esite_flutter_player

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object PlayerEventBridge {
    private val mainHandler = Handler(Looper.getMainLooper())

    var stateSink: EventChannel.EventSink? = null
    var drmSink: EventChannel.EventSink? = null
    var errorSink: EventChannel.EventSink? = null

    fun sendState(stateCode: Int) {
        mainHandler.post { stateSink?.success(stateCode) }
    }

    fun sendDrmEvent(type: Int, message: String?) {
        mainHandler.post {
            drmSink?.success(mapOf("type" to type, "message" to message))
        }
    }

    fun sendError(code: Int, message: String) {
        mainHandler.post {
            errorSink?.success(mapOf("code" to code, "message" to message))
        }
    }

    /**
     * The player was dismissed. Reported as `closed` (8) rather than
     * `completed` (6) so Dart can tell a finished video from an abandoned one.
     */
    fun notifyActivityFinished() {
        sendState(8)
    }

    fun clear() {
        stateSink = null
        drmSink = null
        errorSink = null
    }
}
