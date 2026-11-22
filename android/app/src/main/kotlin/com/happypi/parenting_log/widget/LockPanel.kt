package com.happypi.parenting_log.widget

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.happypi.parenting_log.R

/**
 * 잠금화면 빠른 기록. iPhone의 실시간 현황(Live Activity)에 해당하는 안드로이드 방식으로,
 * 지워지지 않는 조용한 알림에 상태와 원클릭 버튼 6개를 띄운다. 잠금화면에서도 보이고 누를 수 있다
 * (휴대폰 설정 › 잠금화면 › 알림에서 "내용 모두 표시"일 때).
 *
 * 켜기/끄기는 앱 설정 › 위젯 › "잠금화면 빠른 기록"(WidgetConfig.lockPanel).
 */
object LockPanel {
    private const val CHANNEL_ID = "quick_panel"
    private const val NOTIF_ID = 2701

    fun canPost(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    fun refresh(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        val cfg = WidgetData.config(context)
        if (!cfg.lockPanel || !canPost(context)) {
            nm.cancel(NOTIF_ID)
            return
        }
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "잠금화면 빠른 기록", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "잠금화면에서 수유·기저귀·수면을 바로 기록하는 패널"
                    setShowBadge(false)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
            )
        }
        val st = WidgetData.status(context, cfg)
        val small = RemoteViews(context.packageName, R.layout.notif_panel_small)
        val big = RemoteViews(context.packageName, R.layout.notif_panel)
        for (rv in listOf(small, big)) fillLine(context, rv, cfg, st)
        WidgetRender.fillButtons(context, big)
        // 접힌 모양에는 자주 쓰는 3개만(분유·소변·수면).
        val (sleeping, _) = QuickLog.running(context)
        small.setTextViewText(R.id.qb_sleep, if (sleeping) "깼어요" else "수면")
        small.setOnClickPendingIntent(R.id.qb_formula, WidgetRender.quickIntent(context, QuickKind.FORMULA))
        small.setOnClickPendingIntent(R.id.qb_pee, WidgetRender.quickIntent(context, QuickKind.PEE))
        small.setOnClickPendingIntent(R.id.qb_sleep, WidgetRender.quickIntent(context, QuickKind.SLEEP))

        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID) else Notification.Builder(context)
        b.setSmallIcon(R.drawable.ic_shortcut_mic)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentTitle("${cfg.babyName} 빠른 기록")
            .setContentIntent(WidgetRender.openApp(context))
            .setCustomContentView(small)
            .setCustomBigContentView(big)
            .setStyle(Notification.DecoratedCustomViewStyle())
        try {
            nm.notify(NOTIF_ID, b.build())
        } catch (e: SecurityException) {
            // 알림 권한이 없으면 조용히 넘어간다(앱이 권한을 요청한다).
        }
    }

    /** "튼튼이 D+262 · 수유 23:37 전 · 수면 0:47 전" 한 줄. */
    private fun fillLine(context: Context, rv: RemoteViews, cfg: WidgetConfig, st: Status) {
        val nowWall = System.currentTimeMillis()
        val nowElapsed = SystemClock.elapsedRealtime()
        val dd = WidgetData.ddays(cfg)
        rv.setTextViewText(R.id.np_title, if (dd != null) "${cfg.babyName} D+$dd" else cfg.babyName)
        if (st.lastFeedMs != null) {
            rv.setViewVisibility(R.id.np_feed, View.VISIBLE)
            rv.setChronometer(R.id.np_feed, nowElapsed - (nowWall - st.lastFeedMs), "${st.feedLabel ?: "수유"} %s 전", true)
        } else {
            rv.setViewVisibility(R.id.np_feed, View.GONE)
        }
        if (st.sleepMs != null) {
            rv.setViewVisibility(R.id.np_sleep, View.VISIBLE)
            rv.setChronometer(R.id.np_sleep, nowElapsed - (nowWall - st.sleepMs), "${st.sleepLabel ?: "수면"} %s 전", true)
        } else {
            rv.setViewVisibility(R.id.np_sleep, View.GONE)
        }
    }
}
