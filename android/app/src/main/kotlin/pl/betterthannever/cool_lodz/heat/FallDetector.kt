package pl.betterthannever.cool_lodz.heat

import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Spots a fall in accelerometer samples (m/s², with gravity): a short free
 * fall (|a| < [freeFall] for [freeFallMs]), a hard impact (|a| > [impact])
 * within [impactWithinMs], then lying still (|a| ≈ g) for [stillMs].
 * Feed it with [add]; it returns true once per fall.
 */
class FallDetector(
    private val freeFall: Double = 3.0,
    private val freeFallMs: Long = 60,
    private val impact: Double = 25.0,
    private val impactWithinMs: Long = 1_000,
    private val stillMs: Long = 10_000,
    private val stillTolerance: Double = 1.5,
) {
    private enum class State { WAIT, FALLING, FELL, IMPACT }

    private var state = State.WAIT
    private var since = 0L
    private var stillSince = 0L

    fun add(x: Float, y: Float, z: Float, timeMs: Long): Boolean =
        addMagnitude(sqrt((x * x + y * y + z * z).toDouble()), timeMs)

    fun addMagnitude(a: Double, timeMs: Long): Boolean {
        when (state) {
            State.WAIT -> if (a < freeFall) {
                state = State.FALLING
                since = timeMs
            }
            State.FALLING -> when {
                a >= freeFall -> state = if (timeMs - since >= freeFallMs) {
                    since = timeMs
                    // This sample may already be the impact.
                    if (a > impact) {
                        stillSince = timeMs
                        State.IMPACT
                    } else {
                        State.FELL
                    }
                } else {
                    State.WAIT
                }
            }
            State.FELL -> when {
                a > impact -> {
                    state = State.IMPACT
                    since = timeMs
                    stillSince = timeMs
                }
                timeMs - since > impactWithinMs -> state = State.WAIT
            }
            State.IMPACT -> {
                if (abs(a - GRAVITY) > stillTolerance) {
                    // Moving again: allow 2 s of bounces, then stand down.
                    if (timeMs - since > 2_000) {
                        state = State.WAIT
                    } else {
                        stillSince = timeMs
                    }
                } else if (timeMs - stillSince >= stillMs) {
                    state = State.WAIT
                    return true
                }
            }
        }
        return false
    }

    companion object {
        const val GRAVITY = 9.81
    }
}
