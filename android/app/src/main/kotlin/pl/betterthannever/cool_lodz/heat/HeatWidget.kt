package pl.betterthannever.cool_lodz.heat

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import pl.betterthannever.cool_lodz.MainActivity
import pl.betterthannever.cool_lodz.R

/**
 * Home-screen widget: today's heat risk and the best hours to go out.
 * Written by the app (`updateWidget`) and by the 7:00 job.
 */
object HeatWidget {
    private const val PREFS = "heat_widget"
    private val COLORS = intArrayOf(0xFF2E7D32.toInt(), 0xFFF9A825.toInt(), 0xFFEF6C00.toInt(), 0xFFC62828.toInt())

    fun save(context: Context, level: Int, title: String, line: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putInt("level", level.coerceIn(0, 3))
            .putString("title", title)
            .putString("line", line)
            .apply()
        refresh(context)
    }

    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, HeatWidgetProvider::class.java))
        if (ids.isNotEmpty()) update(context, manager, ids)
    }

    fun update(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val level = p.getInt("level", 0)
        val views = RemoteViews(context.packageName, R.layout.heat_widget).apply {
            setTextViewText(R.id.heat_widget_title, p.getString("title", null) ?: "Cool Łódź")
            setTextViewText(R.id.heat_widget_line, p.getString("line", null) ?: "Otwórz aplikację, aby sprawdzić upał")
            setInt(R.id.heat_widget_bar, "setBackgroundColor", COLORS[level])
            val open = PendingIntent.getActivity(
                context,
                7,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            setOnClickPendingIntent(R.id.heat_widget_root, open)
        }
        manager.updateAppWidget(ids, views)
    }
}

class HeatWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) =
        HeatWidget.update(context, manager, ids)
}
