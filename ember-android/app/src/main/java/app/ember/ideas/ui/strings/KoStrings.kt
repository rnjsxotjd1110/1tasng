package app.ember.ideas.ui.strings

import app.ember.ideas.ai.AiError
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.data.DocDepth
import app.ember.ideas.data.LanguageMode
import app.ember.ideas.data.ProjectKind
import app.ember.ideas.data.ProjectStage
import app.ember.ideas.data.ThemeMode
import app.ember.ideas.handoff.HandoffGoal
import app.ember.ideas.ui.screens.LibraryFilter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object KoStrings : Strings() {
    override val isKorean = true

    override val back = "뒤로"
    override val next = "다음"
    override val skip = "건너뛰기"
    override val close = "닫기"
    override val cancel = "취소"
    override val save = "저장"
    override val delete = "삭제"
    override val retry = "다시 시도"
    override val copy = "복사"
    override val copied = "클립보드에 복사했어요"
    override val share = "공유"
    override val more = "더 보기"
    override val clear = "지우기"
    override val undo = "되돌리기"
    override val reset = "초기화"
    override val stop = "멈추기"
    override val sample = "예시"
    override val working = "작업 중"
    override val current = "현재"
    override val set = "설정됨"
    override val notSet = "미설정"
    override val later = "나중에 할게요"
    override val paste = "붙여넣기"
    override val toggleVisibility = "키 보기/숨기기"

    override fun relativeTime(ts: Long): String {
        val m = minutesAgo(ts)
        return when {
            m < 1 -> "방금"
            m < 60 -> "${m}분 전"
            m < 60 * 24 -> "${m / 60}시간 전"
            m < 60 * 24 * 7 -> "${m / (60 * 24)}일 전"
            else -> SimpleDateFormat("M월 d일", Locale.KOREAN).format(Date(ts))
        }
    }

    override fun charCount(n: Int) = "%,d자".format(n)
    override fun compactNumber(n: Long): String = when {
        n >= 100_000_000 -> "%.1f억".format(n / 100_000_000.0)
        n >= 10_000 -> "%.1f만".format(n / 10_000.0)
        else -> "%,d".format(n)
    }
    override fun money(usd: Double) = if (usd <= 0.0) "₩0" else costApprox(usd).removePrefix("약 ")

    override fun errorTitle(e: AiError) = when (e) {
        AiError.NoKey -> "API 키가 필요해요"
        AiError.InvalidKey -> "API 키를 확인해 주세요"
        AiError.NoCredit -> "크레딧이 부족해요"
        AiError.RateLimited -> "요청이 잠시 몰렸어요"
        AiError.Overloaded -> "Claude가 잠시 바빠요"
        AiError.Offline -> "인터넷에 연결되어 있지 않아요"
        AiError.Refused -> "이 요청에는 답할 수 없어요"
        AiError.BadResponse -> "응답을 읽지 못했어요"
        AiError.ModelUnavailable -> "선택한 모델을 쓸 수 없어요"
        AiError.OverBudget -> "이번 달 예산을 다 썼어요"
        is AiError.Other -> "문제가 생겼어요"
    }

    override fun errorBody(e: AiError) = when (e) {
        AiError.NoKey -> "설정에서 Anthropic API 키를 연결하면 바로 시작할 수 있어요."
        AiError.InvalidKey -> "키가 만료되었거나 잘못 입력되었어요. 콘솔에서 키를 확인한 뒤 다시 연결해 주세요."
        AiError.NoCredit -> "Anthropic 콘솔의 Billing에서 크레딧을 충전한 뒤 다시 시도해 주세요."
        AiError.RateLimited -> "1분쯤 기다렸다가 다시 시도해 주세요."
        AiError.Overloaded -> "서버가 혼잡해요. 잠시 후 다시 시도하면 대부분 해결돼요."
        AiError.Offline -> "Wi‑Fi나 모바일 데이터를 확인해 주세요. 저장된 프로젝트는 오프라인에서도 볼 수 있어요."
        AiError.Refused -> "표현을 바꾸거나 다른 방향으로 요청해 주세요."
        AiError.BadResponse -> "응답 형식이 어긋났어요. 다시 시도하면 대부분 해결돼요."
        AiError.ModelUnavailable -> "설정에서 다른 모델을 고르거나, 이 키에 모델 권한이 있는지 확인해 주세요."
        AiError.OverBudget -> "설정한 월 예산에 도달해 요청을 멈췄어요. 설정 → 월 예산에서 한도를 올리거나 끌 수 있어요."
        is AiError.Other -> e.detail.take(160).ifBlank { "잠시 후 다시 시도해 주세요." }
    }
    override val fixKey = "키 다시 연결"

    override val onb1Title = "질문 카드에\n답하기만 하세요"
    override val onb1Body = "Claude가 무엇을, 어디서, 누구를 위해 만들고 싶은지 하나씩 물어봐요. 고르기만 해도 충분해요."
    override val onb2Title = "나에게 꼭 맞는\n아이디어를 받아요"
    override val onb2Body = "답변을 바탕으로 독창적인 게임·앱 아이디어를 제안해요. 마음에 드는 것은 찜하고, 섞고, 변형할 수 있어요."
    override val onb3Title = "설계서까지 만들고\nClaude로 이어가요"
    override val onb3Body = "고른 아이디어로 개발에 바로 쓸 설계서를 만들고, 버튼 하나로 Claude에서 작업을 이어가요."
    override val getStarted = "시작하기"

    override val keyTitleSettings = "API 키"
    override val keyHeadline = "Claude 연결하기"
    override val keyBody = "Ember는 내 Anthropic API 키로 Claude를 직접 불러요. 서버를 거치지 않아 컴퓨터 없이 휴대폰만으로 쓸 수 있어요."
    override fun keyCurrent(hint: String) = "연결됨 · $hint"
    override val keyFormatError = "키는 sk-ant-로 시작해야 해요. 공백 없이 전체를 붙여 넣어 주세요."
    override val keyModelError = "키는 맞지만 선택한 모델을 쓸 권한이 없어요. 설정에서 모델을 바꿔 보세요."
    override val keySecureNote = "키는 이 기기의 보안 저장소에 암호화되어 저장되고, Anthropic 외에는 어디에도 보내지 않아요."
    override val keyMemoryNote = "이 기기는 보안 저장소를 쓸 수 없어 앱을 닫으면 키가 지워져요."
    override val keyGuideTitle = "API 키는 어디서 받나요?"
    override val keyGuideSteps = listOf(
        "console.anthropic.com에 접속해 로그인해요.",
        "Settings → API Keys에서 Create Key를 눌러요.",
        "Billing에서 결제 수단을 등록하고 크레딧을 충전해요. 최소 $5(약 7,000원)부터 충전할 수 있고, Opus 기준 아이디어 탐색과 설계서를 일곱 세트쯤, Haiku로는 백 번 넘게 만들 수 있어요.",
        "만든 키를 복사해 위 칸에 붙여 넣어요.",
    )
    override val openConsole = "Anthropic 콘솔 열기"
    override val keyCostNote = "요금은 사용한 만큼 Anthropic에 직접 결제돼요. 설정의 사용량에서 대략적인 비용을 확인할 수 있어요."
    override val keyConnect = "연결 확인"
    override val keyConnected = "연결됐어요"
    override val removeKey = "키 삭제"

    override fun greeting(hour: Int) = when (hour) {
        in 5..10 -> "좋은 아침이에요"
        in 11..16 -> "좋은 오후예요"
        in 17..21 -> "좋은 저녁이에요"
        else -> "늦은 밤에도 반가워요"
    }
    override val homeHeadline = "오늘은 무엇을\n만들어 볼까요?"
    override val homeSub = "질문 몇 개에 답하면 Claude가 나에게 맞는 아이디어와 설계서를 만들어 드려요."
    override val pickKind = "관심 있는 분야"
    override fun kindLabel(k: ProjectKind) = when (k) {
        ProjectKind.GAME -> "게임"
        ProjectKind.APP -> "앱"
        ProjectKind.WEB -> "웹 서비스"
        ProjectKind.ANY -> "아직 모르겠어요"
    }
    override fun defaultProjectTitle(k: ProjectKind) = when (k) {
        ProjectKind.GAME -> "새 게임 아이디어"
        ProjectKind.APP -> "새 앱 아이디어"
        ProjectKind.WEB -> "새 웹 서비스 아이디어"
        ProjectKind.ANY -> "새 아이디어"
    }
    override val seedPlaceholder = "떠오르는 단어나 생각이 있다면 적어 주세요 (선택)\n예: 고양이, 출퇴근 시간, 혼자 하는 공부"
    override val inspireMe = "영감 주사위"
    override val inspirations = listOf(
        "비 오는 날 창가에서 하는 것", "출퇴근 지하철 20분", "오래된 사진 앨범", "식물 키우기", "혼자 하는 공부",
        "동네 작은 가게", "잠들기 전 5분", "친구와 주고받는 편지", "우주 정거장의 하루", "레트로 게임기",
        "반려동물과 산책", "가계부 쓰기", "보드게임 밤", "작은 섬 마을", "꿈 일기", "도시 지도 수집",
    )
    override val pickKindFirst = "분야를 먼저 골라 주세요"
    override val connectToStart = "Claude 연결하고 시작하기"
    override val startDiscovery = "아이디어 찾기 시작"
    override val noKeyHint = "API 키 없이도 보관함의 예시 프로젝트는 둘러볼 수 있어요."
    override val continueSection = "이어서 하기"
    override val recentDocs = "최근 설계서"
    override val seeAll = "전체 보기"
    override val setProfileShort = "프로필"
    override val myProfile = "프로필"
    override val profileTipTitle = "개발자 프로필을 알려 주세요"
    override val profileTipBody = "경험과 쓰는 도구를 알면 질문이 줄고 아이디어가 더 현실적이 돼요."
    override fun stageLabel(stage: ProjectStage) = when (stage) {
        ProjectStage.INTERVIEW -> "탐색 중"
        ProjectStage.IDEAS -> "아이디어"
        ProjectStage.DESIGN_INTERVIEW -> "설계 중"
        ProjectStage.DOCUMENT -> "설계서"
    }
    override fun answeredN(n: Int) = "질문 ${n}개에 답했어요"
    override fun ideasCount(n: Int) = "아이디어 ${n}개"

    override fun questionN(n: Int) = "질문 $n"
    override fun answersSoFar(n: Int) = "답변 $n"
    override val multiHint = "여러 개 골라도 돼요"
    override val singleHint = "하나를 골라 주세요"
    override val customAnswer = "직접 입력하기"
    override val customPlaceholder = "생각을 자유롭게 적어 주세요"
    override val previousQuestion = "이전 질문"
    override val skipped = "건너뜀"
    override val firstQuestionTitle = "첫 질문을 준비하고 있어요"
    override val nextQuestionTitle = "다음 질문을 고르고 있어요"
    override val questionThinkingLines = listOf("답변을 정리하고 있어요", "아직 모르는 부분을 찾고 있어요", "고르기 쉬운 선택지를 만들고 있어요")
    override val showIdeasNow = "아이디어 보기"
    override val backToIdeasShort = "아이디어로"
    override val answersTitle = "지금까지의 답변"
    override val decisionsTitle = "확정된 설계 결정"
    override val resumeTitle = "탐색이 잠시 멈췄어요"
    override val resumeBody = "첫 질문을 받기 전에 연결이 끊겼어요. 다시 시작하면 이어서 진행해요."
    override val resume = "다시 시작"

    override val ideaThinkingTitle = "아이디어를 고르고 있어요"
    override val ideaThinkingLines = listOf("답변 속 취향을 연결하고 있어요", "비슷한 작품과 겹치지 않는지 보고 있어요", "개발 규모에 맞게 다듬고 있어요")
    override fun allIdeas(n: Int) = "전체 $n"
    override fun savedIdeas(n: Int) = "찜 $n"
    override val latestIdeas = "새로 받은 아이디어"
    override val earlierIdeas = "이전 아이디어"
    override fun variationOf(label: String) = "‘$label’ 변형"
    override val noSavedIdeas = "아직 찜한 아이디어가 없어요. 카드의 하트를 눌러 보관해 보세요."
    override val ideasFooterHint = ""
    override val moreQuestions = "질문 더 받기"
    override val moreIdeas = "다른 아이디어"
    override val docReadyBanner = "만들어 둔 설계서가 있어요"
    override val chosenIdea = "설계 중인 아이디어"
    override fun difficulty(d: Int) = "난이도 $d/5"
    override val saveIdea = "찜하기"
    override val unsave = "찜 해제"
    override val fieldCoreHook = "핵심 재미·가치"
    override val fieldFeatures = "주요 기능"
    override val fieldUnique = "차별점"
    override val fieldAudience = "대상"
    override val fieldMonetization = "수익 방식"
    override val fieldFit = "이 아이디어를 고른 이유"
    override val fieldScope = "규모"
    override val fieldDevTime = "예상 기간"
    override val fieldDifficulty = "난이도"
    override val designThis = "이 아이디어로 설계하기"
    override val vary = "변형하기"
    override val combine = "섞기"
    override val sendIdeaToClaude = "Claude와 브레인스토밍"
    override val varyTitle = "어떻게 바꿔 볼까요?"
    override fun varySub(title: String) = "‘$title’에서 출발한 새 아이디어 4개를 받아요."
    override val varyPresets = listOf("더 작은 규모로", "멀티플레이로", "다른 장르로", "더 독특하게", "아이들 대상으로", "수익성 높게")
    override val varyPlaceholder = "원하는 방향을 적어 주세요"
    override val makeVariations = "변형 아이디어 받기"
    override val combineTitle = "어떤 아이디어와 섞을까요?"
    override fun combineSub(title: String) = "‘$title’에 섞을 아이디어를 하나 골라 주세요."

    override val designSetupTitle = "설계서 만들기"
    override fun designSetupSub(title: String) = "‘$title’ · 설계 깊이를 골라 주세요. 비용과 시간은 현재 모델 기준이에요."
    override fun depthTitle(d: DocDepth) = when (d) {
        DocDepth.BRIEF -> "핵심 요약"
        DocDepth.STANDARD -> "표준 설계서"
        DocDepth.BUILD_READY -> "개발 착수용 설계서"
    }
    override fun depthBody(d: DocDepth) = when (d) {
        DocDepth.BRIEF -> "방향을 빠르게 확인할 때"
        DocDepth.STANDARD -> "기능·화면·로드맵까지"
        DocDepth.BUILD_READY -> "수치·표·폴더 구조까지"
    }
    override val askDesignQuestions = "설계 질문에 먼저 답하기"
    override val askDesignQuestionsBody = "엔진, 아트, 핵심 루프 같은 결정을 카드로 고르면 설계서가 훨씬 정확해져요."
    override val startDesign = "설계 시작"
    override val designFirstTitle = "설계에 필요한 결정을 정리하고 있어요"
    override val designThinkingLines = listOf("구현할 때 갈리는 결정을 찾고 있어요", "내 개발 환경에 맞는 추천안을 고르고 있어요")
    override val writeDocNow = "바로 설계서 쓰기"

    override val writingTitle = "설계서를 쓰고 있어요"
    override val revisingTitle = "설계서를 고치고 있어요"
    override val docThinkingLines = listOf("전체 구조를 잡고 있어요", "기능을 우선순위별로 나누고 있어요", "개발 로드맵을 짜고 있어요")
    override fun versionLabel(n: Int) = "v$n"
    override val incompleteDoc = "설계서가 중간에 끊겼어요. 다시 생성하면 처음부터 새로 써요."
    override val incomplete = "미완성"
    override val regenerate = "다시 생성"
    override val regenerateAll = "설계서 새로 쓰기"
    override val regenerateBody = "지금까지의 결정으로 설계서를 처음부터 다시 써요. 기존 버전은 버전 기록에 남아요."
    override val followWriting = "작성 위치로"
    override val revise = "수정 요청"
    override val continueInClaude = "Claude로 이어가기"
    override val reviseTitle = "무엇을 고칠까요?"
    override val reviseSub = "요청을 반영한 새 버전을 만들고, 이전 버전은 기록에 남겨요."
    override val revisePresets = listOf("더 간단하게", "더 자세하게", "MVP 범위 줄이기", "수익 모델 보강", "기술 스택 구체화", "일정을 현실적으로")
    override val revisePlaceholder = "추가로 바라는 점 (선택) 예: 첫 버전 범위를 절반으로 줄여 줘"
    override val applyRevision = "새 버전 만들기"
    override val versionsTitle = "버전 기록"
    override val versionsSub = "이전 버전을 복원하면 새 버전으로 추가돼요."
    override val restore = "복원"
    override fun restoredNote(n: Int) = "v$n 복원"
    override val copyDocument = "설계서 복사"
    override val viewIdeas = "아이디어 목록 보기"
    override val viewDocument = "설계서로 돌아가기"

    override val handoffTitle = "Claude로 이어가기"
    override val handoffSubApp = "정리한 내용을 Claude 앱의 새 대화로 보내요. Claude 앱 사용은 API 크레딧을 쓰지 않아요."
    override val handoffSubWeb = "claude.ai 새 대화로 보내요. API 크레딧은 쓰지 않고, 내 Claude 계정(무료 플랜 가능)으로 이어서 써요."
    override fun goalTitle(g: HandoffGoal) = when (g) {
        HandoffGoal.START_BUILD -> "개발 시작하기"
        HandoffGoal.CONTINUE_DESIGN -> "설계 더 다듬기"
        HandoffGoal.REVIEW -> "냉정한 피드백 받기"
        HandoffGoal.BRAINSTORM -> "자유롭게 브레인스토밍"
    }
    override fun goalBody(g: HandoffGoal) = when (g) {
        HandoffGoal.START_BUILD -> "기술 스택 확인 → 폴더 구조 → 첫 작업 코드까지. PC의 코딩 도구 Claude Code에 붙여 넣어도 좋아요"
        HandoffGoal.CONTINUE_DESIGN -> "빠진 부분을 짚고 남은 결정을 하나씩 질문해요"
        HandoffGoal.REVIEW -> "시장성, 차별점, 범위, 가장 큰 위험 3가지"
        HandoffGoal.BRAINSTORM -> "핵심 재미를 키우고 의외의 변형을 찾아요"
    }
    override val includeLabel = "함께 보낼 내용"
    override val includeAnswers = "탐색·설계 답변"
    override val includeDocument = "설계서 전문"
    override val includeProfile = "개발자 프로필"
    override val handoffExtraPlaceholder = "Claude에게 덧붙일 말 (선택)"
    override val previewPrompt = "보낼 프롬프트 미리 보기"
    override val openClaudeApp = "Claude 앱 열기"
    override val openClaudeWeb = "claude.ai 열기"
    override val copyPrompt = "프롬프트 복사"
    override val openedClaudeApp = "Claude 앱으로 보냈어요"
    override val openedClaudeWeb = "claude.ai를 열었어요. 프롬프트가 입력되어 있어요"
    override val openedPaste = "프롬프트를 복사했어요. Claude에서 붙여 넣어 주세요"
    override val openFailed = "열 수 있는 앱이 없어요. 프롬프트는 복사해 두었어요"

    override val rename = "이름 바꾸기"
    override val renamePlaceholder = "프로젝트 이름"
    override val favorite = "상단 고정"
    override val unfavorite = "고정 해제"
    override val deleteTitle = "프로젝트를 삭제할까요?"
    override fun deleteBody(title: String) = "‘$title’ 안의 질문, 아이디어, 설계서가 모두 사라져요."
    override fun deletedProject(title: String) = "프로젝트를 삭제했어요 · $title"
    override val projectMissingTitle = "프로젝트를 찾을 수 없어요"
    override val projectMissingBody = "삭제되었거나 다른 기기에서 옮겨진 프로젝트예요."

    override val libraryTitle = "보관함"
    override val searchPlaceholder = "프로젝트·아이디어 검색"
    override fun tabProjects(n: Int) = "프로젝트 $n"
    override fun tabSavedIdeas(n: Int) = "찜한 아이디어 $n"
    override fun filterLabel(f: LibraryFilter) = when (f) {
        LibraryFilter.ALL -> "전체"
        LibraryFilter.FAVORITE -> "고정됨"
        LibraryFilter.EXPLORING -> "탐색 중"
        LibraryFilter.IDEAS -> "아이디어"
        LibraryFilter.DOCS -> "설계서"
    }
    override val libraryEmptyTitle = "아직 프로젝트가 없어요"
    override val libraryEmptyBody = "홈에서 분야를 고르고 첫 아이디어를 찾아보세요."
    override val startNew = "새 아이디어 찾기"
    override val noResultsTitle = "찾는 결과가 없어요"
    override val noResultsBody = "다른 검색어나 필터를 써 보세요."
    override val noSavedTitle = "찜한 아이디어가 없어요"
    override val noSavedBody = "아이디어 카드의 하트를 누르면 여기에 모여요."

    override val settingsTitle = "설정"
    override val groupClaude = "Claude 연결"
    override val groupPersonal = "개인화"
    override val groupUsage = "사용량"
    override val groupData = "데이터"
    override val groupAbout = "정보"
    override val apiKey = "API 키"
    override val notConnected = "연결 안 됨"
    override val model = "모델"
    override fun modelName(m: ClaudeModel) = when (m) {
        ClaudeModel.OPUS -> "Claude Opus 5.5"
        ClaudeModel.SONNET -> "Claude Sonnet 5.5"
        ClaudeModel.HAIKU -> "Claude Haiku 5.5"
    }
    override fun modelBody(m: ClaudeModel) = when (m) {
        ClaudeModel.OPUS -> "가장 깊이 있는 아이디어와 설계, 비용이 가장 높아요"
        ClaudeModel.SONNET -> "빠르고 균형 잡힌 품질, 비용은 Opus의 절반. 처음이라면 이걸로도 충분해요"
        ClaudeModel.HAIKU -> "가장 빠르고 저렴해 가볍게 둘러볼 때 좋아요"
    }
    override val deepThinking = "깊게 생각하기"
    override val deepThinkingBody = "더 오래 생각해 아이디어와 설계서의 완성도를 높여요. 시간과 비용이 30~60% 늘어요."
    override val devProfile = "개발자 프로필"
    override val devProfileBody = "경험·도구·팀 규모를 모든 질문에 반영해요"
    override val language = "언어"
    override val languageBody = "화면과 Claude의 답변 언어를 함께 바꿔요."
    override fun languageName(l: LanguageMode) = when (l) {
        LanguageMode.AUTO -> "기기 설정 따르기"
        LanguageMode.KO -> "한국어"
        LanguageMode.EN -> "English"
    }
    override val theme = "테마"
    override fun themeName(t: ThemeMode) = when (t) {
        ThemeMode.SYSTEM -> "기기 설정 따르기"
        ThemeMode.LIGHT -> "라이트"
        ThemeMode.DARK -> "다크"
    }
    override val haptics = "진동 피드백"
    override val usageRequests = "요청"
    override val usageTokens = "토큰"
    override val usageCost = "누적 비용"
    override val usageNote = "공개 단가와 1달러 1,400원으로 계산한 추정치예요. 실제 청구는 달러로 되며 Anthropic 콘솔에서 확인할 수 있어요."
    override val resetUsage = "사용량 초기화"
    override val resetUsageBody = "누적 요청·토큰·비용 기록을 0으로 되돌려요."
    override val exportAll = "모든 프로젝트 내보내기"
    override val exportAllBody = "JSON 백업 파일을 공유하거나 저장해요"
    override val addSample = "예시 프로젝트 다시 추가"
    override val sampleAdded = "예시 프로젝트를 추가했어요"
    override val deleteAll = "모든 프로젝트 삭제"
    override val deleteAllBody = "이 기기의 모든 프로젝트를 지워요. 되돌릴 수 없어요."
    override val deletedAll = "모든 프로젝트를 삭제했어요"
    override val about = "Ember 정보"
    override val privacyNote = "API 키와 프로젝트는 이 기기에만 저장돼요. 질문과 답변은 Claude를 부를 때만 Anthropic API로 전송돼요."
    override val aboutBody = "Ember는 질문 카드로 나에게 맞는 게임·앱 아이디어를 찾고, 개발에 바로 쓸 설계서로 다듬어 Claude에서 이어갈 수 있게 돕는 설계 스튜디오예요."
    override val licenses = "오픈소스 라이선스"
    override val trademarkNote = "Claude와 Anthropic은 Anthropic PBC의 상표예요. Ember는 Anthropic의 공식 앱이 아니에요."

    override val profileIntro = "여기 적은 내용은 모든 인터뷰와 설계에 배경 정보로 들어가요. 비워 두어도 괜찮아요."
    override val profileExperience = "개발 경험"
    override val experienceOptions = listOf("처음이에요", "1년 미만", "1~3년", "3년 이상", "현업 개발자")
    override val profileTools = "쓸 수 있는 도구·엔진"
    override val toolOptions = listOf("Godot", "Unity", "Unreal Engine", "Flutter", "React Native", "Kotlin·Android", "Swift·iOS", "React·웹", "Python", "노코드 도구")
    override val addToolPlaceholder = "다른 도구 직접 추가"
    override val profileTeam = "함께 만드는 사람"
    override val teamOptions = listOf("혼자", "2~3명", "4명 이상 팀", "기획만 하고 개발은 맡겨요")
    override val profileNotes = "그 밖에 알려 줄 것"
    override val profileNotesPlaceholder = "예: 픽셀아트를 직접 그릴 수 있어요. 주말에만 개발해요."


    override fun questionOf(n: Int, total: Int) = "질문 $n / 약 ${maxOf(total, n)}"
    override val waitingNote = "앱을 나가도 계속 진행돼요. 끝나면 이 프로젝트에 저장돼요."
    override val doLater = "나가서 나중에 이어서 하기"
    override val designThisShort = "이걸로 설계"
    override val details = "자세히"
    override val tryDifferently = "다르게 해 보기"
    override val brainstormWithClaude = "Claude와 브레인스토밍"
    override fun decisionsCount(n: Int) = "결정 ${n}개"
    override fun sectionProgress(done: Int, total: Int) = "섹션 $done/$total"
    override val writingNote = "앱을 나가도 계속 써요. 멈추면 그때까지 쓴 부분이 저장돼요."
    override val claudeWebNote = "claude.ai는 API 키와 별개인 Claude 계정으로 로그인해서 써요. 무료 플랜으로도 쓸 수 있어요."
    override fun handoffDocName(title: String) = "보낼 설계서 · $title"
    override val pin = "상단 고정"
    override val unpin = "고정 해제"
    override fun costApprox(usd: Double): String {
        val krw = usd * 1400
        return when {
            krw < 10 -> "약 ₩10 미만"
            krw < 1000 -> "약 ₩${(Math.round(krw / 10).toInt().coerceAtLeast(1)) * 10}"
            else -> "약 ₩" + "%,d".format(Math.round(krw / 100).toInt() * 100)
        }
    }
    override fun costPerDiscovery(cost: String, model: String) = "탐색 1회 $cost ($model)"
    override fun depthMeta(d: DocDepth, cost: String, minutes: String) = when (d) {
        DocDepth.BRIEF -> "2~3쪽 분량 · 질문 약 3개 · $cost · 약 $minutes"
        DocDepth.STANDARD -> "5~8쪽 분량 · 질문 약 6개 · $cost · 약 $minutes"
        DocDepth.BUILD_READY -> "10쪽 이상 · 질문 약 9개 · $cost · 약 $minutes"
    }
    override fun reviseCost(cost: String) = "새 버전 한 번에 $cost"
    override fun modelShort(m: ClaudeModel) = when (m) {
        ClaudeModel.OPUS -> "Opus\u00A05.5"
        ClaudeModel.SONNET -> "Sonnet\u00A05.5"
        ClaudeModel.HAIKU -> "Haiku\u00A05.5"
    }
    override fun modelSetCost(cost: String) = "탐색과 표준 설계서 한 세트 $cost"
    override val quickIdeas = "질문 없이 바로 아이디어 받기"
    override val demoTry = "키 없이 체험해 보기"
    override val demoBanner = "체험 모드예요. 미리 준비된 질문과 결과라 내 답변은 반영되지 않아요."
    override val demoConnect = "Claude 연결"
    override val demoTitle = "체험 프로젝트"
    override val keyStoredNote = "키는 이 기기 안에만 저장되고 Anthropic 외에는 어디에도 보내지 않아요."
    override val profileButton = "프로필"
    override fun profileSummary(experience: String, tools: List<String>) =
        listOfNotNull(experience.takeIf { it.isNotBlank() }, tools.firstOrNull()?.let { if (tools.size > 1) "$it 외 ${tools.size - 1}" else it }).joinToString(" · ").ifEmpty { "설정됨" }
    override val recommended = "추천"
    override val moreActions = "더 많은 동작"

    override fun minutes(lo: Int, hi: Int) = "$lo~${hi}분"

    override fun yourAnswer(a: String) = "내 답변 · $a"
    override val previousShort = "이전"
    override val compare = "비교"
    override val compareTitle = "아이디어 비교"
    override val compareSub = "아이디어마다 규모·난이도·재미·수익·차별점을 같은 순서로 정리했어요."
    override fun openIdea(title: String) = "‘$title’ 자세히 보기"
    override fun goalShort(g: HandoffGoal) = when (g) {
        HandoffGoal.START_BUILD -> "코드로 바로 시작"
        HandoffGoal.CONTINUE_DESIGN -> "빠진 결정 채우기"
        HandoffGoal.REVIEW -> "위험과 약점 점검"
        HandoffGoal.BRAINSTORM -> "아이디어 넓히기"
    }
    override val exportClaudeMd = "Claude Code용 CLAUDE.md 내보내기"
    override val errorSafeNote = "실패한 요청에는 요금이 청구되지 않고, 지금까지의 답변은 그대로 저장되어 있어요."

    override val fieldSimilar = "참고할 작품"
    override val fieldRisks = "가장 큰 위험"
    override val fieldValidation = "가장 싸게 검증하는 법"
    override val easiest = "가장 쉬움"
    override val exportClaudeMdBody = "PC의 Claude Code가 저장소에서 바로 읽는 설계 파일이에요"
    override val monthlyBudget = "월 예산"
    override val budgetBody = "이번 달 예상 비용이 예산에 닿으면 요청을 멈추고 알려 드려요."
    override val budgetOptionsUsd = listOf(0.0, 5000 / 1400.0, 10000 / 1400.0, 30000 / 1400.0)
    override fun budgetLabel(usd: Double) = if (usd <= 0) "없음" else money(usd)
    override fun thisMonth(used: String, budget: String?) = if (budget == null) "이번 달 $used" else "이번 달 $used / 예산 $budget"
    override fun budgetWarn(pct: Int) = "이번 달 예산의 $pct%를 썼어요"
    override fun writingNow(title: String) = "지금 쓰는 중 · $title"
    override fun remaining(min: Int) = if (min <= 1) "1분 안에 끝나요" else "약 ${min}분 남았어요"

    override val nextQuestionTag = "다음 질문"
    override val newIdeaHeadline = "새 아이디어 찾기"

    override fun costPreview(discovery: String, doc: String) = "Opus 기준으로 아이디어 탐색 1회 $discovery, 표준 설계서 1편 $doc 정도예요. Sonnet은 절반, Haiku는 훨씬 저렴해요."
    override val resend = "다시 보내기"
    override fun compareCount(n: Int) = "아이디어 ${n}개 · 옆으로 밀어 보세요"

    override fun moreSections(n: Int) = "이어서 ${n}개 섹션을 더 써요"

    override val editDocument = "직접 편집"
    override val editDocumentSub = "Markdown 그대로 고칠 수 있어요. 저장하면 새 버전으로 남고 비용은 들지 않아요."
    override val editedNote = "직접 편집"
    override fun rewriteSection(title: String) = "‘$title’ 섹션만 더 구체적으로 다시 써 줘. 다른 섹션은 그대로 둬."
    override val rewriteSectionShort = "이 섹션 다시 쓰기"
    override val prepaidNote = "API는 콘솔에서 크레딧을 먼저 충전해야 쓸 수 있어요(최소 $5, 약 7,000원)."

    override val rewriteShort = "다시 쓰기"
    override val saveClaudeMd = "CLAUDE.md 저장"

    override val tabHome = "홈"
    override val tabLibrary = "보관함"
    override val tabSettings = "설정"
}
