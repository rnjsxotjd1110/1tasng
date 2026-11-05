package app.ember.ideas.handoff

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/** GitHub 요청이 실패한 이유. 화면은 이 값으로 안내 문구를 고른다. */
sealed class GitHubError(message: String) : Exception(message) {
    data object BadToken : GitHubError("bad_token")
    data object NoPermission : GitHubError("no_permission")
    data object NameTaken : GitHubError("name_taken")
    data object Offline : GitHubError("offline")
    class Other(val detail: String) : GitHubError(detail)
}

data class GitHubRepo(val fullName: String, val private: Boolean, val hasIssues: Boolean, val url: String)

/** 내보낼 파일 하나. [path] 는 저장소 안의 경로. */
data class RepoFile(val path: String, val content: String)

/**
 * 개인 액세스 토큰으로 GitHub REST API 를 부른다. 토큰은 휴대폰에만 저장되고 api.github.com 에만 보낸다.
 * 필요한 권한: 새 저장소(Administration·Contents 쓰기), 이슈(Issues 쓰기). 클래식 토큰은 repo 범위.
 */
class GitHubClient(
    private val http: OkHttpClient = OkHttpClient.Builder().connectTimeout(15, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS).build(),
    private val baseUrl: String = "https://api.github.com",
) {
    private val json = Json { ignoreUnknownKeys = true }
    private val jsonType = "application/json".toMediaType()

    /** 토큰이 유효한지 확인하고 사용자 이름을 돌려준다. */
    suspend fun verify(token: String): String =
        call(token, "GET", "/user").jsonObject["login"]?.jsonPrimitive?.content ?: throw GitHubError.BadToken

    suspend fun repos(token: String): List<GitHubRepo> =
        call(token, "GET", "/user/repos?sort=updated&per_page=50&affiliation=owner,collaborator").jsonArray.map { r ->
            val o = r.jsonObject
            GitHubRepo(
                fullName = o["full_name"]!!.jsonPrimitive.content,
                private = o["private"]?.jsonPrimitive?.boolean ?: false,
                hasIssues = o["has_issues"]?.jsonPrimitive?.booleanOrNull ?: true,
                url = o["html_url"]!!.jsonPrimitive.content,
            )
        }

    /** 새 저장소를 만들고 파일을 차례로 올린다. 만든 저장소 주소를 돌려준다. */
    suspend fun createRepo(token: String, name: String, description: String, private: Boolean, files: List<RepoFile>): String {
        val repo = call(token, "POST", "/user/repos", buildJsonObject {
            put("name", name)
            put("description", description.take(300))
            put("private", private)
            put("auto_init", false)
            put("has_issues", true)
        }).jsonObject
        val full = repo["full_name"]!!.jsonPrimitive.content
        files.forEach { f ->
            val encoded = java.util.Base64.getEncoder().encodeToString(f.content.toByteArray(Charsets.UTF_8))
            call(token, "PUT", "/repos/$full/contents/${f.path}", buildJsonObject {
                put("message", "Add ${f.path} from Ember")
                put("content", encoded)
            })
        }
        return repo["html_url"]!!.jsonPrimitive.content
    }

    /** 이슈를 만들고 이슈 주소를 돌려준다. */
    suspend fun createIssue(token: String, fullName: String, title: String, body: String): String =
        call(token, "POST", "/repos/$fullName/issues", buildJsonObject {
            put("title", title.take(250))
            put("body", body.take(MAX_ISSUE_BODY))
        }).jsonObject["html_url"]!!.jsonPrimitive.content

    private suspend fun call(token: String, method: String, path: String, body: JsonObject? = null): JsonElement = withContext(Dispatchers.IO) {
        val req = Request.Builder().url(baseUrl + path)
            .header("Authorization", "Bearer $token")
            .header("Accept", "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .header("User-Agent", "Ember-Android")
            .method(method, body?.toString()?.toRequestBody(jsonType))
            .build()
        val res = try { http.newCall(req).execute() } catch (e: IOException) { throw GitHubError.Offline }
        res.use { r ->
            val text = r.body?.string().orEmpty()
            if (r.isSuccessful) return@withContext if (text.isBlank()) JsonObject(emptyMap()) else json.parseToJsonElement(text)
            val message = runCatching { json.parseToJsonElement(text).jsonObject["message"]?.jsonPrimitive?.content }.getOrNull().orEmpty()
            val errors = runCatching { json.parseToJsonElement(text).jsonObject["errors"]?.jsonArray }.getOrNull() ?: JsonArray(emptyList())
            throw when {
                r.code == 401 -> GitHubError.BadToken
                r.code == 403 || r.code == 404 && method != "GET" -> GitHubError.NoPermission
                r.code == 422 && (message.contains("name already exists") || errors.toString().contains("already exists")) -> GitHubError.NameTaken
                else -> GitHubError.Other("${r.code} $message".trim())
            }
        }
    }

    companion object {
        /** GitHub 이슈 본문 최대 길이(65,536자)보다 조금 여유를 둔다. */
        const val MAX_ISSUE_BODY = 65_000

        /** 프로젝트 제목으로 저장소 이름을 만든다. 영문·숫자가 없으면 ember-design 으로 시작한다. */
        fun repoNameFor(title: String, fallbackId: String): String {
            val slug = title.lowercase().map { ch -> if (ch in 'a'..'z' || ch in '0'..'9') ch else '-' }
                .joinToString("").replace(Regex("-+"), "-").trim('-').take(60)
            return slug.ifBlank { "ember-design-${fallbackId.take(6).lowercase()}" }
        }

        /** 설계서를 ## 단락별로 나눈다(단락마다 이슈 하나). 제목 앞의 번호는 지운다. */
        fun sections(markdown: String): List<Pair<String, String>> {
            val out = ArrayList<Pair<String, String>>()
            var title: String? = null
            val buf = StringBuilder()
            markdown.lines().forEach { line ->
                if (line.startsWith("## ")) {
                    title?.let { out += it to buf.toString().trim() }
                    title = line.removePrefix("## ").trim().replace(Regex("^\\d+[.)]\\s*"), "")
                    buf.clear()
                } else if (title != null) buf.appendLine(line)
            }
            title?.let { out += it to buf.toString().trim() }
            return out.filter { it.second.isNotBlank() }
        }
    }
}
