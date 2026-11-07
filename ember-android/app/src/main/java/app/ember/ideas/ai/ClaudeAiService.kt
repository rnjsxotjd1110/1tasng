package app.ember.ideas.ai

import app.ember.ideas.data.ChatMessage
import app.ember.ideas.data.Usage
import com.anthropic.client.AnthropicClient
import com.anthropic.client.okhttp.AnthropicOkHttpClient
import com.anthropic.core.JsonValue
import com.anthropic.errors.AnthropicIoException
import com.anthropic.errors.AnthropicServiceException
import com.anthropic.errors.BadRequestException
import com.anthropic.errors.InternalServerException
import com.anthropic.errors.NotFoundException
import com.anthropic.errors.PermissionDeniedException
import com.anthropic.errors.RateLimitException
import com.anthropic.errors.UnauthorizedException
import com.anthropic.models.messages.Base64ImageSource
import com.anthropic.models.messages.CacheControlEphemeral
import com.anthropic.models.messages.ContentBlockParam
import com.anthropic.models.messages.WebSearchTool20260209
import com.anthropic.models.messages.JsonOutputFormat
import com.anthropic.models.messages.MessageCreateParams
import com.anthropic.models.messages.OutputConfig
import com.anthropic.models.messages.StopReason
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.longOrNull
import java.io.IOException
import java.time.Duration

/** 요청을 보낼 곳. [baseUrl] 이 있으면 Ember 중계 서버, 없으면 Anthropic 에 직접 보낸다. */
data class Endpoint(val key: String, val baseUrl: String? = null)

/**
 * Anthropic Java SDK 로 Claude 를 부른다.
 * 보낼 곳은 매 요청마다 [endpoint] 에서 읽어 오며, 바뀌면 클라이언트를 다시 만든다.
 */
/** 참고 이미지 한 장의 최대 크기(앱이 저장할 때 줄이므로 이보다 크면 앱이 만든 파일이 아니다). */
private const val MAX_IMAGE_BYTES = 5L * 1024 * 1024

class ClaudeAiService(private val endpoint: () -> Endpoint?) : AiService {

    @Volatile private var cached: Pair<Endpoint, AnthropicClient>? = null

    /** 서버측 거절 대체(fallbacks) 기능. 계정이 지원하지 않아 400 이 나면 끄고 다시 보낸다. */
    @Volatile private var fallbackEnabled = true

    private fun client(ep: Endpoint? = endpoint()): AnthropicClient {
        if (ep == null || ep.key.isBlank()) throw AiError.NoKey
        cached?.let { (k, c) -> if (k == ep) return c }
        val c = AnthropicOkHttpClient.builder()
            .apiKey(ep.key)
            // 이 SDK 버전은 키만 넘기면 Authorization: Bearer 로 보내는데, Anthropic API 키는 x-api-key 로 보내야 한다.
            // 헤더를 직접 넣으면 SDK 가 Bearer 를 덧붙이지 않는다(중계 서버도 x-api-key 를 받는다).
            .putHeader("X-Api-Key", ep.key)
            .apply { if (ep.baseUrl != null) baseUrl(ep.baseUrl) }
            .maxRetries(2)
            .timeout(Duration.ofMinutes(10))
            .build()
        cached = ep to c
        return c
    }

    private fun MessageCreateParams.Builder.applyCommon(
        model: ClaudeModel,
        system: String,
        messages: List<ChatMessage>,
        effort: Effort,
        maxTokens: Long,
        format: JsonOutputFormat?,
        withFallback: Boolean,
    ): MessageCreateParams.Builder {
        model(model.id)
        maxTokens(maxTokens)
        system(system)
        cacheControl(CacheControlEphemeral.builder().build())
        messages.forEach { m ->
            when {
                m.role == ChatMessage.ASSISTANT -> addAssistantMessage(m.text)
                m.images.isEmpty() -> addUserMessage(m.text)
                else -> {
                    // 이미지를 글보다 앞에 두면 Claude 가 그림을 먼저 보고 질문을 읽는다.
                    val blocks = m.images.mapNotNull { path -> imageBlock(path) } + ContentBlockParam.ofText(m.text)
                    addUserMessageOfContentBlockParams(blocks)
                }
            }
        }
        val oc = OutputConfig.builder().effort(effort.toSdk())
        if (format != null) oc.format(format)
        outputConfig(oc.build())
        if (withFallback && model.supportsFallback) {
            putAdditionalHeader("anthropic-beta", "server-side-fallback-2026-07-01")
            putAdditionalBodyProperty("fallbacks", JsonValue.from("default"))
        }
        return this
    }

