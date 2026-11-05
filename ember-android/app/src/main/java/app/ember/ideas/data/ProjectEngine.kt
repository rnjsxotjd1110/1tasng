package app.ember.ideas.data

import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.currentCoroutineContext
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.ai.AiError
import app.ember.ideas.ai.AiService
import app.ember.ideas.ai.Effort
import app.ember.ideas.ai.Protocol
import app.ember.ideas.ai.ReplyLanguage
import app.ember.ideas.ai.StreamEvent
import app.ember.ideas.ai.StreamRequest
import app.ember.ideas.ai.TurnRequest
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.SerializationException
import java.util.Locale

enum class OpKind { ASKING, IDEAS, DESIGN_ASKING, WRITING, REVISING }

/** 프로젝트별로 진행 중인 AI 작업 상태. 화면을 벗어나도 작업은 계속된다. */
data class OpState(
    val kind: OpKind,
    val running: Boolean = true,
    val error: AiError? = null,
    val streamingText: String = "",
    val startedAt: Long = System.currentTimeMillis(),
    /** 질문을 받는 중이면 지금까지 도착한 질문(제목·선택지 일부). */
    val partial: app.ember.ideas.ai.PartialQuestion? = null,
)

/**
 * 프로젝트의 모든 AI 흐름(아이디어 인터뷰 → 아이디어 → 설계 인터뷰 → 설계서)을 담당한다.
 * 요청이 성공했을 때만 대화 기록을 저장하므로, 실패하면 같은 동작을 그대로 다시 시도할 수 있다.
 */
private const val SEARCH_FROM_PROGRESS = 60

/** 새로 받은 아이디어 중 겹치지 않는 것이 이보다 적으면 한 번 더 요청한다. */
private const val MIN_FRESH_IDEAS = 3

