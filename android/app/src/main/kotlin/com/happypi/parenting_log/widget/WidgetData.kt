package com.happypi.parenting_log.widget

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import java.io.File
import java.util.Calendar

/**
 * 위젯이 읽는 데이터. 앱의 drift DB 파일(app_flutter/parenting_log.sqlite)을
 * 읽기 전용으로 직접 열고, 위젯 설정은 앱이 위젯 채널로 넘겨준 JSON을 쓴다.
 *
 * 계산 규칙은 lib/features/widgets/widget_status.dart 와 같다.
 */
data class WidgetConfig(
    val showName: Boolean = true,
    val showDday: Boolean = true,
    val showFeeding: Boolean = true,
    val genericFeedLabel: Boolean = false,
    val showNextFeed: Boolean = true,
    val autoNextFeed: Boolean = true,
    val fixedIntervalMin: Int = 180,
    val showSleep: Boolean = true,
    val calendarShowStatus: Boolean = true,
    val calendarShowToday: Boolean = true,
    val theme: String = "dark",
    val babyName: String = "튼튼이",
    val birthDateSec: Long? = null,
) {
    companion object {
        fun from(json: String?): WidgetConfig {
            if (json.isNullOrEmpty()) return WidgetConfig()
            return try {
                val j = JSONObject(json)
                WidgetConfig(
                    showName = j.optBoolean("showName", true),
                    showDday = j.optBoolean("showDday", true),
                    showFeeding = j.optBoolean("showFeeding", true),
                    genericFeedLabel = j.optString("feedLabel") == "generic",
                    showNextFeed = j.optBoolean("showNextFeed", true),
                    autoNextFeed = j.optString("nextFeedMode", "auto") != "fixed",
                    fixedIntervalMin = j.optInt("fixedIntervalMin", 180),
                    showSleep = j.optBoolean("showSleep", true),
                    calendarShowStatus = j.optBoolean("calendarShowStatus", true),
                    calendarShowToday = j.optBoolean("calendarShowToday", true),
                    theme = j.optString("theme", "dark"),
                    babyName = j.optString("babyName").ifEmpty { "튼튼이" },
                    birthDateSec = if (j.isNull("birthDateSec")) null else j.optLong("birthDateSec"),
                )
            } catch (e: Exception) {
                WidgetConfig()
            }
        }
    }
}

data class Status(
    val feedLabel: String? = null,
    val lastFeedMs: Long? = null,
    val nextFeedMs: Long? = null,
    val sleepLabel: String? = null,
    val sleepMs: Long? = null,
    val sleeping: Boolean = false,
)

data class WidgetEvent(
    val title: String,
    val startMs: Long,
    val endMs: Long,
    val allDay: Boolean,
    val color: Int,
)

object WidgetData {
    const val PREFS = "tunteuni_widget"
    const val KEY_CONFIG = "config"

