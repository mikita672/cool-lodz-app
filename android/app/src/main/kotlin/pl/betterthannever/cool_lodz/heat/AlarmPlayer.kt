package pl.betterthannever.cool_lodz.heat

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import pl.betterthannever.cool_lodz.R
import kotlin.math.roundToInt

/**
 * The siren on the alarm stream (it plays in silent mode too), vibration
 * and a blinking flashlight. Restores the alarm volume when stopped.
 */
class AlarmPlayer(private val context: Context) {
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var savedVolume: Int? = null
    private var torchOn = false
    private var torchId: String? = null

    fun vibrate() {
        val pattern = longArrayOf(0, 700, 400, 700, 400, 700)
        val vibrator = if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        try {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } catch (e: Exception) {
            Log.w(TAG, "vibrate", e)
        }
    }

    private fun stopVibration() {
        try {
            if (Build.VERSION.SDK_INT >= 31) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).cancel()
            } else {
                @Suppress("DEPRECATION")
                (context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
            }
        } catch (e: Exception) {
            Log.w(TAG, "vibration cancel", e)
        }
    }

    /** Plays the siren in a loop at [fraction] of the alarm stream's maximum. */
    fun play(fraction: Float) {
        try {
            val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            if (savedVolume == null) savedVolume = audio.getStreamVolume(AudioManager.STREAM_ALARM)
            val volume = (max * fraction).roundToInt().coerceIn(1, max)
            audio.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0)
        } catch (e: Exception) {
            Log.w(TAG, "volume", e)
        }
        if (player != null) return
        try {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val id = audio.generateAudioSessionId()
            player = MediaPlayer.create(context, R.raw.heat_alarm, attributes, id)?.apply {
                isLooping = true
                start()
            }
        } catch (e: Exception) {
            Log.w(TAG, "siren", e)
        }
    }

    /** Blinks the flashlight twice a second (if there is one). */
    fun blinkTorch() {
        if (torchId != null) return
        val camera = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        torchId = try {
            camera.cameraIdList.firstOrNull {
                camera.getCameraCharacteristics(it)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
        } catch (e: Exception) {
            null
        } ?: return
        val blink = object : Runnable {
            override fun run() {
                val id = torchId ?: return
                torchOn = !torchOn
                try {
                    camera.setTorchMode(id, torchOn)
                } catch (e: Exception) {
                    Log.w(TAG, "torch", e)
                    torchId = null
                    return
                }
                handler.postDelayed(this, 500)
            }
        }
        handler.post(blink)
    }

    fun stop() {
        handler.removeCallbacksAndMessages(null)
        torchId?.let { id ->
            try {
                (context.getSystemService(Context.CAMERA_SERVICE) as CameraManager).setTorchMode(id, false)
            } catch (e: Exception) {
                Log.w(TAG, "torch off", e)
            }
        }
        torchId = null
        torchOn = false
        player?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
        stopVibration()
        savedVolume?.let {
            try {
                audio.setStreamVolume(AudioManager.STREAM_ALARM, it, 0)
            } catch (e: Exception) {
                Log.w(TAG, "volume restore", e)
            }
        }
        savedVolume = null
    }

    companion object {
        private const val TAG = "HeatAlarm"
    }
}
