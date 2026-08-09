package com.esite.player.esite_flutter_player

import android.annotation.SuppressLint
import android.graphics.Color
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.os.Build
import android.os.Bundle
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.C
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.Util
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.ui.DefaultTimeBar
import androidx.media3.ui.PlayerView

class PlayerActivity : AppCompatActivity() {

    companion object {
        /**
         * The player currently on screen, if any. The plugin routes transport
         * commands here — the Activity and the Flutter plugin cannot share
         * instance references any other way.
         */
        @Volatile
        var current: PlayerActivity? = null
            private set
    }

    private var player: ExoPlayer? = null
    private var playerView: PlayerView? = null
    private var trackSelector: DefaultTrackSelector? = null

    private var errorOverlay: LinearLayout? = null
    private var errorTitle: TextView? = null
    private var errorMessage: TextView? = null
    private var btnRetry: Button? = null
    private var btnClose: Button? = null

    // Buttons inside the custom controller layout
    private var btnSpeed: ImageButton? = null
    private var btnAudio: ImageButton? = null
    private var btnQuality: ImageButton? = null

    // YouTube-like features
    private var seekAnimationView: SeekAnimationView? = null
    private var bufferingRing: ProgressBar? = null
    private var gestureDetector: GestureDetector? = null

    private var currentConfig: Map<String, Any>? = null
    private var currentSpeed: Float = 1.0f
    private var volumeBeforeMute: Float = 1.0f

    private var primaryColor: Int = Color.WHITE
    private var secondaryColor: Int = Color.WHITE

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        current = this
        setContentView(R.layout.activity_player)

        playerView = findViewById(R.id.player_view)
        errorOverlay = findViewById(R.id.error_overlay)
        errorTitle = findViewById(R.id.error_title)
        errorMessage = findViewById(R.id.error_message)
        btnRetry = findViewById(R.id.btn_retry)
        btnClose = findViewById(R.id.btn_close)

        // Find buttons inside the PlayerView's custom controller layout
        btnSpeed = playerView?.findViewById(R.id.btn_speed)
        btnAudio = playerView?.findViewById(R.id.btn_audio)
        btnQuality = playerView?.findViewById(R.id.btn_quality)

        // YouTube-like features
        seekAnimationView = findViewById(R.id.seek_animation_view)
        bufferingRing = playerView?.findViewById(R.id.buffering_ring)

        btnRetry?.setOnClickListener { retryPlayback() }
        btnClose?.setOnClickListener { finish() }
        btnSpeed?.setOnClickListener { showSpeedMenu(it) }
        btnAudio?.setOnClickListener { showAudioTrackMenu(it) }
        btnQuality?.setOnClickListener { showQualityMenu(it) }

        setupDoubleTapGesture()

        val config = PlayerConfigHolder.take()
        if (config == null) {
            showError("Configuration Error", "No player configuration available")
            PlayerEventBridge.sendError(4, "No player configuration available")
            return
        }

        currentConfig = config

        // Read colors from config
        val primaryColorValue = config["primaryColor"] as? Long
            ?: (config["primaryColor"] as? Int)?.toLong()
        val secondaryColorValue = config["secondaryColor"] as? Long
            ?: (config["secondaryColor"] as? Int)?.toLong()

        if (primaryColorValue != null) {
            primaryColor = primaryColorValue.toInt()
        }
        if (secondaryColorValue != null) {
            secondaryColor = secondaryColorValue.toInt()
        }

        applyColors()

