package com.esite.player.esite_flutter_player

import android.app.Activity
import android.view.WindowManager

class SecurityManager {

    private var activity: Activity? = null
    private var isSecureEnabled = false
    private var preventScreenshots = false
    private var preventScreenRecording = false

    fun setActivity(activity: Activity?) {
        this.activity = activity
        if (isSecureEnabled && activity != null) {
            enableSecurity()
        }
    }

    fun configure(preventScreenshots: Boolean, preventScreenRecording: Boolean) {
        this.preventScreenshots = preventScreenshots
        this.preventScreenRecording = preventScreenRecording
    }

    fun enableSecurity() {
        if (preventScreenshots || preventScreenRecording) {
            activity?.window?.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
            isSecureEnabled = true
        }
    }

    fun disableSecurity() {
        activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        isSecureEnabled = false
    }

    fun isSecurityEnabled(): Boolean = isSecureEnabled

    fun clearActivity() {
        disableSecurity()
        activity = null
    }
}