    private fun imageBlock(path: String): ContentBlockParam? {
        val f = java.io.File(path).canonicalFile
        // 앱이 저장한 참고 이미지(files/images/)만 보낸다. 가져온 백업이 다른 파일을 가리켜도 읽지 않는다.
        if (!f.isFile || f.parentFile?.name != "images" || f.parentFile?.parentFile?.name != "files" || f.length() > MAX_IMAGE_BYTES) return null
        val data = java.util.Base64.getEncoder().encodeToString(f.readBytes())
        return ContentBlockParam.ofImage(Base64ImageSource.builder().mediaType(Base64ImageSource.MediaType.IMAGE_JPEG).data(data).build())
    }

    // 블로킹 HTTP 호출이라 runInterruptible 로 감싼다: '중지'를 누르면 스레드를 깨워 요청을 바로 끊는다.
    override suspend fun turn(model: ClaudeModel, request: TurnRequest): TurnResult = kotlinx.coroutines.runInterruptible(Dispatchers.IO) {
        val format = JsonOutputFormat.builder()
            .schema(JsonOutputFormat.Schema.builder().apply {
                request.schema.forEach { (k, v) -> putAdditionalProperty(k, JsonValue.from(v.toPlain())) }
            }.build())
            .build()
        val c = client()
        val search = request.webSearch && model != ClaudeModel.HAIKU
        var usage = app.ember.ideas.data.Usage()
        val sources = LinkedHashMap<String, app.ember.ideas.data.Reference>()
        val earlier = ArrayList<com.anthropic.models.messages.Message>()
        var response: com.anthropic.models.messages.Message
        // 웹 검색이 길어지면 서버가 pause_turn 으로 잠시 돌려준다. 받은 내용을 그대로 붙여 이어 가게 한다(최대 3번).
        while (true) {
            response = mapErrors {
                withFallbackRetry { fb ->
                    val b = MessageCreateParams.builder()
                        .applyCommon(model, request.system, request.messages, request.effort, request.maxTokens, format, fb)
                    if (search) b.addTool(WebSearchTool20260209.builder().maxUses(3L).build())
                    earlier.forEach { b.addMessage(it) }
                    c.messages().create(b.build())
                }
            }
            val u = response.usage()
            val searches = u.serverToolUse().map { it.webSearchRequests() }.orElse(0L)
            usage += usageOf(ClaudeModel.find(response.model().asString()) ?: model, u.inputTokens(), u.outputTokens(), u.cacheReadInputTokens().orElse(0L), u.cacheCreationInputTokens().orElse(0L), searches)
            response.content().forEach { b ->
                b.webSearchToolResult().orElse(null)?.content()?.resultBlocks()?.orElse(null)?.forEach { r ->
                    sources.putIfAbsent(r.url(), app.ember.ideas.data.Reference(r.title(), r.url()))
                }
            }
            if (response.stopReason().orElse(null) != StopReason.PAUSE_TURN || earlier.size >= 3) break
            earlier += response
        }
        val stop = response.stopReason().orElse(null)
        if (stop == StopReason.REFUSAL) throw AiError.Refused
        // 검색을 쓰면 앞쪽에 짧은 안내 글이 섞일 수 있으니 마지막 도구 결과 뒤의 글만 JSON 으로 본다.
        val blocks = response.content()
        val lastTool = blocks.indexOfLast { !it.isText() && it.thinking().isEmpty }
        val text = blocks.drop(lastTool + 1).mapNotNull { b -> b.text().orElse(null)?.text() }.joinToString("")
        if (stop == StopReason.MAX_TOKENS && endpoint()?.baseUrl != null) throw AiError.CreditCapped
        if (text.isBlank() || stop == StopReason.MAX_TOKENS) throw AiError.BadResponse
        TurnResult(text, usage, sources.values.toList())
    }

