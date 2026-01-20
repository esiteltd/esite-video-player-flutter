package com.esite.player.esite_flutter_player

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.common.util.Util
import java.util.UUID
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.common.C
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.drm.DefaultDrmSessionManagerProvider
import androidx.media3.exoplayer.drm.DrmSessionEventListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory

class NativePlayer(
    private val context: Context,
    private val onState: (Int) -> Unit,
    private val onError: (Int, String) -> Unit,
    private val onDrmEvent: (Int, String?) -> Unit,
    private val onPlaybackStarted: () -> Unit = {},
    private val onPlaybackPaused: () -> Unit = {}
) {

    private var player: ExoPlayer? = null
    private var trackSelector: DefaultTrackSelector? = null
    private var currentMediaItems: MutableList<MediaItem> = mutableListOf()
    private var currentIndex: Int = 0

    fun getPlayer(): ExoPlayer? = player

    fun initialize(args: Map<String, Any>) {
        val sourceUrl = args["sourceUrl"] as String
        val headers = args["headers"] as? Map<String, String> ?: emptyMap()
        val drm = args["drm"] as? Map<String, Any>
        val autoPlay = args["autoPlay"] as? Boolean ?: false

        if (drm == null) {
            onError(0, "DRM configuration is required")
            return
        }

        val licenseUrl = drm["licenseUrl"] as? String
        val scheme = drm["scheme"] as? String
        val licenseHeaders = drm["licenseHeaders"] as? Map<String, String>

        if (licenseUrl == null || scheme == null) {
            onError(1, "Invalid DRM configuration")
            return
        }

        val drmUuid = when (scheme) {
            "widevine" -> C.WIDEVINE_UUID
            "playready" -> C.PLAYREADY_UUID
            else -> {
                onError(1, "Unsupported DRM scheme: $scheme")
                return
            }
        }

        try {
            trackSelector = DefaultTrackSelector(context)

            val httpDataSourceFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(Util.getUserAgent(context, "esite_flutter_player"))
                .setDefaultRequestProperties(headers)

            val drmHttpDataSourceFactory = DefaultHttpDataSource.Factory()
                .setUserAgent(Util.getUserAgent(context, "esite_flutter_player"))

            val drmSessionManagerProvider = DefaultDrmSessionManagerProvider()
            drmSessionManagerProvider.setDrmHttpDataSourceFactory(drmHttpDataSourceFactory)

            val mediaSourceFactory = DefaultMediaSourceFactory(context)
                .setDataSourceFactory(httpDataSourceFactory)
                .setDrmSessionManagerProvider(drmSessionManagerProvider)

            player = ExoPlayer.Builder(context)
                .setTrackSelector(trackSelector!!)
                .setMediaSourceFactory(mediaSourceFactory)
                .build()

            player?.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    val mapped = when (state) {
                        Player.STATE_IDLE -> 0
                        Player.STATE_BUFFERING -> 2
                        Player.STATE_READY -> 3
                        Player.STATE_ENDED -> {
                            onPlaybackPaused()
                            6
                        }
                        else -> 0
                    }
                    onState(mapped)
                }

                override fun onPlayerError(error: PlaybackException) {
                    val (code, message) = when (error.errorCode) {
                        PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED,
                        PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT ->
                            Pair(2, "Network error: ${error.message}")
                        PlaybackException.ERROR_CODE_DRM_LICENSE_ACQUISITION_FAILED,
                        PlaybackException.ERROR_CODE_DRM_PROVISIONING_FAILED,
                        PlaybackException.ERROR_CODE_DRM_DEVICE_REVOKED ->
                            Pair(1, "DRM failure: ${error.message}")
                        PlaybackException.ERROR_CODE_IO_INVALID_HTTP_CONTENT_TYPE,
                        PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS ->
                            Pair(0, "Invalid source: ${error.message}")
                        else -> Pair(3, "Playback error: ${error.message}")
                    }
                    onError(code, message)
                    onDrmEvent(2, message)
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    if (isPlaying) {
                        onState(4)
                        onPlaybackStarted()
                    } else {
                        if (player?.playbackState != Player.STATE_ENDED) {
                            onState(5)
                        }
                        onPlaybackPaused()
                    }
                }
            })

            val drmEventListener = object : DrmSessionEventListener {
                override fun onDrmSessionAcquired(
                    windowIndex: Int,
                    mediaPeriodId: androidx.media3.exoplayer.source.MediaSource.MediaPeriodId?,
                    loadDurationMs: Long
                ) {
                    onDrmEvent(1, "License acquired in ${loadDurationMs}ms")
                }

                override fun onDrmKeysLoaded(
                    windowIndex: Int,
                    mediaPeriodId: androidx.media3.exoplayer.source.MediaSource.MediaPeriodId?
                ) {
                    onDrmEvent(1, "DRM keys loaded successfully")
                }

                override fun onDrmSessionManagerError(
                    windowIndex: Int,
                    mediaPeriodId: androidx.media3.exoplayer.source.MediaSource.MediaPeriodId?,
                    error: Exception
                ) {
                    onDrmEvent(2, "DRM error: ${error.message}")
                }
            }

            player?.addAnalyticsListener(object : androidx.media3.exoplayer.analytics.AnalyticsListener {
                override fun onDrmSessionAcquired(
                    eventTime: androidx.media3.exoplayer.analytics.AnalyticsListener.EventTime,
                    state: Int
                ) {
                    onDrmEvent(0, "License requested")
                }
            })

            val mediaItem = MediaItem.Builder()
                .setUri(sourceUrl)
                .setDrmConfiguration(
                    MediaItem.DrmConfiguration.Builder(drmUuid)
                        .setLicenseUri(licenseUrl)
                        .setLicenseRequestHeaders(licenseHeaders ?: emptyMap())
                        .build()
                )
                .build()

            currentMediaItems.clear()
            currentMediaItems.add(mediaItem)
            currentIndex = 0

            player?.setMediaItem(mediaItem)
            player?.prepare()
            player?.playWhenReady = autoPlay

        } catch (e: Exception) {
            onError(4, "Initialization failed: ${e.message}")
        }
    }

    fun play() {
        player?.playWhenReady = true
    }

    fun pause() {
        player?.pause()
    }

    fun seekTo(positionMs: Long) {
        player?.seekTo(positionMs)
    }

    fun setPlaybackSpeed(speed: Float) {
        val clampedSpeed = speed.coerceIn(0.5f, 4.0f)
        player?.playbackParameters = PlaybackParameters(clampedSpeed)
    }

    fun seekForward(offsetMs: Long) {
        player?.let {
            val newPosition = (it.currentPosition + offsetMs).coerceAtMost(it.duration)
            it.seekTo(newPosition)
        }
    }

    fun seekBackward(offsetMs: Long) {
        player?.let {
            val newPosition = (it.currentPosition - offsetMs).coerceAtLeast(0)
            it.seekTo(newPosition)
        }
    }

    fun setVolume(volume: Float) {
        val clampedVolume = volume.coerceIn(0.0f, 1.0f)
        player?.volume = clampedVolume
    }

    fun setMuted(muted: Boolean) {
        player?.volume = if (muted) 0.0f else 1.0f
    }

    fun isMuted(): Boolean {
        return player?.volume == 0.0f
    }

    fun getVolume(): Float {
        return player?.volume ?: 1.0f
    }

    fun getAvailableVideoTracks(): List<Map<String, Any>> {
        val tracks = mutableListOf<Map<String, Any>>()
        player?.let { player ->
            val currentTracks = player.currentTracks
            for (group in currentTracks.groups) {
                if (group.type == C.TRACK_TYPE_VIDEO) {
                    for (i in 0 until group.length) {
                        val format = group.getTrackFormat(i)
                        tracks.add(mapOf(
                            "id" to "$i",
                            "width" to (format.width),
                            "height" to (format.height),
                            "bitrate" to (format.bitrate),
                            "label" to (format.label ?: "${format.width}x${format.height}")
                        ))
                    }
                }
            }
        }
        return tracks
    }

    fun setVideoTrack(trackId: String) {
        try {
            trackSelector?.let { selector ->
                val trackIndex = trackId.toIntOrNull() ?: return
                val parameters = selector.parameters
                    .buildUpon()
                    .setMaxVideoSize(Int.MAX_VALUE, Int.MAX_VALUE)
                    .setMaxVideoBitrate(Int.MAX_VALUE)
                    .build()
                selector.parameters = parameters
            }
        } catch (e: Exception) {
            onError(4, "Failed to set video track: ${e.message}")
        }
    }

    fun setSubtitleEnabled(enabled: Boolean) {
        trackSelector?.let { selector ->
            val parameters = selector.parameters.buildUpon()
                .setRendererDisabled(C.TRACK_TYPE_TEXT, !enabled)
                .build()
            selector.parameters = parameters
        }
    }

    fun isSubtitleEnabled(): Boolean {
        return trackSelector?.parameters?.getRendererDisabled(C.TRACK_TYPE_TEXT) != true
    }

    fun hasNext(): Boolean {
        return player?.hasNextMediaItem() == true || currentIndex < currentMediaItems.size - 1
    }

    fun hasPrevious(): Boolean {
        return player?.hasPreviousMediaItem() == true || currentIndex > 0
    }

    fun next() {
        if (player?.hasNextMediaItem() == true) {
            player?.seekToNextMediaItem()
        } else if (currentIndex < currentMediaItems.size - 1) {
            currentIndex++
            player?.setMediaItem(currentMediaItems[currentIndex])
            player?.prepare()
        }
    }

    fun previous() {
        if (player?.hasPreviousMediaItem() == true) {
            player?.seekToPreviousMediaItem()
        } else if (currentIndex > 0) {
            currentIndex--
            player?.setMediaItem(currentMediaItems[currentIndex])
            player?.prepare()
        }
    }

    fun dispose() {
        onPlaybackPaused()
        player?.release()
        player = null
        trackSelector = null
        currentMediaItems.clear()
    }
}
