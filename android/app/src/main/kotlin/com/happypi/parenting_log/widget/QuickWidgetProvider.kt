package com.happypi.parenting_log.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.happypi.parenting_log.R

/**
 * 튼튼이 빠른 기록 (4×2). 왼쪽 상태(아기 이름·D+ / 수유·수면 경과), 오른쪽 원클릭 버튼 6개.
 * 버튼을 누르면 앱을 열지 않고 바로 저장된다(QuickLog).
 */
class QuickWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val cfg = WidgetData.config(context)
        val st = WidgetData.status(context, cfg)
        val p = WidgetRender.palette(context, cfg)
        for (id in ids) {
            val rv = RemoteViews(context.packageName, R.layout.widget_quick)
            rv.setInt(R.id.qw_root, "setBackgroundResource", p.bgRes)
            WidgetRender.fillStatus(context, rv, cfg, st, p)
            WidgetRender.fillButtons(context, rv)
            rv.setOnClickPendingIntent(R.id.st_block, WidgetRender.openApp(context))
            manager.updateAppWidget(id, rv)
        }
        WidgetRender.scheduleRefresh(context, st.nextFeedMs)
    }
}
