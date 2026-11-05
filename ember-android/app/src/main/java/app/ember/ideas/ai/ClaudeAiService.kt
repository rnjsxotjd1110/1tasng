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
import com.anthropic.models.messages.CacheControlEphemeral
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

/**
 * Anthropic Java SDK 로 Claude 를 부른다.
 * 키는 매 요청마다 [apiKey] 에서 읽어 오며, 키가 바뀌면 클라이언트를 다시 만든다.
 */
class ClaudeAiService(private val apiKey: () -> String?) : AiService {

    @Volatile private var cached: Pair<String, AnthropicClient>? = null

    /** 서버측 거절 대체(fallbacks) 기능. 계정이 지원하지 않아 400 이 나면 끄고 다시 보낸다. */
    @Volatile private var fallbackEnabled = true

    private fun client(key: String? = apiKey()): AnthropicClient {
        if (key.isNullOrBlank()) throw AiError.NoKey
        cached?.let { (k, c) -> if (k == key) return c }
        val c = AnthropicOkHttpClient.builder()
            .apiKey(key)
            .maxRetries(2)
            .timeout(Duration.ofMinutes(10))
            .build()
        cached = key to c
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
            if (m.role == ChatMessage.ASSISTANT) addAssistantMessage(m.text) else addUserMessage(m.text)
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

    override suspend fun turn(model: ClaudeModel, request: TurnRequest): TurnResult = withContext(Dispatchers.IO) {
        val format = JsonOutputFormat.builder()
            .schema(JsonOutputFormat.Schema.builder().apply {
                request.schema.forEach { (k, v) -> putAdditionalProperty(k, JsonValue.from(v.toPlain())) }
            }.build())
            .build()
        val c = client()
        val response = mapErrors {
            withFallbackRetry { fb ->
                val params = MessageCreateParams.builder()
                    .applyCommon(model, request.system, request.messages, request.effort, request.maxTokens, format, fb)
                    .build()
                c.messages().create(params)
            }
        }
        val stop = response.stopReason().orElse(null)
        if (stop == StopReason.REFUSAL) throw AiError.Refused
        val text = response.content().mapNotNull { b -> b.text().orElse(null)?.text() }.joinToString("")
        if (text.isBlank() || stop == StopReason.MAX_TOKENS) throw AiError.BadResponse
        val u = response.usage()
        val usage = usageOf(
            model,
            u.inputTokens(),
            u.outputTokens(),
            u.cacheReadInputTokens().orElse(0L),
            u.cacheCreationInputTokens().orElse(0L),
        )
        TurnResult(text, usage)
    }

    override fun stream(model: ClaudeModel, request: StreamRequest): Flow<StreamEvent> = flow {
        val c = client()
        var input = 0L
        var cacheRead = 0L
        var cacheWrite = 0L
        var output = 0L
        var stop: StopReason? = null
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
        emit(StreamEvent.Done(usageOf(model, input, output, cacheRead, cacheWrite), truncated = stop == StopReason.MAX_TOKENS))
    }.flowOn(Dispatchers.IO)

    override suspend fun validate(apiKey: String, model: ClaudeModel) = withContext(Dispatchers.IO) {
        val c = client(apiKey.trim())
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

    private fun usageOf(model: ClaudeModel, input: Long, output: Long, cacheRead: Long, cacheWrite: Long) = Usage(
        inputTokens = input,
        outputTokens = output,
        cacheReadTokens = cacheRead,
        cacheWriteTokens = cacheWrite,
        costUsd = model.cost(input, output, cacheRead, cacheWrite),
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
