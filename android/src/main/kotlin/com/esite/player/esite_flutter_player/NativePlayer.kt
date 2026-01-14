package com.esite.player.esite_flutter_player

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.drm.DefaultDrmSessionManagerProvider
import androidx.media3.common.util.Util
import java.util.UUID

class NativePlayer(private val context: Context) {

    private var player: ExoPlayer? = null

    fun initialize(args: Map<String, Any>) {
        val sourceUrl = args["sourceUrl"] as String
        val drm = args["drm"] as Map<String, Any>

        val licenseUrl = drm["licenseUrl"] as String
        val scheme = drm["scheme"] as String
        val licenseHeaders = drm["licenseHeaders"] as? Map<String, String>

        val drmUuid = when (scheme) {
            "widevine" -> UUID.fromString("edef8ba9-79d6-4ace-a3c8-27dcd51d21ed")
            else -> throw IllegalArgumentException("Unsupported DRM scheme")
        }

        val trackSelector = DefaultTrackSelector(context)

        val drmProvider = DefaultDrmSessionManagerProvider().apply {
            setDrmHttpDataSourceFactory(
                Util.getUserAgent(context, "esite_flutter_player")
            )
        }

        player = ExoPlayer.Builder(context)
            .setTrackSelector(trackSelector)
            .setDrmSessionManagerProvider(drmProvider)
            .build()

        val mediaItem = MediaItem.Builder()
            .setUri(sourceUrl)
            .setDrmConfiguration(
                MediaItem.DrmConfiguration.Builder(drmUuid)
                    .setLicenseUri(licenseUrl)
                    .setLicenseRequestHeaders(licenseHeaders ?: emptyMap())
                    .build()
            )
            .build()

        player?.setMediaItem(mediaItem)
        player?.prepare()
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
        player?.playbackParameters = PlaybackParameters(speed)
    }

    fun dispose() {
        player?.release()
        player = null
    }
}
