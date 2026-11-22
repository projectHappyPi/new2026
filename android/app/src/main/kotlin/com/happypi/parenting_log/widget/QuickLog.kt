package com.happypi.parenting_log.widget

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.Toast
import org.json.JSONObject
import java.util.Calendar
import java.util.UUID

/**
 * 위젯·잠금화면 알림의 "원클릭 기록". 앱을 열지 않고 앱 DB(activities)에 바로 쓴다.
 *
 * 규칙은 앱의 버튼 짧게 누르기와 같다(lib/features/record/record_screen.dart):
 *   분유 → 기본 용량 저장 · 기저귀 → 소변/대변 저장 · 이유식 → 마지막 식재료로 저장
 *   수면·모유 → 진행 중이면 종료, 아니면 시작(수면은 20시 이후 밤잠)
 * 쓰고 나면 위젯과 잠금화면 패널을 다시 그린다. 앱은 다시 열릴 때(resume) 이 변경을 읽고,
 * 가족 공유가 켜져 있으면 updated_at 이 바뀐 행이라 다음 동기화 때 서버로 올라간다.
 */
enum class QuickKind(val label: String) {
    FORMULA("분유"), BREAST("모유"), SOLID("이유식"), PEE("소변"), POOP("대변"), SLEEP("수면");

    companion object {
        fun of(name: String?): QuickKind? = values().firstOrNull { it.name == name }
    }
}

object QuickLog {
    const val ACTION = "com.happypi.parenting_log.QUICK_LOG"
    const val EXTRA_KIND = "kind"

    /** @return 사용자에게 보여줄 한 줄(예: "분유 150ml 기록했어요"), 실패하면 이유. */
    fun log(context: Context, kind: QuickKind): String {
        val cfg = WidgetData.config(context)
        val f = WidgetData.dbFile(context)
        if (!f.exists()) return "튼튼이 앱을 한 번 먼저 열어 주세요"
        return try {
            SQLiteDatabase.openDatabase(f.path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                db.rawQuery("PRAGMA busy_timeout = 3000", null).use { it.moveToFirst() }
                write(db, cfg, kind)
            }
        } catch (e: Exception) {
            "기록하지 못했어요 (${e.message ?: "DB 오류"})"
        } finally {
            WidgetRender.updateAll(context)
            LockPanel.refresh(context)
        }
    }

    private fun write(db: SQLiteDatabase, cfg: WidgetConfig, kind: QuickKind): String {
        val now = System.currentTimeMillis() / 1000
        when (kind) {
            QuickKind.SLEEP, QuickKind.BREAST -> {
                val type = if (kind == QuickKind.SLEEP) "sleep" else "breast"
                val running = runningId(db, type)
                if (running != null) {
                    db.execSQL(
                        "UPDATE activities SET ended_at = ?, updated_at = ? WHERE id = ?",
                        arrayOf<Any>(now, now, running.first),
                    )
                    val min = (now - running.second) / 60
                    val dur = if (min >= 60) "${min / 60}시간 ${min % 60}분" else "${min}분"
                    return "${kind.label} 종료 · $dur"
                }
                val payload = JSONObject().put("via", "widget")
                var label = kind.label
                if (kind == QuickKind.SLEEP) {
                    val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                    val period = if (hour >= 20) "night" else "nap"
                    payload.put("period", period)
                    label = if (period == "night") "밤잠" else "낮잠"
                }
                insert(db, cfg, type, now, payload)
                return "$label 시작"
            }
            QuickKind.FORMULA -> {
                insert(db, cfg, "formula", now, JSONObject().put("ml", cfg.formulaMl).put("via", "widget"))
                return "분유 ${cfg.formulaMl}ml 기록했어요"
            }
            QuickKind.PEE, QuickKind.POOP -> {
                val p = JSONObject().put("sub", if (kind == QuickKind.PEE) "pee" else "poop").put("via", "widget")
                if (kind == QuickKind.POOP) p.put("texture", "보통")
                insert(db, cfg, "diaper", now, p)
                return "${kind.label} 기록했어요"
            }
            QuickKind.SOLID -> {
                val food = lastFood(db) ?: "쌀미음"
                insert(db, cfg, "solid", now, JSONObject().put("food", food).put("amount", "보통").put("via", "widget"))
                return "이유식($food) 기록했어요"
            }
        }
    }

    private fun insert(db: SQLiteDatabase, cfg: WidgetConfig, type: String, now: Long, payload: JSONObject) {
        val v = ContentValues().apply {
            put("id", UUID.randomUUID().toString())
            put("type", type)
            put("started_at", now)
            putNull("ended_at")
            put("payload", payload.toString())
            put("created_by", cfg.memberName)
            put("created_at", now)
            put("updated_at", now)
            putNull("deleted_at")
        }
        db.insertOrThrow("activities", null, v)
    }

    /** 진행 중(ended_at IS NULL)인 가장 최근 기록의 (id, 시작 초). */
    fun runningId(db: SQLiteDatabase, type: String): Pair<String, Long>? =
        db.rawQuery(
            "SELECT id, started_at FROM activities WHERE type = ? AND ended_at IS NULL AND deleted_at IS NULL " +
                "ORDER BY started_at DESC LIMIT 1",
            arrayOf(type),
        ).use { c -> if (c.moveToFirst()) c.getString(0) to c.getLong(1) else null }

    private fun lastFood(db: SQLiteDatabase): String? =
        db.rawQuery(
            "SELECT payload FROM activities WHERE type = 'solid' AND deleted_at IS NULL ORDER BY started_at DESC LIMIT 1",
            null,
        ).use { c ->
            if (!c.moveToFirst()) return null
            try { JSONObject(c.getString(0)).optString("food").ifEmpty { null } } catch (e: Exception) { null }
        }

    /** 진행 중인 모유·수면이 있는지(버튼 글자를 "수면 끝"처럼 바꾸는 데 쓴다). */
    fun running(context: Context): Pair<Boolean, Boolean> {
        val f = WidgetData.dbFile(context)
        if (!f.exists()) return false to false
        return try {
            SQLiteDatabase.openDatabase(f.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                (runningId(db, "sleep") != null) to (runningId(db, "breast") != null)
            }
        } catch (e: Exception) {
            false to false
        }
    }
}

/** 위젯·알림 버튼 → 여기로 온다. */
class QuickLogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != QuickLog.ACTION) return
        val kind = QuickKind.of(intent.getStringExtra(QuickLog.EXTRA_KIND)) ?: return
        val pending = goAsync()
        Thread {
            try {
                val msg = QuickLog.log(context.applicationContext, kind)
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    Toast.makeText(context.applicationContext, msg, Toast.LENGTH_SHORT).show()
                }
            } finally {
                pending.finish()
            }
        }.start()
    }
}
