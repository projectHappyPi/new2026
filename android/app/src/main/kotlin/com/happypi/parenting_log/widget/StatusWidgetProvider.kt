package com.happypi.parenting_log.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.happypi.parenting_log.R

/** 튼튼이 상태 위젯 (2×2 · 4×2). */
class StatusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val cfg = WidgetData.config(context)
        val st = WidgetData.status(context, cfg)
        val p = WidgetRender.palette(context, cfg)
        for (id in ids) {
            val rv = RemoteViews(context.packageName, R.layout.widget_status)
            rv.setInt(R.id.st_root, "setBackgroundResource", p.bgRes)
            WidgetRender.fillStatus(context, rv, cfg, st, p)
            rv.setOnClickPendingIntent(R.id.st_root, WidgetRender.openApp(context))
            rv.setOnClickPendingIntent(R.id.st_mic, WidgetRender.openVoice(context))
            rv.setInt(R.id.st_mic, "setColorFilter", p.dim)
            manager.updateAppWidget(id, rv)
        }
        WidgetRender.scheduleRefresh(context, st.nextFeedMs)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetRender.ACTION_REFRESH) WidgetRender.updateAll(context)
    }
}
