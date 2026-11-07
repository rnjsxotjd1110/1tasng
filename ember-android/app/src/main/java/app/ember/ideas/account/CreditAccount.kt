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
    suspend fun connect(): Int {
        if (!settings.creditToken().isNullOrBlank()) return refresh()
        // 무료 크레딧을 기기마다 한 번만 주도록 Play Integrity 토큰을 함께 보낸다.
        // 서버가 일시 오류(502)를 주면 새 nonce 로 한 번 더 시도한다.
        var body: JsonObject? = null
        for (attempt in 0 until 2) {
            val payload = registerPayload()
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
        return credits
    }

    private suspend fun registerPayload(): JsonObject {
        val nonce = runCatching { get("/ember/nonce", token = null)["nonce"]?.jsonPrimitive?.content }.getOrNull()
        val token = nonce?.let { n -> runCatching { integrity(n) }.getOrNull() }
        return buildJsonObject {
            put("installId", settings.installId())
            if (nonce != null && token != null) {
                put("nonce", nonce)
                put("integrityToken", token)
            }
        }
    }

    /** 서버에서 잔액을 다시 읽는다. 토큰이 만료되었으면 다시 등록한다(무료 크레딧은 다시 주지 않는다). */
    suspend fun refresh(): Int {
        val token = settings.creditToken() ?: return connect()
        return try {
            val credits = get("/ember/balance", token)["credits"]?.jsonPrimitive?.int ?: 0
            settings.setCredits(credits)
            credits
        } catch (e: AiError.InvalidKey) {
            settings.setCreditAccount(null, 0)
            connect()
        }
    }

    /** 마지막 [redeem] 으로 새로 받은 크레딧 수. */
    @Volatile var lastGranted: Int = 0
        private set

    /** Play 결제 영수증을 서버에 보내 크레딧을 받는다. 같은 영수증은 서버가 한 번만 인정한다. */
    suspend fun redeem(productId: String, purchaseToken: String): Int {
        val token = settings.creditToken() ?: run { connect(); settings.creditToken()!! }
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

    /** AI 가 만든 내용을 신고한다(Google Play 생성형 AI 정책). */
    suspend fun report(kind: String, reason: String, content: String, note: String, appVersion: String) {
        val token = settings.creditToken() ?: run { connect(); settings.creditToken()!! }
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
