package app.ember.ideas.data

import app.ember.ideas.ai.Protocol
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import java.io.File

// ------------------------------------------------------------------ 원석(메모)

/** 원석함에 적어 둔 메모. 나중에 이 원석으로 아이디어 탐색을 시작할 수 있다. */
@Serializable
data class Memo(
    val id: String,
    val text: String,
    val tags: List<String> = emptyList(),
    val pinned: Boolean = false,
    /** 함께 붙인 사진(앱 저장소 경로). */
    val imagePath: String? = null,
    val createdAt: Long,
    val updatedAt: Long = createdAt,
    /** 이 원석으로 시작한 프로젝트 id. */
    val projectIds: List<String> = emptyList(),
) {
    companion object {
        /** 본문에서 #태그를 뽑는다. */
        fun tagsIn(text: String): List<String> =
            Regex("#([\\p{L}\\p{N}_]{1,20})").findAll(text).map { it.groupValues[1] }.distinct().take(6).toList()
    }
}

// ------------------------------------------------------------------ 거푸집(미리 정한 답)

/** 질문을 얼마나 길게 이어 갈지. */
@Serializable
enum class DepthMode(val questions: Int) { SHORT(5), NORMAL(9), LONG(0) }

/**
 * 거푸집: 자주 쓰는 답을 미리 정해 둔 묶음. 정한 갈래는 질문하지 않고 건너뛴다.
 * [picks] 는 갈래 키 → 고른 값(화면 언어 그대로). 직접 입력한 값도 그대로 들어간다.
 */
@Serializable
data class Mold(
    val id: String,
    val name: String,
    val picks: Map<String, String> = emptyMap(),
    val depth: DepthMode? = null,
    /** 무엇을 만들지(게임/앱/웹/미정)까지 정해 두었으면 그 값. */
    val kind: ProjectKind? = null,
    val createdAt: Long,
    val usedCount: Int = 0,
)

/** 프로젝트를 시작할 때 미리 정해 둔 답 하나(화면에 '거푸집' 단조판으로 보인다). */
@Serializable
data class PresetAnswer(val category: String, val value: String)

/** 거푸집에서 고를 수 있는 갈래와 선택지. 언어별로 따로 둔다. */
object MoldCatalog {
    data class Category(val key: String, val title: String, val hint: String, val options: List<String>)

    fun categories(korean: Boolean): List<Category> = if (korean) listOf(
        Category("purpose", "목적", "왜 만드나요", listOf("바이브 코딩", "개인 개발", "포트폴리오", "출시·수익", "게임잼", "공부")),
        Category("method", "만드는 방식", "코드는 누가", listOf("AI에게 맡김", "AI와 함께", "직접", "팀으로")),
        Category("platform", "플랫폼", "", listOf("모바일", "PC", "웹", "콘솔")),
        Category("genre", "장르", "", listOf("퍼즐", "로그라이크", "시뮬레이션", "리듬", "내러티브", "액션", "생산성", "커뮤니티")),
        Category("theme", "테마", "세계와 소재", listOf("판타지", "SF", "일상", "호러", "동화", "역사")),
        Category("mood", "분위기", "", listOf("아늑함", "몽환적", "긴장감", "유쾌함", "쓸쓸함")),
        Category("scope", "규모", "", listOf("주말", "1개월", "3개월", "6개월 이상")),
        Category("engine", "엔진·기술", "", listOf("Godot", "Unity", "Unreal", "웹(JS)", "Flutter", "Kotlin")),
    ) else listOf(
        Category("purpose", "Purpose", "Why build it", listOf("Vibe coding", "Personal project", "Portfolio", "Ship & earn", "Game jam", "Learning")),
        Category("method", "How it's built", "Who writes code", listOf("Leave it to AI", "With AI", "By hand", "As a team")),
        Category("platform", "Platform", "", listOf("Mobile", "PC", "Web", "Console")),
        Category("genre", "Genre", "", listOf("Puzzle", "Roguelike", "Simulation", "Rhythm", "Narrative", "Action", "Productivity", "Community")),
        Category("theme", "Theme", "World and setting", listOf("Fantasy", "Sci-fi", "Everyday", "Horror", "Fairy tale", "History")),
        Category("mood", "Mood", "", listOf("Cozy", "Dreamy", "Tense", "Playful", "Lonely")),
        Category("scope", "Scope", "", listOf("A weekend", "1 month", "3 months", "6+ months")),
        Category("engine", "Engine / tech", "", listOf("Godot", "Unity", "Unreal", "Web (JS)", "Flutter", "Kotlin")),
    )

    /** 거푸집의 답을 프로젝트에 붙일 미리 정한 답 목록으로 바꾼다(갈래 순서 유지). */
    fun presets(mold: Mold, korean: Boolean): List<PresetAnswer> {
        val cats = categories(korean)
        val known = cats.mapNotNull { c -> mold.picks[c.key]?.let { PresetAnswer(c.title, it) } }
        val extra = mold.picks.filterKeys { k -> cats.none { it.key == k } }.map { (k, v) -> PresetAnswer(k, v) }
        return known + extra
    }
}

