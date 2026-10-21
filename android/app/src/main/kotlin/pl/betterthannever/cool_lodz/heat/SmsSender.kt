package pl.betterthannever.cool_lodz.heat

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.util.Log

/** Sends a text from the user's own SIM (free on most Polish plans). */
object SmsSender {
    fun canSend(context: Context) =
        context.checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED &&
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_MESSAGING)

    /** Returns the numbers the message was handed to the modem for. */
    fun send(context: Context, numbers: List<String>, text: String): List<String> {
        if (!canSend(context)) return emptyList()
        val sms: SmsManager = if (Build.VERSION.SDK_INT >= 31) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val parts = sms.divideMessage(text)
        return numbers.filter { number ->
            try {
                sms.sendMultipartTextMessage(number, null, parts, null, null)
                true
            } catch (e: Exception) {
                Log.w("HeatSms", "send", e)
                false
            }
        }
    }
}
