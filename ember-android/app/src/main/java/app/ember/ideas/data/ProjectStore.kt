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
import kotlinx.serialization.builtins.ListSerializer
import java.io.File
import java.util.UUID

/**
 * 모든 프로젝트를 앱 내부 저장소의 JSON 파일 하나에 보관한다.
 * 메모리의 StateFlow 가 원본이고, 바뀔 때마다 임시 파일에 쓴 뒤 교체해 손상을 막는다.
 */
class ProjectStore(private val dir: File, private val scope: CoroutineScope) {

    private val file = File(dir, "projects.json")
    private val tmp = File(dir, "projects.json.tmp")
    private val writeLock = Mutex()
    private val serializer = ListSerializer(Project.serializer())

    private val _projects = MutableStateFlow<List<Project>>(emptyList())
    val projects: StateFlow<List<Project>> = _projects.asStateFlow()

    @Volatile var loaded = false
        private set

    fun loadBlocking() {
        if (loaded) return
        val list = runCatching {
            if (file.exists()) Protocol.json.decodeFromString(serializer, file.readText()) else emptyList()
        }.getOrElse {
            // 손상된 파일은 지우지 않고 옆에 보관해 둔다.
            runCatching { file.copyTo(File(dir, "projects.corrupt.${System.currentTimeMillis()}.json"), overwrite = true) }
            emptyList()
        }
        _projects.value = list.sortedByDescending { it.updatedAt }
        loaded = true
    }

    fun get(id: String): Project? = _projects.value.firstOrNull { it.id == id }

    fun upsert(project: Project) {
        _projects.update { list -> (listOf(project) + list.filter { it.id != project.id }).sortedByDescending { it.updatedAt } }
        persist()
    }

    /** 원자적으로 한 프로젝트를 고친다. 프로젝트가 없으면 아무것도 하지 않는다. */
    fun update(id: String, touch: Boolean = true, transform: (Project) -> Project): Project? {
        var result: Project? = null
        _projects.update { list ->
            list.map { p ->
                if (p.id == id) transform(p).let { if (touch) it.copy(updatedAt = System.currentTimeMillis()) else it }.also { result = it } else p
            }.sortedByDescending { it.updatedAt }
        }
        if (result != null) persist()
        return result
    }

    fun delete(id: String): Project? {
        val removed = get(id)
        _projects.update { list -> list.filter { it.id != id } }
        persist()
        return removed
    }

    fun deleteAll() {
        _projects.value = emptyList()
        persist()
    }

    fun exportJson(): String = Protocol.json.encodeToString(serializer, _projects.value)

    private fun persist() {
        val snapshot = _projects.value
        scope.launch(Dispatchers.IO) {
            writeLock.withLock {
                runCatching {
                    tmp.writeText(Protocol.json.encodeToString(serializer, snapshot))
                    if (!tmp.renameTo(file)) {
                        file.delete()
                        tmp.renameTo(file)
                    }
                }
            }
        }
    }

    companion object {
        fun newId(): String = UUID.randomUUID().toString().replace("-", "").take(16)
    }
}