    override suspend fun turnStreaming(model: ClaudeModel, request: TurnRequest, onText: (String) -> Unit): TurnResult {
        // 웹 검색이 섞이면 중간 글과 도구 결과가 끼어들므로 한 번에 받는다.
        if (request.webSearch) return turn(model, request)
        return withContext(Dispatchers.IO) {
            val format = JsonOutputFormat.builder()
                .schema(JsonOutputFormat.Schema.builder().apply {
                    request.schema.forEach { (k, v) -> putAdditionalProperty(k, JsonValue.from(v.toPlain())) }
                }.build())
                .build()
            val c = client()
            val text = StringBuilder()
            var input = 0L
            var cacheRead = 0L
            var cacheWrite = 0L
            var output = 0L
            var stop: StopReason? = null
        // 서버가 다른 모델로 답했으면(무료 크레딧의 Haiku, 대체 모델) 그 모델 단가로 계산한다.
        var answered = model
            var lastEmit = 0L
            mapErrors {
                withFallbackRetry { fb ->
                    text.clear()
                    val params = MessageCreateParams.builder()
                        .applyCommon(model, request.system, request.messages, request.effort, request.maxTokens, format, fb)
                        .build()
                    c.messages().createStreaming(params).use { sr ->
                        val it = sr.stream().iterator()
                        while (it.hasNext()) {
                            currentCoroutineContext().ensureActive()
                            val event = it.next()
                            event.messageStart().orElse(null)?.let { st ->
                                ClaudeModel.find(st.message().model().asString())?.let { answered = it }
                                val u = st.message().usage()
                                input = u.inputTokens()
                                cacheRead = u.cacheReadInputTokens().orElse(0L)
                                cacheWrite = u.cacheCreationInputTokens().orElse(0L)
                            }
                            val delta = event.contentBlockDelta().orElse(null)?.delta()?.text()?.orElse(null)?.text()
                            if (!delta.isNullOrEmpty()) {
                                text.append(delta)
                                // 화면 갱신은 0.12초에 한 번이면 충분하다.
                                val now = System.currentTimeMillis()
                                if (now - lastEmit > 120) { lastEmit = now; onText(text.toString()) }
                            }
                            event.messageDelta().orElse(null)?.let { d ->
                                output = d.usage().outputTokens()
                                val inTok = d.usage().inputTokens().orElse(0L)
                                if (inTok > 0) input = inTok
                                stop = d.delta().stopReason().orElse(null)
                            }
                        }
                    }
                }
            }
            if (stop == StopReason.REFUSAL) throw AiError.Refused
            val result = text.toString()
            if (stop == StopReason.MAX_TOKENS && endpoint()?.baseUrl != null) throw AiError.CreditCapped
            if (result.isBlank() || stop == StopReason.MAX_TOKENS) throw AiError.BadResponse
            onText(result)
            TurnResult(result, usageOf(answered, input, output, cacheRead, cacheWrite))
        }
    }

    override fun stream(model: ClaudeModel, request: StreamRequest): Flow<StreamEvent> = flow {
        val c = client()
        var input = 0L
        var cacheRead = 0L
        var cacheWrite = 0L
        var output = 0L
        var stop: StopReason? = null
        // 서버가 다른 모델로 답했으면(무료 크레딧의 Haiku, 대체 모델) 그 모델 단가로 계산한다.
        var answered = model
        mapErrors {
            withFallbackRetry { fb ->
                val params = MessageCreateParams.builder()
                    .applyCommon(model, request.system, request.messages, request.effort, request.maxTokens, null, fb)
                    .build()
                c.messages().createStreaming(params).use { sr ->
                    val it = sr.stream().iterator()
                    while (it.hasNext()) {
                        currentCoroutineContext().ensureActive()
                        val event = it.next()
                        event.messageStart().orElse(null)?.let { s ->
                            ClaudeModel.find(s.message().model().asString())?.let { answered = it }
                            val u = s.message().usage()
                            input = u.inputTokens()
                            cacheRead = u.cacheReadInputTokens().orElse(0L)
                            cacheWrite = u.cacheCreationInputTokens().orElse(0L)
                        }
                        val delta = event.contentBlockDelta().orElse(null)?.delta()?.text()?.orElse(null)?.text()
                        if (!delta.isNullOrEmpty()) emit(StreamEvent.Delta(delta))
                        event.messageDelta().orElse(null)?.let { d ->
                            output = d.usage().outputTokens()
                            val inTok = d.usage().inputTokens().orElse(0L)
                            if (inTok > 0) input = inTok
                            stop = d.delta().stopReason().orElse(null)
                        }
                    }
                }
            }
        }
        if (stop == StopReason.REFUSAL) throw AiError.Refused
        emit(StreamEvent.Done(usageOf(answered, input, output, cacheRead, cacheWrite), truncated = stop == StopReason.MAX_TOKENS))
    }.flowOn(Dispatchers.IO)