class ProjectEngine(
    private val store: ProjectStore,
    private val settings: SettingsStore,
    private val ai: AiService,
    private val scope: CoroutineScope,
    private val demoAi: AiService = app.ember.ideas.ai.DemoAiService(),
) {
    /** 체험 프로젝트는 키 없이 준비된 응답을 쓰는 데모 AI 로 돌린다. */
    private fun aiFor(id: String): AiService = if (store.get(id)?.isDemo == true) demoAi else ai

    /** 작업이 끝날 때마다 알린다(알림·백그라운드 유지에 쓴다). */
    data class OpFinished(val projectId: String, val kind: OpKind, val error: AiError?)
    private val _finished = kotlinx.coroutines.flow.MutableSharedFlow<OpFinished>(extraBufferCapacity = 16)
    val finished: kotlinx.coroutines.flow.SharedFlow<OpFinished> = _finished

    private val _ops = MutableStateFlow<Map<String, OpState>>(emptyMap())
    val ops: StateFlow<Map<String, OpState>> = _ops.asStateFlow()

    private val jobs = HashMap<String, Job>()
    private val retries = HashMap<String, () -> Unit>()
    private val nextAfter = HashMap<String, () -> Unit>()

    private val lang: ReplyLanguage
        get() = when (settings.settings.value.language) {
            LanguageMode.KO -> ReplyLanguage.KO
            LanguageMode.EN -> ReplyLanguage.EN
            LanguageMode.AUTO -> if (Locale.getDefault().language == "ko") ReplyLanguage.KO else ReplyLanguage.EN
        }

    private val deep get() = settings.settings.value.deepThinking
    private val model get() = settings.settings.value.model

    /** '질문은 빠르게'를 켜면 질문 단계만 Sonnet 으로 보낸다. 아이디어·설계서는 고른 모델 그대로. */
    private fun questionModel(kind: OpKind): ClaudeModel =
        if (settings.settings.value.fastQuestions && (kind == OpKind.ASKING || kind == OpKind.DESIGN_ASKING) && model == ClaudeModel.OPUS) ClaudeModel.SONNET else model

    /** 모델이 적은 참고 링크 중 실제 검색 결과에 있던 것만 남긴다(주소를 지어내지 못하게). */
    private fun verifiedReferences(refs: List<app.ember.ideas.data.Reference>, sources: List<app.ember.ideas.data.Reference>): List<app.ember.ideas.data.Reference> {
        fun key(u: String) = u.trim().removeSuffix("/").substringBefore("#").lowercase()
        val known = sources.associateBy { key(it.url) }
        return refs.mapNotNull { r -> known[key(r.url)]?.let { k -> app.ember.ideas.data.Reference(r.title.ifBlank { k.title }, k.url) } }
            .distinctBy { key(it.url) }.take(3)
    }

    fun isBusy(id: String) = _ops.value[id]?.running == true

    // ------------------------------------------------------------ 프로젝트 생성

    fun createProject(kind: ProjectKind, seed: String, defaultTitle: String, quick: Boolean = false, images: List<String> = emptyList()): Project {
        val now = System.currentTimeMillis()
        val title = seed.trim().lineSequence().firstOrNull()?.take(28)?.takeIf { it.isNotBlank() } ?: defaultTitle
        val p = Project(id = ProjectStore.newId(), title = title, kind = kind, seed = seed.trim(), createdAt = now, updatedAt = now, images = images)
        store.upsert(p)
        startInterview(p.id, quick)
        return p
    }

    fun createDemoProject(title: String): Project {
        val now = System.currentTimeMillis()
        val p = Project(id = ProjectStore.newId(), title = title, kind = ProjectKind.GAME, seed = "", createdAt = now, updatedAt = now, isDemo = true)
        store.upsert(p)
        startInterview(p.id)
        return p
    }

    fun startInterview(id: String, quick: Boolean = false) {
        val p = store.get(id) ?: return
        val start = Protocol.startMessage(p.kind, p.seed, settings.settings.value.profile, lang, imageCount = p.images.size)
        val text = if (quick) start.removeSuffix("첫 질문을 해 주세요.") + Protocol.REQUEST_QUICK_IDEAS else start
        discoveryCall(id, if (quick) OpKind.IDEAS else OpKind.ASKING, base = emptyList(), userMsg = ChatMessage(ChatMessage.USER, text, p.images), onBeforeCommit = { it })
    }

    // ------------------------------------------------------------ 아이디어 인터뷰

    fun answer(id: String, answer: Answer) {
        val p = store.get(id) ?: return
        val turn = p.currentTurn ?: return
        val left = p.extraQuestionsLeft
        // 추가 질문 중이면 남은 개수를 알려 아이디어로 건너뛰지 않게 하고, 마지막 답이면 새 아이디어를 요청한다.
        val text = Protocol.answerMessage(turn.question, answer) + when {
            left > 0 -> Protocol.remainingNote(left)
            left == 0 -> "\n" + Protocol.freshIdeasMessage(previousTitles(p))
            else -> ""
        }
        discoveryCall(
            id, if (left == 0) OpKind.IDEAS else OpKind.ASKING, base = p.messages, userMsg = ChatMessage(ChatMessage.USER, text),
            onBeforeCommit = { proj -> proj.copy(turns = proj.turns.dropLast(1) + turn.copy(answer = answer)) },
            extraAfter = { isQuestion -> if (left < 0 || !isQuestion) -1 else (left - 1).coerceAtLeast(0) },
            fromExtra = left >= 0,
        )
    }

    /** 지금 질문에서 바로 앞 질문으로 돌아갈 수 있는지. 요청으로 시작된 질문은 앞 질문과 이어져 있지 않아 되돌릴 수 없다. */
    fun canUndo(p: Project): Boolean {
        if (p.currentTurn == null || p.turns.size < 2 || p.messages.size < 2) return false
        val trigger = p.messages[p.messages.size - 2]
        return trigger.role == ChatMessage.USER && (trigger.text.startsWith("[답변]") || trigger.text.startsWith("[건너뜀]"))
    }

    /** 바로 직전 질문으로 돌아간다. 돌아간 질문의 이전 답은 반환해 화면에서 미리 선택해 둔다. */
    fun undo(id: String): Answer? {
        if (isBusy(id)) return null
        val p = store.get(id) ?: return null
        if (!canUndo(p)) return null
        val prev = p.turns[p.turns.size - 2]
        dismissError(id)
        store.update(id) {
            it.copy(
                turns = it.turns.dropLast(2) + prev.copy(answer = null),
                messages = it.messages.dropLast(2),
                extraQuestionsLeft = prev.extraLeft,
            )
        }
        return prev.answer
    }

    fun requestIdeasNow(id: String) {
        val p = store.get(id) ?: return
        // 추가 질문을 하다가 멈추면 지금까지의 추가 답을 반영한 새 아이디어를 받는다.
        if (p.inExtraQuestions) discoveryRequest(id, Protocol.freshIdeasMessage(previousTitles(p)), OpKind.IDEAS, fromExtra = true)
        else discoveryRequest(id, Protocol.REQUEST_IDEAS_NOW, OpKind.IDEAS)
    }

    fun moreIdeas(id: String) {
        val p = store.get(id) ?: return
        discoveryRequest(id, Protocol.moreIdeasMessage(previousTitles(p)), OpKind.IDEAS)
    }

    fun moreQuestions(id: String) {
        val p = store.get(id) ?: return
        val asked = p.turns.map { it.question.title }.filter { it.isNotBlank() }
        discoveryRequest(
            id, Protocol.moreQuestionsMessage(asked, previousTitles(p)), OpKind.ASKING,
            extraAfter = { isQuestion -> if (isQuestion) Protocol.EXTRA_QUESTIONS - 1 else -1 },
            fromExtra = true,
        )
    }

    fun variation(id: String, idea: Idea, direction: String) =
        discoveryRequest(id, Protocol.variationMessage(idea, direction), OpKind.IDEAS, label = idea.title)

    fun combine(id: String, a: Idea, b: Idea) =
        discoveryRequest(id, Protocol.combineMessage(a, b), OpKind.IDEAS, label = "${a.title} + ${b.title}")

    private fun previousTitles(p: Project): List<String> = p.allIdeas.map { it.title }.distinct()

    private fun discoveryRequest(
        id: String,
        text: String,
        kind: OpKind,
        label: String = "",
        extraAfter: (Boolean) -> Int = { -1 },
        fromExtra: Boolean = false,
    ) {
        val p = store.get(id) ?: return
        val pending = p.currentTurn
        discoveryCall(id, kind, base = p.messages, userMsg = ChatMessage(ChatMessage.USER, text), onBeforeCommit = { proj ->
            // 답하지 않은 질문이 남아 있으면 건너뛴 것으로 처리한다.
            if (pending != null && proj.currentTurn != null) proj.copy(turns = proj.turns.dropLast(1) + pending.copy(answer = Answer(skipped = true))) else proj
        }, label = label, extraAfter = extraAfter, fromExtra = fromExtra)
    }

    /** 같은 아이디어인지 판단할 때 쓰는 비교용 문자열(공백·기호·대소문자 무시). */
    private fun ideaKey(s: String) = s.lowercase().filter { it.isLetterOrDigit() }

    /** [fresh] 가운데 이미 받은 아이디어와 제목이나 한 줄 소개가 같은 것. */
    private fun duplicatesOf(fresh: List<Idea>, previous: List<Idea>): List<Idea> {
        val titles = previous.map { ideaKey(it.title) }.toSet()
        val loglines = previous.map { ideaKey(it.logline) }.filter { it.length > 8 }.toSet()
        return fresh.filter { ideaKey(it.title) in titles || ideaKey(it.logline) in loglines }
    }

    private fun discoveryCall(
        id: String,
        kind: OpKind,
        base: List<ChatMessage>,
        userMsg: ChatMessage,
        onBeforeCommit: (Project) -> Project,
        label: String = "",
        extraAfter: (Boolean) -> Int = { -1 },
        fromExtra: Boolean = false,
    ) {
        launchOp(id, kind, retry = { discoveryCall(id, kind, base, userMsg, onBeforeCommit, label, extraAfter, fromExtra) }) {
            val messages = base + userMsg
            // 아이디어가 나올 차례일 때만 웹 검색을 준다(질문 단계의 비용·대기 시간을 늘리지 않으려고).
            val lastProgress = store.get(id)?.turns?.lastOrNull()?.progress ?: 0
            val search = settings.settings.value.webSearch && (kind == OpKind.IDEAS || lastProgress >= SEARCH_FROM_PROGRESS)
            val result = aiFor(id).turnStreaming(
                questionModel(kind),
                TurnRequest(
                    system = Protocol.discoverySystem(lang),
                    messages = messages,
                    schema = Protocol.discoverySchema,
                    effort = if (kind == OpKind.IDEAS) (if (deep) Effort.HIGH else Effort.MEDIUM) else (if (deep) Effort.MEDIUM else Effort.LOW),
                    webSearch = search,
                ),
            ) { text -> showPartial(id, text) }
            var reply = parse(result.text).let { r -> r.copy(ideas = r.ideas.map { it.copy(references = verifiedReferences(it.references, result.sources)) }) }
            if (!reply.isQuestion && !reply.isIdeas) throw AiError.BadResponse
            var history = messages + ChatMessage(ChatMessage.ASSISTANT, result.text)
            var usage = result.usage
            // 앞에서 받은 아이디어를 그대로 다시 보내면 겹치는 것을 빼고, 대부분 겹치면 한 번 더 요청한다.
            val previous = store.get(id)?.allIdeas.orEmpty()
            if (reply.isIdeas && previous.isNotEmpty() && store.get(id)?.isDemo != true) {
                val dups = duplicatesOf(reply.ideas, previous)
                if (reply.ideas.size - dups.size < MIN_FRESH_IDEAS) {
                    val ask = ChatMessage(ChatMessage.USER, Protocol.duplicateMessage(dups.map { it.title }, previous.map { it.title }.distinct()))
                    val again = aiFor(id).turn(
                        questionModel(OpKind.IDEAS),
                        TurnRequest(Protocol.discoverySystem(lang), history + ask, Protocol.discoverySchema, if (deep) Effort.HIGH else Effort.MEDIUM),
                    )
                    usage += again.usage
                    val r2 = parse(again.text)
                    if (!r2.isIdeas) {
                        settings.addUsage(usage)
                        throw AiError.BadResponse
                    }
                    history = history + ask + ChatMessage(ChatMessage.ASSISTANT, again.text)
                    reply = r2
                }
                val fresh = reply.ideas - duplicatesOf(reply.ideas, previous).toSet()
                if (fresh.isEmpty()) {
                    settings.addUsage(usage)
                    throw AiError.DuplicateIdeas
                }
                reply = reply.copy(ideas = fresh)
            }
            val finalHistory = history
            val finalUsage = usage
            val finalReply = reply
            // 중지된 작업이 늦게 돌아와도 결과를 저장하지 않는다.
            currentCoroutineContext().ensureActive()
            store.update(id) { proj0 ->
                val proj = onBeforeCommit(proj0)
                val reply = finalReply
                val withMsgs = proj.copy(
                    messages = finalHistory,
                    usage = proj.usage + finalUsage,
                    extraQuestionsLeft = extraAfter(reply.isQuestion),
                )
                if (reply.isQuestion) {
                    withMsgs.copy(
                        stage = ProjectStage.INTERVIEW,
                        turns = withMsgs.turns + Turn(reply.stage, reply.progress, reply.insight, reply.question, extraLeft = withMsgs.extraQuestionsLeft),
                    )
                } else {
                    val batchId = ProjectStore.newId().take(6)
                    withMsgs.copy(
                        stage = ProjectStage.IDEAS,
                        ideaBatches = withMsgs.ideaBatches + IdeaBatch(
                            id = batchId,
                            createdAt = System.currentTimeMillis(),
                            intro = reply.ideasIntro,
                            label = label,
                            ideas = reply.ideas.map { it.copy(id = "${batchId}_${it.id}") },
                            fromExtraQuestions = fromExtra,
                        ),
                    )
                }
            }
            settings.addUsage(finalUsage)
        }
    }

    // ------------------------------------------------------------ 아이디어 보관

    fun toggleSaved(id: String, ideaId: String) {
        store.update(id) { p ->
            p.copy(savedIdeaIds = if (ideaId in p.savedIdeaIds) p.savedIdeaIds - ideaId else p.savedIdeaIds + ideaId)
        }
    }

    // ------------------------------------------------------------ 설계 인터뷰

    fun startDesign(id: String, ideaId: String, depth: DocDepth, askQuestions: Boolean) {
        if (isBusy(id)) return
        val p = store.get(id) ?: return
        val idea = p.idea(ideaId) ?: return
        store.update(id) {
            val cur = it.design
            // 지금 설계서는 버리지 않는다: 다른 아이디어면 보관하고, 같은 아이디어면 버전 기록을 이어 간다.
            val stash = if (cur != null && cur.latest != null && cur.ideaId != ideaId) it.otherDesigns + (cur.ideaId to cur) else it.otherDesigns
            val keepVersions = when {
                cur != null && cur.ideaId == ideaId -> cur.versions
                else -> it.otherDesigns[ideaId]?.versions.orEmpty()
            }
            it.copy(
                design = DesignState(ideaId = ideaId, depth = depth, versions = keepVersions),
                otherDesigns = stash - ideaId,
                stage = if (askQuestions) ProjectStage.DESIGN_INTERVIEW else ProjectStage.DOCUMENT,
                title = if (it.titleEdited) it.title else idea.title,
                savedIdeaIds = if (ideaId in it.savedIdeaIds) it.savedIdeaIds else it.savedIdeaIds + ideaId,
            )
        }
        if (askQuestions) designStart(id) else generateDocument(id)
    }

    /** 설계 질문의 첫 요청. 중지·실패로 질문 없이 멈춘 설계를 다시 시작할 때도 쓴다. */
    fun designStart(id: String) {
        val p = store.get(id) ?: return
        val idea = p.selectedIdea ?: return
        val first = ChatMessage(ChatMessage.USER, Protocol.designStartMessage(p, idea, settings.settings.value.profile, lang))
        designCall(id, emptyList(), first) { it }
    }

    /** 보관해 둔 다른 아이디어의 설계서를 다시 연다. 지금 설계서는 보관한다. */
    fun openDesign(id: String, ideaId: String) {
        if (isBusy(id)) return
        store.update(id) { p ->
            val target = p.otherDesigns[ideaId] ?: return@update if (p.design?.ideaId == ideaId) p.copy(stage = ProjectStage.DOCUMENT) else p
            val cur = p.design
            val stash = (if (cur != null && cur.latest != null) p.otherDesigns + (cur.ideaId to cur) else p.otherDesigns) - ideaId
            val idea = p.idea(ideaId)
            p.copy(
                design = target,
                otherDesigns = stash,
                stage = ProjectStage.DOCUMENT,
                title = if (p.titleEdited || idea == null) p.title else Protocol.documentTitle(target.latest?.markdown.orEmpty())?.take(40) ?: idea.title,
            )
        }
    }

    fun designAnswer(id: String, answer: Answer) {
        val d = store.get(id)?.design ?: return
        val turn = d.turns.lastOrNull()?.takeIf { it.answer == null } ?: return
        val msg = ChatMessage(ChatMessage.USER, Protocol.answerMessage(turn.question, answer))
        designCall(id, d.messages, msg) { ds -> ds.copy(turns = ds.turns.dropLast(1) + turn.copy(answer = answer)) }
    }

    fun designUndo(id: String): Answer? {
        if (isBusy(id)) return null
        val d = store.get(id)?.design ?: return null
        val last = d.turns.lastOrNull() ?: return null
        if (last.answer != null || d.turns.size < 2) return null
        val prev = d.turns[d.turns.size - 2]
        dismissError(id)
        store.update(id) {
            it.copy(design = d.copy(turns = d.turns.dropLast(2) + prev.copy(answer = null), messages = d.messages.dropLast(2)))
        }
        return prev.answer
    }

    fun designReadyNow(id: String) {
        val d = store.get(id)?.design ?: return
        val pending = d.turns.lastOrNull()?.takeIf { it.answer == null }
        designCall(id, d.messages, ChatMessage(ChatMessage.USER, Protocol.REQUEST_READY_NOW)) { ds ->
            if (pending != null) ds.copy(turns = ds.turns.dropLast(1) + pending.copy(answer = Answer(skipped = true))) else ds
        }
    }

    private fun designCall(id: String, base: List<ChatMessage>, userMsg: ChatMessage, onBeforeCommit: (DesignState) -> DesignState) {
        launchOp(id, OpKind.DESIGN_ASKING, retry = { designCall(id, base, userMsg, onBeforeCommit) }) {
            val depth = store.get(id)?.design?.depth ?: DocDepth.STANDARD
            val messages = base + userMsg
            val result = aiFor(id).turnStreaming(
                questionModel(OpKind.DESIGN_ASKING),
                TurnRequest(
                    system = Protocol.designSystem(lang, depth),
                    messages = messages,
                    schema = Protocol.designSchema,
                    effort = if (deep) Effort.HIGH else Effort.MEDIUM,
                ),
            ) { text -> showPartial(id, text) }
            val reply = parse(result.text)
            if (!reply.isQuestion && !reply.isReady) throw AiError.BadResponse
            currentCoroutineContext().ensureActive()
            store.update(id) { proj ->
                val d0 = proj.design ?: return@update proj
                val d1 = onBeforeCommit(d0).let { it.copy(messages = messages + ChatMessage(ChatMessage.ASSISTANT, result.text)) }
                val d2 = if (reply.isQuestion) {
                    d1.copy(turns = d1.turns + Turn(reply.stage, reply.progress, reply.insight, reply.question))
                } else {
                    d1.copy(readySummary = reply.readySummary)
                }
                proj.copy(design = d2, usage = proj.usage + result.usage, stage = if (reply.isReady) ProjectStage.DOCUMENT else ProjectStage.DESIGN_INTERVIEW)
            }
            settings.addUsage(result.usage)
            if (reply.isReady) {
                // 결정이 끝나면 곧바로 설계서 작성으로 넘어간다.
                nextAfter[id] = { generateDocument(id) }
            }
        }
    }

    // ------------------------------------------------------------ 설계서

    fun generateDocument(id: String) {
        val p = store.get(id) ?: return
        val idea = p.selectedIdea ?: return
        val request = Protocol.documentRequest(p, idea, settings.settings.value.profile, lang)
        streamDoc(id, OpKind.WRITING, listOf(ChatMessage(ChatMessage.USER, request)), note = "")
    }

    fun reviseDocument(id: String, instruction: String) {
        val p = store.get(id) ?: return
        val idea = p.selectedIdea ?: return
        val latest = p.design?.latest ?: return
        val request = Protocol.documentRequest(p, idea, settings.settings.value.profile, lang)
        val messages = listOf(
            ChatMessage(ChatMessage.USER, request),
            ChatMessage(ChatMessage.ASSISTANT, latest.markdown),
            ChatMessage(ChatMessage.USER, Protocol.revisionRequest(instruction)),
        )
        streamDoc(id, OpKind.REVISING, messages, note = instruction.trim())
    }

    /** 사용자가 직접 고친 설계서를 새 버전으로 저장한다(비용 없음). */
    fun saveManualEdit(id: String, markdown: String, note: String) {
        if (isBusy(id)) return
        val md = markdown.trim()
        if (md.isEmpty()) return
        store.update(id) { p ->
            val d = p.design ?: return@update p
            if (d.latest?.markdown?.trim() == md) return@update p
            p.copy(design = d.copy(versions = d.versions + DocVersion(ProjectStore.newId(), System.currentTimeMillis(), note, md, true)))
        }
    }

    fun restoreVersion(id: String, versionId: String, note: String) {
        if (isBusy(id)) return
        store.update(id) { p ->
            val d = p.design ?: return@update p
            val v = d.versions.firstOrNull { it.id == versionId } ?: return@update p
            p.copy(design = d.copy(versions = d.versions + v.copy(id = ProjectStore.newId(), createdAt = System.currentTimeMillis(), note = note)))
        }
    }

    private fun streamDoc(id: String, kind: OpKind, messages: List<ChatMessage>, note: String) {
        launchOp(id, kind, retry = { streamDoc(id, kind, messages, note) }) {
            val p = store.get(id) ?: return@launchOp
            val depth = p.design?.depth ?: DocDepth.STANDARD
            val sb = StringBuilder()
            var lastPush = 0L
            try {
                aiFor(id).stream(
                    model,
                    StreamRequest(
                        system = Protocol.documentSystem(lang, p.kind, depth),
                        messages = messages,
                        effort = if (deep) Effort.XHIGH else Effort.HIGH,
                    ),
                ).collect { ev ->
                    when (ev) {
                        is StreamEvent.Delta -> {
                            sb.append(ev.text)
                            val now = System.currentTimeMillis()
                            if (now - lastPush > 80) {
                                lastPush = now
                                setOp(id) { it.copy(streamingText = sb.toString()) }
                            }
                        }
                        is StreamEvent.Done -> {
                            val md = sb.toString().trim()
                            if (md.isEmpty()) throw AiError.BadResponse
                            currentCoroutineContext().ensureActive()
                            saveVersion(id, md, note, complete = !ev.truncated, usage = ev.usage)
                            settings.addUsage(ev.usage)
                        }
                    }
                }
            } catch (e: CancellationException) {
                // 사용자가 멈춘 경우: 잘린 원고를 새 버전으로 남기지 않는다.
                throw e
            } catch (e: Throwable) {
                // 처음 쓰다가 끊기면 받은 부분을 미완성 버전으로 남긴다.
                // 수정 중에 끊기면 잘린 원고가 최신본이 되지 않도록 이전 완성본을 그대로 둔다.
                val partial = sb.toString().trim()
                if (kind == OpKind.WRITING && partial.length > 200) saveVersion(id, partial, note, complete = false, usage = Usage())
                throw e
            }
        }
    }

    private fun saveVersion(id: String, md: String, note: String, complete: Boolean, usage: Usage) {
        store.update(id) { p ->
            val d = p.design ?: return@update p
            val v = DocVersion(ProjectStore.newId(), System.currentTimeMillis(), note, md, complete)
            val newTitle = Protocol.documentTitle(md)?.take(40)
            p.copy(
                design = d.copy(versions = d.versions + v),
                stage = ProjectStage.DOCUMENT,
                usage = p.usage + usage,
                title = if (d.versions.isEmpty() && newTitle != null && !p.titleEdited) newTitle else p.title,
            )
        }
    }

    // ------------------------------------------------------------ 기타 편집

    fun rename(id: String, title: String) {
        val t = title.trim().take(60)
        if (t.isEmpty()) return
        store.update(id) { it.copy(title = t, titleEdited = true) }
    }

    fun setFavorite(id: String, favorite: Boolean) = store.update(id) { it.copy(favorite = favorite) }

    fun setNote(id: String, note: String) = store.update(id) { it.copy(note = note) }

    /** 아이디어 목록으로 돌아가 다른 아이디어를 고를 수 있게 한다(설계 기록은 유지). */
    fun backToIdeas(id: String) = store.update(id) { it.copy(stage = ProjectStage.IDEAS) }

    fun openDocument(id: String) = store.update(id) { if (it.design?.latest != null) it.copy(stage = ProjectStage.DOCUMENT) else it }

    fun delete(id: String): Project? {
        cancel(id)
        return store.delete(id)
    }

    fun restore(project: Project) = store.upsert(project)

    // ------------------------------------------------------------ 작업 관리

    fun retry(id: String) {
        val r = retries[id] ?: return
        r()
    }

    fun dismissError(id: String) {
        _ops.update { it - id }
        retries.remove(id)
    }

    fun cancel(id: String) {
        jobs.remove(id)?.cancel()
        _ops.update { it - id }
    }

    /** 스트리밍 중인 질문을 화면에 미리 보여 준다. 바뀐 것이 없으면 상태를 건드리지 않는다. */
    private fun showPartial(id: String, text: String) {
        val pq = app.ember.ideas.ai.PartialJson.question(text) ?: return
        setOp(id) { if (it.partial == pq) it else it.copy(partial = pq) }
    }

    private fun setOp(id: String, f: (OpState) -> OpState) {
        _ops.update { m -> m[id]?.let { m + (id to f(it)) } ?: m }
    }

    private fun launchOp(id: String, kind: OpKind, retry: () -> Unit, block: suspend () -> Unit) {
        if (isBusy(id) || jobs[id]?.isActive == true) return
        retries[id] = retry
        // 월 예산을 넘었으면 요청을 보내지 않는다(체험 프로젝트는 비용이 없으므로 예외).
        if (store.get(id)?.isDemo != true && settings.overBudget()) {
            _ops.update { it + (id to OpState(kind, running = false, error = AiError.OverBudget)) }
            return
        }
        _ops.update { it + (id to OpState(kind)) }
        val job = scope.launch(start = CoroutineStart.LAZY) {
            val me = coroutineContext[Job]
            // 이 작업이 아직 이 프로젝트의 현재 작업인지. 중지된 뒤 늦게 끝난 작업은 새 작업의 상태를 건드리면 안 된다.
            fun mine() = jobs[id] === me
            var success = false
            try {
                block()
                success = true
            } catch (e: CancellationException) {
                if (mine()) {
                    _ops.update { it - id }
                    jobs.remove(id)
                }
                throw e
            } catch (e: AiError) {
                if (mine()) {
                    _ops.update { it + (id to OpState(kind, running = false, error = e)) }
                    _finished.tryEmit(OpFinished(id, kind, e))
                }
            } catch (e: Throwable) {
                if (mine()) {
                    val err = AiError.Other(e.message ?: e.javaClass.simpleName)
                    _ops.update { it + (id to OpState(kind, running = false, error = err)) }
                    _finished.tryEmit(OpFinished(id, kind, err))
                }
            }
            if (!mine()) return@launch
            if (success) {
                _finished.tryEmit(OpFinished(id, kind, null))
                _ops.update { it - id }
                retries.remove(id)
            }
            jobs.remove(id)
            if (success) nextAfter.remove(id)?.invoke() else nextAfter.remove(id)
        }
        jobs[id] = job
        job.start()
    }

    private fun parse(text: String): Protocol.InterviewReply = try {
        Protocol.parseReply(text)
    } catch (e: SerializationException) {
        throw AiError.BadResponse
    } catch (e: IllegalArgumentException) {
        throw AiError.BadResponse
    }
}
