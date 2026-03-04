package com.esite.player.esite_flutter_player

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.drawable.Drawable
import android.os.SystemClock
import android.util.AttributeSet
import android.view.View
import androidx.appcompat.content.res.AppCompatResources
import kotlin.math.max

class SeekAnimationView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    // Animation state
    private var isAnimating = false
    private var isForward = true
    private var tapX = 0f
    private var tapY = 0f
    private var accumulatedSeconds = 0
    private var animationStartTime = 0L

    // Timing
    private val animDuration = 700L
    private val accumulateTimeout = 900L

    // Pre-allocated drawing objects
    private val ovalPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val ripplePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }
    private val clipPath = Path()
    private val ovalRect = RectF()

    // Drawables (loaded lazily)
    private var forwardDrawable: Drawable? = null
    private var replayDrawable: Drawable? = null

    private val resetRunnable = Runnable {
        accumulatedSeconds = 0
    }

    init {
        isClickable = false
        isFocusable = false
        setWillNotDraw(false)
    }

    fun showSeek(x: Float, y: Float, forward: Boolean) {
        removeCallbacks(resetRunnable)
        accumulatedSeconds += 10
        isForward = forward
        tapX = x
        tapY = y
        animationStartTime = SystemClock.elapsedRealtime()
        isAnimating = true
        postDelayed(resetRunnable, accumulateTimeout)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        if (!isAnimating) return

        val elapsed = SystemClock.elapsedRealtime() - animationStartTime
        val fraction = (elapsed.toFloat() / animDuration).coerceIn(0f, 1f)

        if (fraction >= 1f) {
            isAnimating = false
            return
        }

        val w = width.toFloat()
        val h = height.toFloat()
        val halfW = w / 2f

        // Ease-out curve for smoother animation
        val easedFraction = 1f - (1f - fraction) * (1f - fraction)

        // Alpha that fades out in the second half of animation
        val alpha = if (fraction < 0.5f) 1f else 1f - (fraction - 0.5f) * 2f

        canvas.save()

        // Clip to the tapped half of the screen with a slight inward curve
        clipPath.reset()
        if (isForward) {
            // Right half with curved left edge
            val curveInset = halfW * 0.15f
            clipPath.moveTo(halfW + curveInset, 0f)
            clipPath.lineTo(w, 0f)
            clipPath.lineTo(w, h)
            clipPath.lineTo(halfW + curveInset, h)
            clipPath.quadTo(halfW - curveInset, h / 2f, halfW + curveInset, 0f)
            clipPath.close()
        } else {
            // Left half with curved right edge
            val curveInset = halfW * 0.15f
            clipPath.moveTo(halfW - curveInset, 0f)
            clipPath.lineTo(0f, 0f)
            clipPath.lineTo(0f, h)
            clipPath.lineTo(halfW - curveInset, h)
            clipPath.quadTo(halfW + curveInset, h / 2f, halfW - curveInset, 0f)
            clipPath.close()
        }
        canvas.clipPath(clipPath)

        // Draw semi-transparent background on the tapped half
        ovalPaint.color = Color.argb((40 * alpha).toInt(), 255, 255, 255)
        canvas.drawRect(0f, 0f, w, h, ovalPaint)

        // Draw expanding ripple circle from tap point
        val maxRadius = max(w, h) * 0.5f
        val rippleRadius = maxRadius * easedFraction
        ripplePaint.color = Color.argb((60 * alpha).toInt(), 255, 255, 255)
        canvas.drawCircle(tapX, tapY, rippleRadius, ripplePaint)

        // Calculate center of the tapped half for icon and text
        val centerX = if (isForward) halfW + halfW / 2f else halfW / 2f
        val centerY = h / 2f

        // Draw the forward/replay icon
        val iconSize = (48 * resources.displayMetrics.density).toInt()
        val drawable = getSeekDrawable()
        drawable?.let {
            val iconAlpha = (255 * alpha).toInt()
            it.alpha = iconAlpha
            it.setBounds(
                (centerX - iconSize / 2).toInt(),
                (centerY - iconSize / 2 - 12 * resources.displayMetrics.density).toInt(),
                (centerX + iconSize / 2).toInt(),
                (centerY + iconSize / 2 - 12 * resources.displayMetrics.density).toInt()
            )
            it.draw(canvas)
        }

        // Draw the accumulated seconds text
        textPaint.textSize = 14 * resources.displayMetrics.scaledDensity
        textPaint.color = Color.argb((255 * alpha).toInt(), 255, 255, 255)
        val text = if (isForward) "+${accumulatedSeconds} seconds" else "-${accumulatedSeconds} seconds"
        canvas.drawText(
            text,
            centerX,
            centerY + iconSize / 2f + 4 * resources.displayMetrics.density,
            textPaint
        )

        canvas.restore()

        // Continue animation loop
        postInvalidateOnAnimation()
    }

    private fun getSeekDrawable(): Drawable? {
        return if (isForward) {
            if (forwardDrawable == null) {
                forwardDrawable = AppCompatResources.getDrawable(context, R.drawable.ic_forward_10)
            }
            forwardDrawable
        } else {
            if (replayDrawable == null) {
                replayDrawable = AppCompatResources.getDrawable(context, R.drawable.ic_replay_10)
            }
            replayDrawable
        }
    }
}
