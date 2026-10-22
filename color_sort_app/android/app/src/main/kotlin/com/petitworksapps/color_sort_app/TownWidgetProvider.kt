package com.petitworksapps.color_sort_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import java.io.File

/** ホーム画面ウィジェット。アプリが書き出した町の絵を見せ、タップでアプリを開く。 */
class TownWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, views(context))
    }

    companion object {
        private const val FILE = "town_widget.png"

        /** 受け取った絵を保存し、置いてあるウィジェットを更新する。 */
        fun save(context: Context, png: ByteArray) {
            File(context.filesDir, FILE).writeBytes(png)
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TownWidgetProvider::class.java))
            for (id in ids) manager.updateAppWidget(id, views(context))
        }

        private fun views(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.town_widget)
            val file = File(context.filesDir, FILE)
            if (file.exists()) {
                // ウィジェットの転送上限を超えないよう、縮めて読む。
                val opts = BitmapFactory.Options().apply { inSampleSize = 2 }
                BitmapFactory.decodeFile(file.path, opts)?.let { views.setImageViewBitmap(R.id.town_image, it) }
            }
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pending = PendingIntent.getActivity(
                    context, 0, launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.town_root, pending)
            }
            return views
        }
    }
}