    fun config(context: Context): WidgetConfig =
        WidgetConfig.from(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_CONFIG, null))

    /** path_provider의 getApplicationDocumentsDirectory() = getDir("flutter"). */
    private fun dbFile(context: Context) =
        File(context.getDir("flutter", Context.MODE_PRIVATE), "parenting_log.sqlite")

    private fun <T> withDb(context: Context, fallback: T, block: (SQLiteDatabase) -> T): T {
        val f = dbFile(context)
        if (!f.exists()) return fallback
        return try {
            SQLiteDatabase.openDatabase(f.path, null, SQLiteDatabase.OPEN_READONLY).use(block)
        } catch (e: Exception) {
            fallback
        }
    }

    fun ddays(cfg: WidgetConfig, nowMs: Long = System.currentTimeMillis()): Int? {
        val b = cfg.birthDateSec ?: return null
        val birth = Calendar.getInstance().apply { timeInMillis = b * 1000; clearTime() }
        val today = Calendar.getInstance().apply { timeInMillis = nowMs; clearTime() }
        return Math.round((today.timeInMillis - birth.timeInMillis) / 86_400_000.0).toInt()
    }

    fun status(context: Context, cfg: WidgetConfig, nowMs: Long = System.currentTimeMillis()): Status =
        withDb(context, Status()) { db ->
            val since = nowMs / 1000 - 3 * 86_400
            // 수유 대표 시각: 모유는 끝났으면 종료, 분유는 기록 시각.
            val feeds = mutableListOf<Pair<String, Long>>()
            db.rawQuery(
                "SELECT type, started_at, ended_at FROM activities " +
                    "WHERE deleted_at IS NULL AND type IN ('formula','breast') AND started_at >= ?",
                arrayOf(since.toString()),
            ).use { c ->
                while (c.moveToNext()) {
                    val type = c.getString(0)
                    val ref = if (type == "breast" && !c.isNull(2)) c.getLong(2) else c.getLong(1)
                    feeds += type to ref * 1000
                }
            }
            feeds.sortBy { it.second }
            var feedLabel: String? = null
            var last: Long? = null
            var next: Long? = null
            if (feeds.isNotEmpty()) {
                val (type, ref) = feeds.last()
                last = ref
                feedLabel = if (cfg.genericFeedLabel) "수유" else if (type == "breast") "모유" else "분유"
                var interval = cfg.fixedIntervalMin * 60_000L
                if (cfg.autoNextFeed && feeds.size >= 2) {
                    val tail = feeds.takeLast(4).map { it.second }
                    interval = (tail.last() - tail.first()) / (tail.size - 1)
                }
                next = ref + interval
            }

            var sleepLabel: String? = null
            var sleepMs: Long? = null
            var sleeping = false
            db.rawQuery(
                "SELECT started_at, ended_at, payload FROM activities " +
                    "WHERE deleted_at IS NULL AND type = 'sleep' ORDER BY started_at DESC LIMIT 1",
                null,
            ).use { c ->
                if (c.moveToFirst()) {
                    if (c.isNull(1)) {
                        sleeping = true
                        sleepMs = c.getLong(0) * 1000
                        val period = try { JSONObject(c.getString(2)).optString("period") } catch (e: Exception) { "" }
                        val hour = Calendar.getInstance().apply { timeInMillis = sleepMs!! }.get(Calendar.HOUR_OF_DAY)
                        sleepLabel = when (period) {
                            "night" -> "밤잠"
                            "nap" -> "낮잠"
                            else -> if (hour >= 20) "밤잠" else "낮잠"
                        }
                    } else {
                        sleepLabel = "기상"
                        sleepMs = c.getLong(1) * 1000
                    }
                }
            }
            Status(feedLabel, last, next, sleepLabel, sleepMs, sleeping)
        }

    /** [fromMs, toMs) 에 걸친 일정. */
    fun events(context: Context, fromMs: Long, toMs: Long): List<WidgetEvent> =
        withDb(context, emptyList()) { db ->
            val out = mutableListOf<WidgetEvent>()
            try {
                db.rawQuery(
                    "SELECT title, start_at, end_at, all_day, color FROM events " +
                        "WHERE deleted_at IS NULL AND start_at < ? AND COALESCE(end_at, start_at) >= ? " +
                        "ORDER BY all_day DESC, start_at",
                    arrayOf((toMs / 1000).toString(), (fromMs / 1000).toString()),
                ).use { c ->
                    while (c.moveToNext()) {
                        val s = c.getLong(1) * 1000
                        out += WidgetEvent(
                            title = c.getString(0),
                            startMs = s,
                            endMs = if (c.isNull(2)) s else c.getLong(2) * 1000,
                            allDay = c.getInt(3) == 1,
                            color = eventColor(c.getString(4)),
                        )
                    }
                }
            } catch (e: Exception) {
                // 앱 업데이트 전(events 테이블 없음)
            }
            out
        }

    /** lib/data/models/calendar_event.dart EventColor 와 같은 값. */
    fun eventColor(name: String?): Int = when (name) {
        "red" -> 0xFFE0685A.toInt()
        "orange" -> 0xFFE59A4E.toInt()
        "yellow" -> 0xFFD9B44A.toInt()
        "green" -> 0xFF6FAF72.toInt()
        "teal" -> 0xFF4FA8A0.toInt()
        "purple" -> 0xFF9A7BD1.toInt()
        "pink" -> 0xFFD97FA7.toInt()
        else -> 0xFF5B8FD9.toInt()
    }
}

fun Calendar.clearTime() {
    set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
}