        val preventScreenshots = config["preventScreenshots"] as? Boolean ?: false
        val preventScreenRecording = config["preventScreenRecording"] as? Boolean ?: false
        if (preventScreenshots || preventScreenRecording) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
        }

        initializePlayer(config)
    }

    private fun applyColors() {
        // Apply primary color to the seek bar
        val timeBar = playerView?.findViewById<DefaultTimeBar>(
            resources.getIdentifier("exo_progress", "id", packageName)
        ) ?: playerView?.findViewById<DefaultTimeBar>(
            androidx.media3.ui.R.id.exo_progress
        )

        timeBar?.let {
            it.setPlayedColor(primaryColor)
            it.setScrubberColor(primaryColor)
            it.setBufferedColor(Color.argb(
                100,
                Color.red(primaryColor),
                Color.green(primaryColor),
                Color.blue(primaryColor)
            ))
            it.setUnplayedColor(Color.argb(
                50,
                Color.red(primaryColor),
                Color.green(primaryColor),
                Color.blue(primaryColor)
            ))
        }

        // Apply secondary color to custom button icons
        val colorFilter = PorterDuffColorFilter(secondaryColor, PorterDuff.Mode.SRC_IN)
        btnSpeed?.colorFilter = colorFilter
        btnAudio?.colorFilter = colorFilter
        btnQuality?.colorFilter = colorFilter

        // Apply secondary color to center transport buttons
        val playPause = playerView?.findViewById<ImageButton>(
            androidx.media3.ui.R.id.exo_play_pause
        )
        val rew = playerView?.findViewById<ImageButton>(
            androidx.media3.ui.R.id.exo_rew
        )
        val ffwd = playerView?.findViewById<ImageButton>(
            androidx.media3.ui.R.id.exo_ffwd
        )

        val transportFilter = PorterDuffColorFilter(secondaryColor, PorterDuff.Mode.SRC_IN)
        playPause?.colorFilter = transportFilter
        rew?.colorFilter = transportFilter
        ffwd?.colorFilter = transportFilter

        // Tint buffering ring with primary color
        bufferingRing?.indeterminateDrawable?.setColorFilter(
            primaryColor, PorterDuff.Mode.SRC_IN
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun initializePlayer(args: Map<String, Any>) {
        hideError()

        val sourceUrl = args["sourceUrl"] as? String
        if (sourceUrl.isNullOrBlank()) {
            showError("Invalid Source", "No video source URL provided")
            PlayerEventBridge.sendError(0, "No video source URL provided")
            return
        }

        val headers = args["headers"] as? Map<String, String> ?: emptyMap()
        val drm = args["drm"] as? Map<String, Any>
        val autoPlay = args["autoPlay"] as? Boolean ?: false
        val streamFormat = (args["streamFormat"] as? String)?.lowercase() ?: "auto"

        // DRM is optional. Unprotected and "Lite DRM" sources open no DRM
        // session at all: Lite DRM is HLS with AES-128 encrypted segments, and
        // HlsMediaSource fetches the key itself from the playlist's key route
        // using the same data source factory as the segments.
        var drmUuid: java.util.UUID? = null
        var licenseUrl: String? = null
        var licenseHeaders: Map<String, String>? = null

        if (drm != null) {
            licenseUrl = drm["licenseUrl"] as? String
            val scheme = drm["scheme"] as? String
            licenseHeaders = drm["licenseHeaders"] as? Map<String, String>

            if (licenseUrl.isNullOrBlank()) {
                showError("DRM Error", "No license server URL provided")
                PlayerEventBridge.sendError(1, "Invalid DRM configuration: missing license URL")
                return
            }

            drmUuid = when (scheme) {
                "widevine" -> C.WIDEVINE_UUID
                // FairPlay is iOS-only; Android has no CDM for it.
                else -> {
                    showError("DRM Error", "Unsupported DRM scheme: $scheme\nSupported on Android: Widevine")
                    PlayerEventBridge.sendError(1, "Unsupported DRM scheme: $scheme")
                    return
                }
            }
        }

        try {
            releasePlayer()

            trackSelector = DefaultTrackSelector(this).apply {
                setParameters(
                    buildUponParameters()
                        .setForceHighestSupportedBitrate(false)
                        .setAllowVideoMixedMimeTypeAdaptiveness(true)
                )
            }

            val httpDataSourceFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(Util.getUserAgent(this, "esite_flutter_player"))
                .setDefaultRequestProperties(headers)
                .setConnectTimeoutMs(15000)
                .setReadTimeoutMs(15000)

            val mediaSourceFactory = DefaultMediaSourceFactory(this)
                .setDataSourceFactory(httpDataSourceFactory)

            player = ExoPlayer.Builder(this)
                .setTrackSelector(trackSelector!!)
                .setMediaSourceFactory(mediaSourceFactory)
                .setLoadControl(
                    DefaultLoadControl.Builder()
                        .setBufferDurationsMs(15000, 30000, 2500, 5000)
                        .build()
                )
                .build()

            playerView?.player = player

            player?.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    val mapped = when (state) {
                        Player.STATE_IDLE -> 0
                        Player.STATE_BUFFERING -> 2
                        Player.STATE_READY -> 3
                        Player.STATE_ENDED -> 6
                        else -> 0
                    }
                    PlayerEventBridge.sendState(mapped)

                    // Show/hide buffering ring
                    bufferingRing?.visibility = if (state == Player.STATE_BUFFERING) {
                        View.VISIBLE
                    } else {
                        View.GONE
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    handlePlaybackError(error)
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    if (isPlaying) {
                        PlayerEventBridge.sendState(4)
                    } else {
                        player?.let {
                            if (it.playbackState != Player.STATE_ENDED) {
                                PlayerEventBridge.sendState(5)
                            }
                        }
                    }
                }
            })

            player?.addAnalyticsListener(object : AnalyticsListener {
                override fun onDrmKeysLoaded(
                    eventTime: AnalyticsListener.EventTime
                ) {
                    PlayerEventBridge.sendDrmEvent(1, "License acquired")
                }

                override fun onDrmSessionManagerError(
                    eventTime: AnalyticsListener.EventTime,
                    error: Exception
                ) {
                    PlayerEventBridge.sendDrmEvent(
                        2,
                        "License acquisition failed: ${error.message}"
                    )
                }
            })

            val mediaItemBuilder = MediaItem.Builder().setUri(sourceUrl)

            // Declare the container rather than letting ExoPlayer infer it from
            // the URL suffix: playback URLs are token-authenticated and carry
            // query strings, so they often do not end in .m3u8 or .mpd.
            when (streamFormat) {
                "hls" -> mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_M3U8)
                "dash" -> mediaItemBuilder.setMimeType(MimeTypes.APPLICATION_MPD)
            }

            if (drmUuid != null && licenseUrl != null) {
                mediaItemBuilder.setDrmConfiguration(
                    MediaItem.DrmConfiguration.Builder(drmUuid)
                        .setLicenseUri(licenseUrl)
                        .setLicenseRequestHeaders(licenseHeaders ?: emptyMap())
                        .setForceSessionsForAudioAndVideoTracks(true)
                        .build()
                )
                reportSecurityLevel(drmUuid)
            }

            player?.setMediaItem(mediaItemBuilder.build())
            player?.prepare()
            player?.playWhenReady = autoPlay
            player?.playbackParameters = PlaybackParameters(currentSpeed)

            PlayerEventBridge.sendState(1) // initializing

        } catch (e: Exception) {
            showError("Initialization Error", "Failed to initialize the player:\n${e.localizedMessage ?: "Unknown error"}")
            PlayerEventBridge.sendError(4, "Initialization failed: ${e.message}")
        }
    }

    private fun handlePlaybackError(error: PlaybackException) {
        val (code, title, message) = when (error.errorCode) {
            PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED ->
                Triple(2, "Network Error", "Could not connect to the server.\nPlease check your internet connection.")
            PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT ->
                Triple(2, "Connection Timeout", "The connection timed out.\nPlease check your network and try again.")

            PlaybackException.ERROR_CODE_DRM_LICENSE_ACQUISITION_FAILED ->
                Triple(1, "DRM License Error", "Failed to acquire the DRM license.\nThe content may require valid authentication.")
            PlaybackException.ERROR_CODE_DRM_PROVISIONING_FAILED ->
                Triple(1, "DRM Provisioning Error", "DRM provisioning failed.\nThis device may not support the required DRM level.")
            PlaybackException.ERROR_CODE_DRM_DEVICE_REVOKED ->
                Triple(1, "DRM Device Revoked", "This device has been revoked and cannot play protected content.")
            PlaybackException.ERROR_CODE_DRM_SYSTEM_ERROR ->
                Triple(1, "DRM System Error", "A DRM system error occurred.\nPlease try again or restart the app.")
            PlaybackException.ERROR_CODE_DRM_CONTENT_ERROR ->
                Triple(1, "DRM Content Error", "The content encryption is not compatible with this device.")
            PlaybackException.ERROR_CODE_DRM_LICENSE_EXPIRED ->
                Triple(1, "DRM License Expired", "The DRM license has expired.\nPlease re-authenticate to continue playback.")
            PlaybackException.ERROR_CODE_DRM_DISALLOWED_OPERATION ->
                Triple(1, "DRM Restriction", "This operation is not allowed by the DRM license.")
            PlaybackException.ERROR_CODE_DRM_SCHEME_UNSUPPORTED ->
                Triple(1, "DRM Not Supported", "The required DRM scheme is not supported on this device.")

            PlaybackException.ERROR_CODE_IO_INVALID_HTTP_CONTENT_TYPE ->
                Triple(0, "Invalid Content", "The content type is not supported.")
            PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS ->
                Triple(0, "Content Unavailable", "The server returned an error.\nThe content may no longer be available.")
            PlaybackException.ERROR_CODE_IO_FILE_NOT_FOUND ->
                Triple(0, "Content Not Found", "The requested content was not found.")
            PlaybackException.ERROR_CODE_IO_NO_PERMISSION ->
                Triple(0, "Access Denied", "You do not have permission to access this content.")
            PlaybackException.ERROR_CODE_IO_CLEARTEXT_NOT_PERMITTED ->
                Triple(2, "Security Error", "Cleartext HTTP is not permitted.\nThe content URL must use HTTPS.")

            PlaybackException.ERROR_CODE_PARSING_CONTAINER_MALFORMED,
            PlaybackException.ERROR_CODE_PARSING_MANIFEST_MALFORMED ->
                Triple(0, "Content Error", "The video content is malformed or corrupted.")
            PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED,
            PlaybackException.ERROR_CODE_PARSING_MANIFEST_UNSUPPORTED ->
                Triple(0, "Unsupported Format", "The video format is not supported on this device.")

            PlaybackException.ERROR_CODE_DECODER_INIT_FAILED ->
                Triple(3, "Decoder Error", "Failed to initialize the video decoder.\nTry a lower quality or restart the app.")
            PlaybackException.ERROR_CODE_DECODER_QUERY_FAILED ->
                Triple(3, "Decoder Error", "Could not find a suitable decoder for this content.")
            PlaybackException.ERROR_CODE_DECODING_FAILED ->
                Triple(3, "Decoding Error", "An error occurred while decoding the video.")
            PlaybackException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED ->
                Triple(3, "Unsupported Format", "The video codec is not supported on this device.")

            else ->
                Triple(3, "Playback Error", "An unexpected error occurred during playback.")
        }

        showError(title, message)
        PlayerEventBridge.sendError(code, message.replace("\n", " "))
        // Only report a DRM failure for actual DRM errors — a network or
        // decoder failure is not a licensing problem.
        if (code == 1) {
            PlayerEventBridge.sendDrmEvent(2, message.replace("\n", " "))
        }
    }

    /**
     * Reports the device's Widevine security level for diagnostics.
     *
     * This only *reads* the level — it does not force one. The session itself
     * is created by ExoPlayer from the MediaItem's DrmConfiguration, so
     * overriding the property on a throwaway MediaDrm instance would have no
     * effect on playback. The instance is released immediately.
     */
    private fun reportSecurityLevel(drmUuid: java.util.UUID) {
        var mediaDrm: FrameworkMediaDrm? = null
        try {
            mediaDrm = FrameworkMediaDrm.newInstance(drmUuid)
            val level = mediaDrm.getPropertyString("securityLevel")
            PlayerEventBridge.sendDrmEvent(0, "DRM security level: $level")
        } catch (e: Exception) {
            PlayerEventBridge.sendDrmEvent(0, "DRM security level unavailable: ${e.message}")
        } finally {
            mediaDrm?.release()
        }
    }

    // --- Double-tap to seek (YouTube-like) ---

    @SuppressLint("ClickableViewAccessibility")
    private fun setupDoubleTapGesture() {
        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onDoubleTap(e: MotionEvent): Boolean {
                val viewWidth = playerView?.width ?: return false
                val currentPlayer = player ?: return false

                val isForward = e.x > viewWidth / 2

                if (isForward) {
                    currentPlayer.seekForward()
                } else {
                    currentPlayer.seekBack()
                }

                seekAnimationView?.showSeek(e.x, e.y, isForward)
                return true
            }

            override fun onDoubleTapEvent(e: MotionEvent): Boolean {
                return true
            }

            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                return false // Let PlayerView handle single taps
            }
        })

        playerView?.setOnTouchListener { _, event ->
            gestureDetector?.onTouchEvent(event)
            false // CRITICAL: return false so PlayerView handles all touches normally
        }
    }

    // --- Error UI ---

    private fun showError(title: String, message: String) {
        runOnUiThread {
            errorTitle?.text = title
            errorMessage?.text = message
            errorOverlay?.visibility = View.VISIBLE
            playerView?.useController = false
        }
    }

    private fun hideError() {
        runOnUiThread {
            errorOverlay?.visibility = View.GONE
            playerView?.useController = true
        }
    }

    private fun retryPlayback() {
        currentConfig?.let { config ->
            hideError()
            initializePlayer(config)
        } ?: finish()
    }

    // --- Playback Speed Menu (anchored to bottom button) ---

    private fun showSpeedMenu(anchor: View) {
        val popup = PopupMenu(this, anchor, Gravity.TOP)
        val speeds = listOf(0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 2.0f, 3.0f, 4.0f)

        speeds.forEachIndexed { index, speed ->
            val label = if (speed == currentSpeed) {
                "${speed}x  \u2713"
            } else {
                "${speed}x"
            }
            popup.menu.add(0, index, index, label)
        }

        popup.setOnMenuItemClickListener { item ->
            val speed = speeds[item.itemId]
            currentSpeed = speed
            player?.playbackParameters = PlaybackParameters(speed)
            true
        }

        popup.show()
    }

    // --- Audio Track Menu (anchored to bottom button) ---

    private fun showAudioTrackMenu(anchor: View) {
        val popup = PopupMenu(this, anchor, Gravity.TOP)
        val player = this.player ?: return
        val currentTracks = player.currentTracks

        var itemId = 0
        val trackOverrides = mutableListOf<Pair<Int, TrackSelectionOverride?>>()

        popup.menu.add(0, itemId, itemId, "Auto (default)")
        trackOverrides.add(Pair(itemId, null))
        itemId++

        for (group in currentTracks.groups) {
            if (group.type == C.TRACK_TYPE_AUDIO) {
                for (i in 0 until group.length) {
                    val format = group.getTrackFormat(i)
                    val label = buildAudioLabel(format)
                    val isSelected = group.isTrackSelected(i)
                    val displayLabel = if (isSelected) "$label  \u2713" else label

                    popup.menu.add(0, itemId, itemId, displayLabel)
                    trackOverrides.add(
                        Pair(itemId, TrackSelectionOverride(group.mediaTrackGroup, listOf(i)))
                    )
                    itemId++
                }
            }
        }

        if (itemId <= 1) {
            popup.menu.clear()
            popup.menu.add(0, 0, 0, "No audio tracks available")
            popup.show()
            return
        }

        popup.setOnMenuItemClickListener { item ->
            val (_, override) = trackOverrides.find { it.first == item.itemId } ?: return@setOnMenuItemClickListener false
            val selector = trackSelector ?: return@setOnMenuItemClickListener false

            if (override == null) {
                selector.parameters = selector.parameters.buildUpon()
                    .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
                    .build()
            } else {
                selector.parameters = selector.parameters.buildUpon()
                    .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
                    .addOverride(override)
                    .build()
            }
            true
        }

        popup.show()
    }

    private fun buildAudioLabel(format: Format): String {
        val parts = mutableListOf<String>()
        format.label?.let { parts.add(it) }
        format.language?.let { lang ->
            if (lang != "und") {
                val displayLang = java.util.Locale(lang).displayLanguage
                if (displayLang.isNotBlank() && !parts.any { it.equals(displayLang, ignoreCase = true) }) {
                    parts.add(displayLang)
                }
            }
        }
        if (format.channelCount > 0) {
            val channels = when (format.channelCount) {
                1 -> "Mono"
                2 -> "Stereo"
                6 -> "5.1"
                8 -> "7.1"
                else -> "${format.channelCount}ch"
            }
            parts.add(channels)
        }
        return if (parts.isEmpty()) "Audio track" else parts.joinToString(" - ")
    }

    // --- Quality / Video Track Menu (anchored to bottom button) ---

    private fun showQualityMenu(anchor: View) {
        val popup = PopupMenu(this, anchor, Gravity.TOP)
        val player = this.player ?: return
        val currentTracks = player.currentTracks

        var itemId = 0
        val trackOverrides = mutableListOf<Pair<Int, TrackSelectionOverride?>>()

        popup.menu.add(0, itemId, itemId, "Auto (adaptive)")
        trackOverrides.add(Pair(itemId, null))
        itemId++

        for (group in currentTracks.groups) {
            if (group.type == C.TRACK_TYPE_VIDEO) {
                for (i in 0 until group.length) {
                    val format = group.getTrackFormat(i)
                    val label = buildVideoLabel(format)
                    val isSelected = group.isTrackSelected(i)
                    val displayLabel = if (isSelected) "$label  \u2713" else label

                    popup.menu.add(0, itemId, itemId, displayLabel)
                    trackOverrides.add(
                        Pair(itemId, TrackSelectionOverride(group.mediaTrackGroup, listOf(i)))
                    )
                    itemId++
                }
            }
        }

        if (itemId <= 1) {
            popup.menu.clear()
            popup.menu.add(0, 0, 0, "No quality options available")
            popup.show()
            return
        }

        popup.setOnMenuItemClickListener { item ->
            val (_, override) = trackOverrides.find { it.first == item.itemId } ?: return@setOnMenuItemClickListener false
            val selector = trackSelector ?: return@setOnMenuItemClickListener false

            if (override == null) {
                selector.parameters = selector.parameters.buildUpon()
                    .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                    .setMaxVideoSize(Int.MAX_VALUE, Int.MAX_VALUE)
                    .setMaxVideoBitrate(Int.MAX_VALUE)
                    .build()
            } else {
                selector.parameters = selector.parameters.buildUpon()
                    .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                    .addOverride(override)
                    .build()
            }
            true
        }

        popup.show()
    }

    private fun buildVideoLabel(format: Format): String {
        val parts = mutableListOf<String>()
        if (format.height > 0) {
            parts.add("${format.height}p")
        }
        if (format.bitrate > 0) {
            val mbps = format.bitrate / 1_000_000.0
            if (mbps >= 1.0) {
                parts.add("${String.format("%.1f", mbps)} Mbps")
            } else {
                parts.add("${format.bitrate / 1000} kbps")
            }
        }
        if (format.frameRate > 0) {
            parts.add("${format.frameRate.toInt()}fps")
        }
        return if (parts.isEmpty()) "Video track" else parts.joinToString(" - ")
    }

    // --- Transport commands from Dart ---
    //
    // MethodChannel handlers run on the platform main thread, which is also
    // ExoPlayer's application thread, so these touch the player directly.

    fun commandPlay() { player?.play() }

    fun commandPause() { player?.pause() }

    fun commandSeekTo(positionMs: Long) { player?.seekTo(positionMs) }

    fun commandSeekForward(offsetMs: Long) {
        player?.let { it.seekTo((it.currentPosition + offsetMs).coerceAtMost(it.duration.coerceAtLeast(0))) }
    }

    fun commandSeekBackward(offsetMs: Long) {
        player?.let { it.seekTo((it.currentPosition - offsetMs).coerceAtLeast(0)) }
    }

    fun commandSetSpeed(speed: Float) {
        currentSpeed = speed
        player?.playbackParameters = PlaybackParameters(speed)
    }

    fun commandSetVolume(volume: Float) {
        if (volume > 0f) {
            volumeBeforeMute = volume
        }
        player?.volume = volume
    }

    fun commandGetVolume(): Double = (player?.volume ?: 1.0f).toDouble()

    fun commandSetMuted(muted: Boolean) {
        val currentVolume = player?.volume ?: 1.0f
        if (muted) {
            if (currentVolume > 0f) {
                volumeBeforeMute = currentVolume
            }
            player?.volume = 0f
        } else {
            player?.volume = volumeBeforeMute
        }
    }

    fun commandIsMuted(): Boolean = (player?.volume ?: 1.0f) == 0f

    fun commandHasNext(): Boolean = player?.hasNextMediaItem() ?: false

    fun commandHasPrevious(): Boolean = player?.hasPreviousMediaItem() ?: false

    fun commandNext() {
        player?.let { if (it.hasNextMediaItem()) it.seekToNextMediaItem() }
    }

    fun commandPrevious() {
        player?.let { if (it.hasPreviousMediaItem()) it.seekToPreviousMediaItem() }
    }

    fun commandClose() { finish() }

    /**
     * Video tracks as `{id, label, width, height, bitrate, frameRate}`. The id
     * is `groupIndex:trackIndex`, which [commandSetVideoTrack] parses back.
     */
    fun commandGetAvailableVideoTracks(): List<Map<String, Any>> {
        val tracks = player?.currentTracks ?: return emptyList()
        val result = mutableListOf<Map<String, Any>>()
        tracks.groups.forEachIndexed { groupIndex, group ->
            if (group.type != C.TRACK_TYPE_VIDEO) return@forEachIndexed
            for (trackIndex in 0 until group.length) {
                if (!group.isTrackSupported(trackIndex)) continue
                val format = group.getTrackFormat(trackIndex)
                result.add(
                    mapOf(
                        "id" to "$groupIndex:$trackIndex",
                        "label" to buildVideoLabel(format),
                        "width" to format.width,
                        "height" to format.height,
                        "bitrate" to format.bitrate,
                        "frameRate" to format.frameRate.toDouble()
                    )
                )
            }
        }
        return result
    }

    /** Pass `"auto"` to return to adaptive selection. */
    fun commandSetVideoTrack(trackId: String) {
        val selector = trackSelector ?: return
        if (trackId == "auto") {
            selector.parameters = selector.buildUponParameters()
                .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
                .setMaxVideoSize(Int.MAX_VALUE, Int.MAX_VALUE)
                .setMaxVideoBitrate(Int.MAX_VALUE)
                .build()
            return
        }

        val parts = trackId.split(":")
        val groupIndex = parts.getOrNull(0)?.toIntOrNull() ?: return
        val trackIndex = parts.getOrNull(1)?.toIntOrNull() ?: return
        val groups = player?.currentTracks?.groups ?: return
        val group = groups.getOrNull(groupIndex) ?: return

        selector.parameters = selector.buildUponParameters()
            .clearOverridesOfType(C.TRACK_TYPE_VIDEO)
            .addOverride(TrackSelectionOverride(group.mediaTrackGroup, trackIndex))
            .build()
    }

    fun commandSetSubtitleEnabled(enabled: Boolean) {
        val selector = trackSelector ?: return
        selector.parameters = selector.buildUponParameters()
            .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, !enabled)
            .build()
    }

    fun commandIsSubtitleEnabled(): Boolean {
        val selector = trackSelector ?: return false
        return !selector.parameters.getRendererDisabled(C.TRACK_TYPE_TEXT) &&
            !selector.parameters.disabledTrackTypes.contains(C.TRACK_TYPE_TEXT)
    }

    // --- Lifecycle ---

    override fun onResume() {
        super.onResume()
        playerView?.onResume()
    }

    override fun onPause() {
        super.onPause()
        playerView?.onPause()
        if (Build.VERSION.SDK_INT < 24 || !isInMultiWindowMode) {
            player?.playWhenReady = false
        }
    }

    override fun onStop() {
        super.onStop()
        player?.playWhenReady = false
    }

    override fun onDestroy() {
        super.onDestroy()
        if (current === this) {
            current = null
        }
        releasePlayer()
        PlayerEventBridge.notifyActivityFinished()
    }

    private fun releasePlayer() {
        player?.let {
            it.stop()
            it.release()
        }
        player = null
        playerView?.player = null
        trackSelector = null
    }
}