    override suspend fun validate(apiKey: String, model: ClaudeModel) = withContext(Dispatchers.IO) {
        val c = client(Endpoint(apiKey.trim()))
        mapErrors { c.models().retrieve(model.id) }
        Unit
    }

    private inline fun <T> withFallbackRetry(block: (Boolean) -> T): T {
        if (!fallbackEnabled) return block(false)
        return try {
            block(true)
        } catch (e: BadRequestException) {
            val msg = (e.message ?: "") + e.body().toString()
            if (msg.contains("fallback", ignoreCase = true) || msg.contains("anthropic-beta", ignoreCase = true)) {
                fallbackEnabled = false
                block(false)
            } else throw e
        }
    }

    private inline fun <T> mapErrors(block: () -> T): T = try {
        block()
    } catch (e: AiError) {
        throw e
    } catch (e: UnauthorizedException) {
        throw AiError.InvalidKey
    } catch (e: PermissionDeniedException) {
        // 중계 서버가 정산 확인 때문에 계정을 멈춘 경우는 키 오류와 다르게 안내한다.
        val msg = (e.message ?: "") + runCatching { e.body().toString() }.getOrDefault("")
        if (msg.contains("reconciliation", ignoreCase = true)) throw AiError.AccountHeld
        throw AiError.InvalidKey
    } catch (e: RateLimitException) {
        throw AiError.RateLimited
    } catch (e: NotFoundException) {
        throw AiError.ModelUnavailable
    } catch (e: InternalServerException) {
        throw AiError.Overloaded
    } catch (e: BadRequestException) {
        val msg = (e.message ?: "") + e.body().toString()
        if (msg.contains("credit balance", ignoreCase = true) || msg.contains("billing", ignoreCase = true)) throw AiError.NoCredit
        throw AiError.Other(e.message ?: "400")
    } catch (e: AnthropicServiceException) {
        if (e.statusCode() == 402) throw AiError.OutOfCredits
        if (e.statusCode() == 529 || e.statusCode() >= 500) throw AiError.Overloaded
        throw AiError.Other("${e.statusCode()} ${e.message ?: ""}".trim())
    } catch (e: AnthropicIoException) {
        throw AiError.Offline
    } catch (e: IOException) {
        throw AiError.Offline
    } catch (e: kotlinx.coroutines.CancellationException) {
        throw e
    } catch (e: RuntimeException) {
        if (e.cause is IOException) throw AiError.Offline
        throw AiError.Other(e.message ?: e.javaClass.simpleName)
    }

    private fun Effort.toSdk(): OutputConfig.Effort = when (this) {
        Effort.LOW -> OutputConfig.Effort.LOW
        Effort.MEDIUM -> OutputConfig.Effort.MEDIUM
        Effort.HIGH -> OutputConfig.Effort.HIGH
        Effort.XHIGH -> OutputConfig.Effort.XHIGH
    }

    private fun usageOf(model: ClaudeModel, input: Long, output: Long, cacheRead: Long, cacheWrite: Long, searches: Long = 0) = Usage(
        inputTokens = input,
        outputTokens = output,
        cacheReadTokens = cacheRead,
        cacheWriteTokens = cacheWrite,
        costUsd = model.cost(input, output, cacheRead, cacheWrite) + searches * WEB_SEARCH_USD,
        requests = 1,
    )
}

/** kotlinx JSON 을 SDK 의 JsonValue.from() 이 받는 평범한 Map/List/원시값으로 바꾼다. */
internal fun JsonElement.toPlain(): Any? = when (this) {
    is JsonNull -> null
    is JsonObject -> mapValues { it.value.toPlain() }
    is JsonArray -> map { it.toPlain() }
    is JsonPrimitive -> when {
        isString -> content
        booleanOrNull != null -> booleanOrNull
        longOrNull != null -> longOrNull
        else -> content.toDoubleOrNull() ?: content
    }
}
