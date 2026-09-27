package com.happypi.parenting_log.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.happypi.parenting_log.MainActivity
import com.happypi.parenting_log.R

/** 위젯 공통: 색·글자, 상태 블록(이름/D+/수유/다음 수유/수면) 채우기, 탭 동작. */
object WidgetRender {
    data class Palette(val bgRes: Int, val fg: Int, val dim: Int)

    fun palette(context: Context, cfg: WidgetConfig): Palette {
        val dark = when (cfg.theme) {
            "light" -> false
            "system" -> (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            else -> true
        }
        return if (dark) Palette(R.drawable.widget_bg_dark, 0xFFFFFFFF.toInt(), 0x99FFFFFF.toInt())
        else Palette(R.drawable.widget_bg_light, 0xFF1B1B1F.toInt(), 0x8A000000.toInt())
    }

    /**
     * 두 번째 캡처와 같은 모양:
     *   튼튼이            D+248
     *   모유  48:14 전
     *    → 3:35:12 남음
     *   밤잠  47:48 전
     * 안드로이드 위젯은 초 단위로 움직이는 글자를 Chronometer로만 만들 수 있어
     * "48분 14초" 대신 "48:14" 표기가 된다.
     */
    fun fillStatus(context: Context, rv: RemoteViews, cfg: WidgetConfig, st: Status, p: Palette) {
        val nowWall = System.currentTimeMillis()
        val nowElapsed = SystemClock.elapsedRealtime()
        fun base(wallMs: Long) = nowElapsed - (nowWall - wallMs)

        rv.setTextViewText(R.id.st_name, cfg.babyName)
        rv.setViewVisibility(R.id.st_name, if (cfg.showName) View.VISIBLE else View.GONE)
        val dd = WidgetData.ddays(cfg)
        rv.setTextViewText(R.id.st_dday, if (dd != null) "D+$dd" else "")
        rv.setViewVisibility(R.id.st_dday, if (cfg.showDday && dd != null) View.VISIBLE else View.GONE)
        rv.setViewVisibility(R.id.st_head, if (cfg.showName || cfg.showDday) View.VISIBLE else View.GONE)

        // 수유
        if (cfg.showFeeding && st.lastFeedMs != null) {
            rv.setViewVisibility(R.id.st_feed_row, View.VISIBLE)
            rv.setTextViewText(R.id.st_feed_label, st.feedLabel ?: "수유")
            rv.setChronometer(R.id.st_feed_chrono, base(st.lastFeedMs), "%s 전", true)
        } else if (cfg.showFeeding) {
            rv.setViewVisibility(R.id.st_feed_row, View.VISIBLE)
            rv.setTextViewText(R.id.st_feed_label, "수유 기록 없음")
            rv.setChronometer(R.id.st_feed_chrono, nowElapsed, "", false)
            rv.setViewVisibility(R.id.st_feed_chrono, View.GONE)
        } else {
            rv.setViewVisibility(R.id.st_feed_row, View.GONE)
        }

        // 다음 수유
        val next = st.nextFeedMs
        if (cfg.showFeeding && cfg.showNextFeed && next != null) {
            rv.setViewVisibility(R.id.st_next_chrono, View.VISIBLE)
            if (next > nowWall && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                rv.setChronometerCountDown(R.id.st_next_chrono, true)
                rv.setChronometer(R.id.st_next_chrono, base(next), "→ %s 남음", true)
            } else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) rv.setChronometerCountDown(R.id.st_next_chrono, false)
                rv.setChronometer(R.id.st_next_chrono, base(next), "→ %s 지남", true)
            }
        } else {
            rv.setViewVisibility(R.id.st_next_chrono, View.GONE)
        }

        // 수면
        if (cfg.showSleep && st.sleepMs != null) {
            rv.setViewVisibility(R.id.st_sleep_row, View.VISIBLE)
            rv.setTextViewText(R.id.st_sleep_label, st.sleepLabel ?: "수면")
            rv.setChronometer(R.id.st_sleep_chrono, base(st.sleepMs), "%s 전", true)
        } else {
            rv.setViewVisibility(R.id.st_sleep_row, View.GONE)
        }

        for (id in intArrayOf(R.id.st_name, R.id.st_feed_label, R.id.st_feed_chrono, R.id.st_sleep_label, R.id.st_sleep_chrono)) {
            rv.setTextColor(id, p.fg)
        }
        rv.setTextColor(R.id.st_dday, p.dim)
        rv.setTextColor(R.id.st_next_chrono, p.dim)
    }

    fun openApp(context: Context): PendingIntent {
        val i = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(context, 1, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    fun openVoice(context: Context): PendingIntent {
        val i = Intent(Intent.ACTION_VIEW, Uri.parse("tunteuni://voice"), context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(context, 2, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    /** "남음 → 지남" 전환 시각에 위젯을 한 번 더 그리게 예약한다(정확하지 않아도 됨). */
    fun scheduleRefresh(context: Context, atWallMs: Long?) {
        if (atWallMs == null || atWallMs <= System.currentTimeMillis()) return
        val am = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val i = Intent(context, StatusWidgetProvider::class.java).setAction(ACTION_REFRESH)
        val pi = PendingIntent.getBroadcast(context, 3, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        am.set(android.app.AlarmManager.RTC, atWallMs + 1000, pi)
    }

    const val ACTION_REFRESH = "com.happypi.parenting_log.widget.REFRESH"

    /** 앱이 기록·일정·설정을 바꿨을 때 모든 위젯을 다시 그린다. */
    fun updateAll(context: Context) {
        val m = AppWidgetManager.getInstance(context)
        for (cls in listOf(StatusWidgetProvider::class.java, CalendarWidgetProvider::class.java)) {
            val ids = m.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isEmpty()) continue
            context.sendBroadcast(
                Intent(context, cls)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }
    }
}