// ------------------------------------------------------------------ 오늘의 불씨

/** 매일 바뀌는 주제. 서버 없이 날짜로 고른다. */
object DailySpark {
    private val KO = listOf(
        "막차가 끊긴 정류장에서 밤을 보내는 이야기", "비 오는 날에만 열리는 가게", "잃어버린 물건이 모이는 섬",
        "한 손으로 하는 출퇴근길 30초", "할머니의 레시피 노트", "소리를 모으는 수집가", "오래된 기차의 마지막 운행",
        "정전된 도시의 하룻밤", "고양이가 운영하는 우체국", "매일 조금씩 자라는 정원", "말 대신 빛으로 대화하는 마을",
        "지도에 없는 골목", "시험 전날 밤의 도서관", "바다 밑 등대지기", "하루에 한 번만 쓸 수 있는 마법",
        "이사 가는 날의 빈 방", "작은 섬의 축제 준비", "잠들지 못하는 사람을 위한 앱", "버려진 놀이공원 재건",
        "편지가 늦게 도착하는 세계", "눈이 오면 길이 바뀌는 숲", "동네 빵집의 새벽 4시", "기억을 파는 시장",
        "우주 정거장의 화분", "퇴근 후 10분의 취미", "날씨를 고치는 수리공", "혼자 사는 사람의 저녁 식탁",
        "모래시계 속 사막", "길고양이 지도 만들기", "오래된 게임기의 숨은 방",
    )
    private val EN = listOf(
        "A night at a bus stop after the last bus", "A shop that opens only when it rains", "An island where lost things gather",
        "A 30-second one-handed commute", "Grandma's recipe notebook", "A collector of sounds", "The last run of an old train",
        "One night in a city without power", "A post office run by cats", "A garden that grows a little each day", "A town that talks with light",
        "An alley that isn't on any map", "The library the night before exams", "A lighthouse keeper under the sea", "Magic you can use once a day",
        "An empty room on moving day", "Getting a tiny island ready for a festival", "An app for people who can't sleep", "Rebuilding an abandoned theme park",
        "A world where letters arrive late", "A forest whose paths change with snow", "4 a.m. at the neighborhood bakery", "A market that sells memories",
        "A flower pot on a space station", "A 10-minute hobby after work", "A repairer who fixes the weather", "Dinner for one",
        "A desert inside an hourglass", "Mapping the street cats", "A hidden room in an old console",
    )

    /** [offset] 만큼 다음 주제로 넘긴다('다른 불씨'). */
    fun of(epochDay: Long, korean: Boolean, offset: Int = 0): String {
        val list = if (korean) KO else EN
        return list[((epochDay + offset) % list.size).toInt().let { if (it < 0) it + list.size else it }]
    }

    fun today(korean: Boolean, offset: Int = 0): String = of(java.time.LocalDate.now().toEpochDay(), korean, offset)
}

// ------------------------------------------------------------------ 목록 저장소

/** 작은 JSON 목록을 파일 하나에 저장한다. 쓰기는 잠금 안에서 최신 상태로 한다. */
class ListStore<T>(private val file: File, private val serializer: KSerializer<T>, private val scope: CoroutineScope, private val idOf: (T) -> String) {
    private val listSerializer = ListSerializer(serializer)
    private val lock = Mutex()
    private val _items = MutableStateFlow<List<T>>(emptyList())
    val items: StateFlow<List<T>> = _items.asStateFlow()

    fun load() {
        _items.value = runCatching { if (file.exists()) Protocol.json.decodeFromString(listSerializer, file.readText()) else emptyList() }.getOrElse {
            runCatching { file.copyTo(File(file.parentFile, file.name + ".corrupt"), overwrite = true) }
            emptyList()
        }
    }

    fun upsert(item: T) {
        _items.update { list -> listOf(item) + list.filter { idOf(it) != idOf(item) } }
        persist()
    }

    fun update(id: String, f: (T) -> T) {
        _items.update { list -> list.map { if (idOf(it) == id) f(it) else it } }
        persist()
    }

    fun delete(id: String): T? {
        val removed = _items.value.firstOrNull { idOf(it) == id }
        _items.update { list -> list.filter { idOf(it) != id } }
        persist()
        return removed
    }

    fun get(id: String): T? = _items.value.firstOrNull { idOf(it) == id }

    fun clear() { _items.value = emptyList(); persist() }

    private fun persist() {
        scope.launch(Dispatchers.IO) {
            lock.withLock {
                val snapshot = _items.value
                runCatching {
                    val tmp = File(file.parentFile, file.name + ".tmp")
                    tmp.writeText(Protocol.json.encodeToString(listSerializer, snapshot))
                    if (!tmp.renameTo(file)) { file.delete(); tmp.renameTo(file) }
                }
            }
        }
    }
}
