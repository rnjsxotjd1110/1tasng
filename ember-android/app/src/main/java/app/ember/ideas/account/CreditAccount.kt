package app.ember.ideas.account

import app.ember.ideas.ai.AiError
import app.ember.ideas.data.SettingsStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Ember 중계 서버의 계정 기능(등록·잔액·구매 확인·신고).
 * Claude 호출 자체는 Anthropic SDK 가 서버 주소로 보내므로 여기서는 다루지 않는다.
 */
class CreditAccount(
    private val settings: SettingsStore,
    private val http: OkHttpClient = defaultClient(),
    /** 서버가 준 nonce 로 Play Integrity 토큰을 받는다. 기기에서 받지 못하면 null. */
    private val integrity: suspend (nonce: String) -> String? = { null },
) {

    private val json = Json { ignoreUnknownKeys = true }
    private val jsonType = "application/json".toMediaType()

    /** 이 기기를 등록하고 무료 크레딧을 받는다. 이미 등록되어 있으면 잔액만 새로 고친다. */
    /**
     * Google 계정으로 크레딧 계정에 들어간다. 이 Google 계정의 계정이 서버에 있으면 그대로 되찾고(기기 변경·재설치),
     * 없으면 새로 만든다. 무료 크레딧은 Google 계정마다 한 번만 받는다.
     */
    suspend fun connect(google: GoogleAccount?): Int {
        if (!settings.creditToken().isNullOrBlank() && google == null) return refresh()
        // 무료 크레딧을 기기마다 한 번만 주도록 Play Integrity 토큰을 함께 보낸다.
        // 서버가 일시 오류(502)를 주면 새 nonce 로 한 번 더 시도한다.
        var body: JsonObject? = null
        for (attempt in 0 until 2) {
            val payload = registerPayload(google?.idToken)
            try {
                body = post("/ember/register", payload, token = null)
                break
            } catch (e: AiError.Overloaded) {
                if (attempt == 1) throw e
            }
        }
        body ?: throw AiError.BadResponse
        val token = body["token"]?.jsonPrimitive?.content ?: throw AiError.BadResponse
        val credits = body["credits"]?.jsonPrimitive?.int ?: 0
        settings.setCreditAccount(token, credits)
        if (google != null) settings.setGoogleEmail(google.email)
        // 같은 Google 계정의 기존 계정을 되찾았는지(기기 변경·재설치).
        lastRestored = body["restored"]?.jsonPrimitive?.content == "true"
        return credits
    }

    /** 예전 버전에서 만든(Google 과 묶이지 않은) 계정을 Google 계정에 묶는다. */
    suspend fun linkGoogle(google: GoogleAccount) {
        val token = settings.creditToken() ?: throw AiError.InvalidKey
        post("/ember/link-google", buildJsonObject { put("idToken", google.idToken) }, token)
        settings.setGoogleEmail(google.email)
    }

    /**
     * 서버의 크레딧 계정을 완전히 지운다(남은 크레딧도 사라진다). 결제 기록은 법에 따라 개인을 알 수 없게 바꿔 보관한다.
     * 지운 뒤에는 이 기기의 연결 정보도 지운다.
     */
    suspend fun deleteAccount() {
        val token = settings.creditToken() ?: return
        call(Request.Builder().url(ServerConfig.serverUrl + "/ember/account").header("x-api-key", token).delete().build())
        settings.setCreditAccount(null, 0)
        settings.setGoogleEmail("")
        settings.setPurchased(false)
        settings.setPreferCredits(false)
    }

    /** 이 기기에서만 로그아웃한다. 크레딧은 서버에 남아 있어 다시 로그인하면 되찾는다. */
    fun signOutHere() {
        settings.setCreditAccount(null, 0)
        settings.setGoogleEmail("")
        settings.setPreferCredits(false)
    }

    private suspend fun registerPayload(idToken: String?): JsonObject {
        val nonce = runCatching { get("/ember/nonce", token = null)["nonce"]?.jsonPrimitive?.content }.getOrNull()
        val token = nonce?.let { n -> runCatching { integrity(n) }.getOrNull() }
        return buildJsonObject {
            put("installId", settings.installId())
            if (idToken != null) put("idToken", idToken)
            if (nonce != null && token != null) {
                put("nonce", nonce)
                put("integrityToken", token)
            }
        }
    }

    /** 서버에서 잔액을 다시 읽는다. 토큰이 무효가 되었으면 연결을 풀고(다시 Google 로그인 필요) 0 을 돌려준다. */
    suspend fun refresh(): Int {
        val token = settings.creditToken() ?: return 0
        return try {
            val body = get("/ember/balance", token)
            val credits = body["credits"]?.jsonPrimitive?.int ?: 0
            settings.setCredits(credits)
            // 유료·무료 구분과 30일 안에 만료되는 유료 크레딧(서버가 주지 않으면 비워 둔다).
            val exp = body["expiringSoon"]?.let { runCatching { it.jsonObject }.getOrNull() }
            settings.setCreditDetail(
                paid = body["paidCredits"]?.jsonPrimitive?.content?.toIntOrNull() ?: -1,
                free = body["freeCredits"]?.jsonPrimitive?.content?.toIntOrNull() ?: -1,
                expiring = exp?.get("credits")?.jsonPrimitive?.content?.toIntOrNull() ?: 0,
                expiringAt = exp?.get("at")?.jsonPrimitive?.content?.let(::parseTime) ?: 0L,
            )
            credits
        } catch (e: AiError.InvalidKey) {
            settings.setCreditAccount(null, 0)
            0
        }
    }

    /** 마지막 [connect] 가 기존 계정을 되찾았는지. */
    @Volatile var lastRestored: Boolean = false
        private set

    /** 이 기기가 크레딧 계정에 로그인해 있는지. */
    val signedIn: Boolean get() = !settings.creditToken().isNullOrBlank()

    /** 마지막 [redeem] 으로 새로 받은 크레딧 수. */
    @Volatile var lastGranted: Int = 0
        private set

    /** Play 결제 영수증을 서버에 보내 크레딧을 받는다. 같은 영수증은 서버가 한 번만 인정한다. */
    suspend fun redeem(productId: String, purchaseToken: String): Int {
        val token = settings.creditToken() ?: throw AiError.NoKey // 크레딧 모드는 Google 로그인으로만 시작한다
        val body = post("/ember/purchase", buildJsonObject {
            put("productId", productId)
            put("purchaseToken", purchaseToken)
        }, token)
        val credits = body["credits"]?.jsonPrimitive?.int ?: throw AiError.BadResponse
        settings.setCredits(credits)
        // 이번 요청으로 새로 받은 크레딧. 같은 영수증을 다시 보내면 0 이다.
        lastGranted = body["granted"]?.jsonPrimitive?.int ?: 0
        if (lastGranted > 0) settings.setPurchased(true)
        return credits
    }

    /** 서버 시각(초·밀리초 숫자 또는 ISO 문자열)을 밀리초로. */
    private fun parseTime(v: String): Long =
        v.toLongOrNull()?.let { if (it < 100_000_000_000L) it * 1000 else it }
            ?: runCatching { java.time.Instant.parse(v).toEpochMilli() }.getOrDefault(0L)

    /** 크레딧 계정이 없는 사람(내 API 키 사용자)의 신고. 계정을 만들지 않고 보낸다. */
    suspend fun reportAnon(kind: String, reason: String, content: String, note: String, appVersion: String) {
        post("/ember/report/anon", buildJsonObject {
            put("kind", kind)
            put("reason", reason)
            put("content", content.take(20_000))
            put("note", note.take(2_000))
            put("appVersion", appVersion)
        }, token = null)
    }

    /** AI 가 만든 내용을 신고한다(Google Play 생성형 AI 정책). */
    suspend fun report(kind: String, reason: String, content: String, note: String, appVersion: String) {
        val token = settings.creditToken() ?: throw AiError.NoKey // 크레딧 모드는 Google 로그인으로만 시작한다
        post("/ember/report", buildJsonObject {
            put("kind", kind)
            put("reason", reason)
            put("content", content.take(20_000))
            put("note", note.take(2_000))
            put("appVersion", appVersion)
        }, token)
    }

    private suspend fun get(path: String, token: String?): JsonObject = call(
        Request.Builder().url(ServerConfig.serverUrl + path).apply { if (token != null) header("x-api-key", token) }.get().build(),
    )

    private suspend fun post(path: String, body: JsonObject, token: String?): JsonObject = call(
        Request.Builder().url(ServerConfig.serverUrl + path)
            .apply { if (token != null) header("x-api-key", token) }
            .post(body.toString().toRequestBody(jsonType))
            .build(),
    )

    private suspend fun call(request: Request): JsonObject = withContext(Dispatchers.IO) {
        if (!ServerConfig.creditsEnabled) throw AiError.NoKey
        val response = try {
            http.newCall(request).execute()
        } catch (e: IOException) {
            throw AiError.Offline
        }
        response.use { r ->
            val text = r.body?.string().orEmpty()
            when {
                r.isSuccessful -> runCatching { json.parseToJsonElement(text).jsonObject }.getOrElse { throw AiError.BadResponse }
                r.code == 401 -> throw AiError.InvalidKey
                r.code == 402 -> throw AiError.OutOfCredits
                r.code == 429 -> throw AiError.RateLimited
                r.code >= 500 -> throw AiError.Overloaded
                else -> throw AiError.Other("${r.code} " + errorMessage(text))
            }
        }
    }

    private fun errorMessage(text: String): String = runCatching {
        json.parseToJsonElement(text).jsonObject["error"]?.jsonObject?.get("message")?.jsonPrimitive?.content
    }.getOrNull() ?: ""

    companion object {
        fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
    }
}
