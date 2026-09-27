package com.happypi.parenting_log.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.happypi.parenting_log.R
import java.util.Calendar

/**
 * 달력 위젯 (4×4). 광고 캡처 구성처럼
 *   ┌ 오늘 일정 ┐┌ 튼튼이 상태(두 번째 캡처) ┐
 *   └──────────┘└──────────────────────┘
 *   일 월 화 수 목 금 토 + 이번 달 6주 그리드(일정 막대)
 */
class CalendarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val cfg = WidgetData.config(context)
        val p = WidgetRender.palette(context, cfg)
        val st = WidgetData.status(context, cfg)

        val now = Calendar.getInstance()
        val today = (now.clone() as Calendar).apply { clearTime() }
        val first = (today.clone() as Calendar).apply { set(Calendar.DAY_OF_MONTH, 1) }
        val gridStart = (first.clone() as Calendar).apply {
            add(Calendar.DAY_OF_MONTH, -(get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY))
        }
        val gridEnd = (gridStart.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, 42) }
        val events = WidgetData.events(context, gridStart.timeInMillis, gridEnd.timeInMillis)

        for (id in ids) {
            val rv = RemoteViews(context.packageName, R.layout.widget_calendar)
            rv.setInt(R.id.cal_root, "setBackgroundResource", p.bgRes)
            rv.setOnClickPendingIntent(R.id.cal_root, WidgetRender.openApp(context))

            // 왼쪽 위: 오늘 날짜 + 오늘 일정
            val dow = "일월화수목금토"[today.get(Calendar.DAY_OF_WEEK) - 1]
            rv.setTextViewText(R.id.cal_title, "${today.get(Calendar.MONTH) + 1}월 ${today.get(Calendar.DAY_OF_MONTH)}일 ${dow}요일")
            rv.setTextColor(R.id.cal_title, p.fg)
            rv.removeAllViews(R.id.cal_today)
            val tStart = today.timeInMillis
            val tEnd = tStart + 86_400_000L
            val todays = events.filter { dayOverlaps(it, tStart, tEnd) }
            if (cfg.calendarShowToday) {
                rv.setViewVisibility(R.id.cal_today, View.VISIBLE)
                if (todays.isEmpty()) {
                    rv.addView(R.id.cal_today, line(context, "오늘 일정 없음", p.dim, null))
                }
                for (e in todays.take(4)) {
                    val time = if (e.allDay) "종일" else hm(e.startMs)
                    rv.addView(R.id.cal_today, line(context, "$time  ${e.title}", p.fg, e.color))
                }
            } else {
                rv.setViewVisibility(R.id.cal_today, View.GONE)
            }

            // 오른쪽 위: 튼튼이 상태 (끄면 다가오는 일정)
            if (cfg.calendarShowStatus) {
                rv.setViewVisibility(R.id.st_block, View.VISIBLE)
                rv.setViewVisibility(R.id.cal_upcoming, View.GONE)
                WidgetRender.fillStatus(context, rv, cfg, st, p)
            } else {
                rv.setViewVisibility(R.id.st_block, View.GONE)
                rv.setViewVisibility(R.id.cal_upcoming, View.VISIBLE)
                rv.removeAllViews(R.id.cal_upcoming)
                val upcoming = WidgetData.events(context, tEnd, tEnd + 14 * 86_400_000L)
                if (upcoming.isEmpty()) rv.addView(R.id.cal_upcoming, line(context, "앞으로 2주 일정 없음", p.dim, null))
                for (e in upcoming.take(4)) {
                    val c = Calendar.getInstance().apply { timeInMillis = e.startMs }
                    rv.addView(R.id.cal_upcoming, line(context, "${c.get(Calendar.MONTH) + 1}/${c.get(Calendar.DAY_OF_MONTH)}  ${e.title}", p.fg, e.color))
                }
            }

            // 요일 머리
            val heads = intArrayOf(R.id.wd0, R.id.wd1, R.id.wd2, R.id.wd3, R.id.wd4, R.id.wd5, R.id.wd6)
            for ((i, h) in heads.withIndex()) {
                rv.setTextColor(h, when (i) { 0 -> SUN; 6 -> SAT; else -> p.dim })
            }

            // 6주 그리드
            rv.removeAllViews(R.id.cal_grid)
            val day = gridStart.clone() as Calendar
            for (w in 0 until 6) {
                val row = RemoteViews(context.packageName, R.layout.widget_cal_row)
                for (d in 0 until 7) {
                    val cell = RemoteViews(context.packageName, R.layout.widget_cal_cell)
                    val s = day.timeInMillis
                    val e = s + 86_400_000L
                    val inMonth = day.get(Calendar.MONTH) == today.get(Calendar.MONTH)
                    val isToday = s == today.timeInMillis
                    cell.setTextViewText(R.id.cell_day, day.get(Calendar.DAY_OF_MONTH).toString())
                    val numColor = when (d) { 0 -> SUN; 6 -> SAT; else -> p.fg }
                    cell.setTextColor(R.id.cell_day, if (inMonth) numColor else p.dim)
                    if (isToday) cell.setInt(R.id.cell_day, "setBackgroundResource", R.drawable.widget_today_dot)
                    val dayEvents = events.filter { dayOverlaps(it, s, e) }
                    for (ev in dayEvents.take(2)) {
                        val bar = RemoteViews(context.packageName, R.layout.widget_cal_event)
                        bar.setTextViewText(R.id.ev_text, ev.title)
                        bar.setInt(R.id.ev_text, "setBackgroundColor", ev.color)
                        cell.addView(R.id.cell_events, bar)
                    }
                    if (dayEvents.size > 2) {
                        val more = RemoteViews(context.packageName, R.layout.widget_cal_event)
                        more.setTextViewText(R.id.ev_text, "+${dayEvents.size - 2}")
                        more.setTextColor(R.id.ev_text, p.dim)
                        cell.addView(R.id.cell_events, more)
                    }
                    row.addView(R.id.cal_row, cell)
                    day.add(Calendar.DAY_OF_MONTH, 1)
                }
                rv.addView(R.id.cal_grid, row)
            }
            manager.updateAppWidget(id, rv)
        }
    }

    private fun dayOverlaps(e: WidgetEvent, dayStart: Long, dayEnd: Long): Boolean {
        val s = Calendar.getInstance().apply { timeInMillis = e.startMs; clearTime() }.timeInMillis
        return s < dayEnd && e.endMs >= dayStart
    }

    private fun hm(ms: Long): String {
        val c = Calendar.getInstance().apply { timeInMillis = ms }
        return "%02d:%02d".format(c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    private fun line(context: Context, text: String, color: Int, dot: Int?): RemoteViews {
        val rv = RemoteViews(context.packageName, R.layout.widget_line)
        rv.setTextViewText(R.id.line_text, text)
        rv.setTextColor(R.id.line_text, color)
        if (dot != null) {
            rv.setInt(R.id.line_dot, "setBackgroundColor", dot)
        } else {
            rv.setViewVisibility(R.id.line_dot, View.GONE)
        }
        return rv
    }

    companion object {
        private const val SUN = 0xFFE0685A.toInt()
        private const val SAT = 0xFF5B8FD9.toInt()
    }
}
