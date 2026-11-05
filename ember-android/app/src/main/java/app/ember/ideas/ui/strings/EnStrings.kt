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

object EnStrings : Strings() {
    override val isKorean = false

    override val back = "Back"
    override val next = "Next"
    override val skip = "Skip"
    override val close = "Close"
    override val cancel = "Cancel"
    override val save = "Save"
    override val delete = "Delete"
    override val retry = "Try again"
    override val copy = "Copy"
    override val copied = "Copied to clipboard"
    override val share = "Share"
    override val more = "More"
    override val clear = "Clear"
    override val undo = "Undo"
    override val reset = "Reset"
    override val stop = "Stop"
    override val sample = "Sample"
    override val working = "Working"
    override val current = "Current"
    override val set = "Set"
    override val notSet = "Not set"
    override val later = "Maybe later"
    override val paste = "Paste"
    override val toggleVisibility = "Show or hide key"

    override fun relativeTime(ts: Long): String {
        val m = minutesAgo(ts)
        return when {
            m < 1 -> "just now"
            m < 60 -> "${m}m ago"
            m < 60 * 24 -> "${m / 60}h ago"
            m < 60 * 24 * 7 -> "${m / (60 * 24)}d ago"
            else -> SimpleDateFormat("MMM d", Locale.ENGLISH).format(Date(ts))
        }
    }
    override fun charCount(n: Int) = "%,d chars".format(Locale.ENGLISH, n)
    override fun compactNumber(n: Long): String = when {
        n >= 1_000_000 -> "%.1fM".format(Locale.ENGLISH, n / 1_000_000.0)
        n >= 1_000 -> "%.1fK".format(Locale.ENGLISH, n / 1_000.0)
        else -> n.toString()
    }
    override fun money(usd: Double) = if (usd < 0.01 && usd > 0) "< $0.01" else "$%.2f".format(Locale.ENGLISH, usd)

    override fun errorTitle(e: AiError) = when (e) {
        AiError.NoKey -> "An API key is needed"
        AiError.InvalidKey -> "Please check your API key"
        AiError.NoCredit -> "Out of credits"
        AiError.RateLimited -> "Too many requests"
        AiError.Overloaded -> "Claude is busy right now"
        AiError.Offline -> "You're offline"
        AiError.Refused -> "Claude can't help with this request"
        AiError.BadResponse -> "Couldn't read the response"
        AiError.ModelUnavailable -> "That model isn't available"
        AiError.OverBudget -> "Monthly budget reached"
        is AiError.Other -> "Something went wrong"
    }
    override fun errorBody(e: AiError) = when (e) {
        AiError.NoKey -> "Connect your Anthropic API key in Settings to get started."
        AiError.InvalidKey -> "The key is expired or mistyped. Check it in the console and connect again."
        AiError.NoCredit -> "Add credits under Billing in the Anthropic console, then try again."
        AiError.RateLimited -> "Wait about a minute, then try again."
        AiError.Overloaded -> "The servers are busy. Trying again shortly usually works."
        AiError.Offline -> "Check Wi‑Fi or mobile data. Saved projects are still available offline."
        AiError.Refused -> "Try rephrasing or taking a different direction."
        AiError.BadResponse -> "The response was malformed. Trying again usually fixes it."
        AiError.ModelUnavailable -> "Choose another model in Settings, or check this key's model access."
        AiError.OverBudget -> "Requests are paused because you hit your monthly budget. Raise or turn it off in Settings → Monthly budget."
        is AiError.Other -> e.detail.take(160).ifBlank { "Please try again in a moment." }
    }
    override val fixKey = "Reconnect key"

    override val onb1Title = "Just answer\nquestion cards"
    override val onb1Body = "Claude asks what you want to make, where, and for whom — one card at a time. Tapping is enough."
    override val onb2Title = "Get ideas that\nfit you"
    override val onb2Body = "Your answers become original game and app ideas. Save, remix and combine the ones you like."
    override val onb3Title = "Design it, then\ncontinue in Claude"
    override val onb3Body = "Turn an idea into a build-ready design doc and carry it into Claude with one tap."
    override val getStarted = "Get started"

    override val keyTitleSettings = "API key"
    override val keyHeadline = "Connect Claude"
    override val keyBody = "Ember calls Claude directly with your own Anthropic API key. No server and no computer needed — just your phone."
    override fun keyCurrent(hint: String) = "Connected · $hint"
    override val keyFormatError = "Keys start with sk-ant-. Paste the whole key without spaces."
    override val keyModelError = "The key works but can't use the selected model. Try another model in Settings."
    override val keySecureNote = "Your key is encrypted in this device's secure storage and only ever sent to Anthropic."
    override val keyMemoryNote = "Secure storage is unavailable here, so the key is forgotten when the app closes."
    override val keyGuideTitle = "Where do I get a key?"
    override val keyGuideSteps = listOf(
        "Sign in at console.anthropic.com.",
        "Go to Settings → API Keys and tap Create Key.",
        "Add a payment method and credits under Billing. You can start with $5, which covers about seven exploration + design-doc sets on Opus, or over a hundred on Haiku.",
        "Copy the key and paste it above.",
    )
    override val openConsole = "Open Anthropic console"
    override val keyCostNote = "You pay Anthropic directly for what you use. Settings shows an estimated cost."
    override val keyConnect = "Verify & connect"
    override val keyConnected = "Connected"
    override val removeKey = "Remove key"

    override fun greeting(hour: Int) = when (hour) {
        in 5..11 -> "Good morning"
        in 12..17 -> "Good afternoon"
        in 18..21 -> "Good evening"
        else -> "Hello, night owl"
    }
    override val homeHeadline = "What will you\nmake today?"
    override val homeSub = "Answer a few questions and Claude builds ideas and a design doc around you."
    override val pickKind = "What are you into?"
    override fun kindLabel(k: ProjectKind) = when (k) {
        ProjectKind.GAME -> "Game"
        ProjectKind.APP -> "App"
        ProjectKind.WEB -> "Web service"
        ProjectKind.ANY -> "Not sure yet"
    }
    override fun defaultProjectTitle(k: ProjectKind) = when (k) {
        ProjectKind.GAME -> "New game idea"
        ProjectKind.APP -> "New app idea"
        ProjectKind.WEB -> "New web idea"
        ProjectKind.ANY -> "New idea"
    }
    override val seedPlaceholder = "Any words on your mind? e.g. cats, my commute, studying alone"
    override val inspireMe = "Inspire me"
    override val inspirations = listOf(
        "Rainy days by the window", "A 20-minute subway commute", "Old photo albums", "Growing houseplants", "Studying alone",
        "A tiny corner shop", "Five minutes before sleep", "Letters between friends", "A day on a space station", "Retro handhelds",
        "Walking the dog", "Budget tracking", "Board game night", "A small island village", "Dream journals", "Collecting city maps",
    )
    override val pickKindFirst = "Pick a category first"
    override val connectToStart = "Connect Claude to start"
    override val startDiscovery = "Start finding ideas"
    override val noKeyHint = "Without a key you can still browse the sample project in your Library."
    override val continueSection = "Continue"
    override val recentDocs = "Recent design docs"
    override val seeAll = "See all"
    override val setProfileShort = "Profile"
    override val myProfile = "Profile"
    override val profileTipTitle = "Tell Ember about you"
    override val profileTipBody = "Knowing your experience and tools means fewer questions and more realistic ideas."
    override fun stageLabel(stage: ProjectStage) = when (stage) {
        ProjectStage.INTERVIEW -> "Exploring"
        ProjectStage.IDEAS -> "Ideas"
        ProjectStage.DESIGN_INTERVIEW -> "Designing"
        ProjectStage.DOCUMENT -> "Design doc"
    }
    override fun answeredN(n: Int) = "$n answered"
    override fun ideasCount(n: Int) = "$n ideas"

    override fun questionN(n: Int) = "Question $n"
    override fun answersSoFar(n: Int) = "My $n answers"
    override val multiHint = "Pick as many as you like"
    override val singleHint = "Pick one"
    override val customAnswer = "Write my own"
    override val customPlaceholder = "Say it in your own words"
    override val previousQuestion = "Previous question"
    override val skipped = "Skipped"
    override val firstQuestionTitle = "Preparing your first question"
    override val nextQuestionTitle = "Choosing the next question"
    override val questionThinkingLines = listOf("Organizing your answers", "Looking for what's still unknown", "Writing easy-to-pick options")
    override val showIdeasNow = "Show ideas"
    override val backToIdeasShort = "To ideas"
    override val answersTitle = "Your answers so far"
    override val decisionsTitle = "Design decisions"
    override val resumeTitle = "Exploration paused"
    override val resumeBody = "The connection dropped before the first question. Resume to pick up where you left off."
    override val resume = "Resume"

    override val ideaThinkingTitle = "Picking ideas for you"
    override val ideaThinkingLines = listOf("Connecting the tastes in your answers", "Checking it's not a copy of something else", "Fitting it to your scope")
    override fun allIdeas(n: Int) = "All $n"
    override fun savedIdeas(n: Int) = "Saved $n"
    override val latestIdeas = "Fresh ideas"
    override val earlierIdeas = "Earlier ideas"
    override fun variationOf(label: String) = "Remix of “$label”"
    override val noSavedIdeas = "No saved ideas yet. Tap the heart on a card to keep it."
    override val ideasFooterHint = ""
    override val moreQuestions = "More questions"
    override val moreIdeas = "More ideas"
    override val docReadyBanner = "You have a design doc for this"
    override val chosenIdea = "Being designed"
    override fun difficulty(d: Int) = "Difficulty $d/5"
    override val saveIdea = "Save"
    override val unsave = "Unsave"
    override val fieldCoreHook = "Core appeal"
    override val fieldFeatures = "Key features"
    override val fieldUnique = "What makes it different"
    override val fieldAudience = "Audience"
    override val fieldMonetization = "Monetization"
    override val fieldFit = "Why this fits you"
    override val fieldScope = "Scope"
    override val fieldDevTime = "Timeline"
    override val fieldDifficulty = "Difficulty"
    override val designThis = "Design this idea"
    override val vary = "Remix"
    override val combine = "Combine"
    override val sendIdeaToClaude = "Brainstorm with Claude"
    override val varyTitle = "How should we remix it?"
    override fun varySub(title: String) = "Get 4 new ideas based on “$title”."
    override val varyPresets = listOf("Smaller scope", "Multiplayer", "Different genre", "More unusual", "For kids", "More profitable")
    override val varyPlaceholder = "Describe the direction you want"
    override val makeVariations = "Get remixes"
    override val combineTitle = "Combine with which idea?"
    override fun combineSub(title: String) = "Blend the best of “$title” and the idea you pick."

    override val designSetupTitle = "Create a design doc"
    override fun designSetupSub(title: String) = "How deep should the design for “$title” go?"
    override fun depthTitle(d: DocDepth) = when (d) {
        DocDepth.BRIEF -> "Quick brief"
        DocDepth.STANDARD -> "Standard design doc"
        DocDepth.BUILD_READY -> "Build-ready spec"
    }
    override fun depthBody(d: DocDepth) = when (d) {
        DocDepth.BRIEF -> "To check the direction fast"
        DocDepth.STANDARD -> "Features, screens and roadmap"
        DocDepth.BUILD_READY -> "Numbers, tables and folder structure"
    }
    override val askDesignQuestions = "Answer design questions first"
    override val askDesignQuestionsBody = "Pick engine, art style, core loop and more as cards for a far more accurate doc."
    override val startDesign = "Start designing"
    override val designFirstTitle = "Lining up the key decisions"
    override val designThinkingLines = listOf("Finding the decisions that matter for building", "Choosing recommendations for your setup")
    override val writeDocNow = "Write the doc now"

    override val writingTitle = "Writing your design doc"
    override val revisingTitle = "Revising your design doc"
    override val docThinkingLines = listOf("Laying out the structure", "Prioritizing features", "Planning the roadmap")
    override fun versionLabel(n: Int) = "v$n"
    override val incompleteDoc = "This doc was cut off. Regenerate to write it again from the start."
    override val incomplete = "Incomplete"
    override val regenerate = "Regenerate"
    override val regenerateAll = "Rewrite the doc"
    override val regenerateBody = "Rewrites the design doc from your decisions. Older versions stay in the history."
    override val followWriting = "Jump to latest"
    override val revise = "Revise"
    override val continueInClaude = "Continue in Claude"
    override val reviseTitle = "What should change?"
    override val reviseSub = "A new version is created and older ones stay in the history."
    override val revisePresets = listOf("Simpler", "More detail", "Smaller MVP", "Stronger monetization", "Concrete tech stack", "Realistic schedule")
    override val revisePlaceholder = "Anything else? (optional) e.g. halve the first release scope"
    override val applyRevision = "Create new version"
    override val versionsTitle = "Version history"
    override val versionsSub = "Restoring adds the old version as a new one."
    override val restore = "Restore"
    override fun restoredNote(n: Int) = "Restored v$n"
    override val copyDocument = "Copy design doc"
    override val viewIdeas = "View idea list"
    override val viewDocument = "Back to design doc"

    override val handoffTitle = "Continue in Claude"
    override val handoffSubApp = "Sends everything to a new chat in the Claude app. Using the Claude app doesn't spend API credits."
    override val handoffSubWeb = "Opens a new chat on claude.ai. It doesn't use API credits; it runs on your Claude account (free plan works)."
    override fun goalTitle(g: HandoffGoal) = when (g) {
        HandoffGoal.START_BUILD -> "Start building"
        HandoffGoal.CONTINUE_DESIGN -> "Refine the design"
        HandoffGoal.REVIEW -> "Get blunt feedback"
        HandoffGoal.BRAINSTORM -> "Brainstorm freely"
    }
    override fun goalBody(g: HandoffGoal) = when (g) {
        HandoffGoal.START_BUILD -> "Stack check → folder structure → first task in code. Also works in Claude Code on your PC"
        HandoffGoal.CONTINUE_DESIGN -> "Spot gaps and ask the remaining decisions one by one"
        HandoffGoal.REVIEW -> "Market fit, differentiation, scope, three biggest risks"
        HandoffGoal.BRAINSTORM -> "Strengthen the core appeal and find surprising twists"
    }
    override val includeLabel = "Include"
    override val includeAnswers = "Discovery & design answers"
    override val includeDocument = "Full design doc"
    override val includeProfile = "Developer profile"
    override val handoffExtraPlaceholder = "Anything else to tell Claude? (optional)"
    override val previewPrompt = "Preview prompt"
    override val openClaudeApp = "Open Claude app"
    override val openClaudeWeb = "Open claude.ai"
    override val copyPrompt = "Copy prompt"
    override val openedClaudeApp = "Sent to the Claude app"
    override val openedClaudeWeb = "Opened claude.ai with your prompt"
    override val openedPaste = "Prompt copied — paste it into Claude"
    override val openFailed = "No app could open this. The prompt is copied"

    override val rename = "Rename"
    override val renamePlaceholder = "Project name"
    override val favorite = "Pin to top"
    override val unfavorite = "Unpin"
    override val deleteTitle = "Delete this project?"
    override fun deleteBody(title: String) = "All questions, ideas and docs in “$title” will be removed."
    override fun deletedProject(title: String) = "Deleted “$title”"
    override val projectMissingTitle = "Project not found"
    override val projectMissingBody = "It may have been deleted."

    override val libraryTitle = "Library"
    override val searchPlaceholder = "Search projects and ideas"
    override fun tabProjects(n: Int) = "Projects $n"
    override fun tabSavedIdeas(n: Int) = "Saved ideas $n"
    override fun filterLabel(f: LibraryFilter) = when (f) {
        LibraryFilter.ALL -> "All"
        LibraryFilter.FAVORITE -> "Pinned"
        LibraryFilter.EXPLORING -> "Exploring"
        LibraryFilter.IDEAS -> "Ideas"
        LibraryFilter.DOCS -> "Design docs"
    }
    override val libraryEmptyTitle = "No projects yet"
    override val libraryEmptyBody = "Pick a category on Home and find your first idea."
    override val startNew = "Find a new idea"
    override val noResultsTitle = "No results"
    override val noResultsBody = "Try another search or filter."
    override val noSavedTitle = "No saved ideas"
    override val noSavedBody = "Tap the heart on any idea card to collect it here."

    override val settingsTitle = "Settings"
    override val groupClaude = "Claude"
    override val groupPersonal = "Personalize"
    override val groupUsage = "Usage"
    override val groupData = "Data"
    override val groupAbout = "About"
    override val apiKey = "API key"
    override val notConnected = "Not connected"
    override val model = "Model"
    override fun modelName(m: ClaudeModel) = when (m) {
        ClaudeModel.OPUS -> "Claude Opus 5.5"
        ClaudeModel.SONNET -> "Claude Sonnet 5.5"
        ClaudeModel.HAIKU -> "Claude Haiku 5.5"
    }
    override fun modelBody(m: ClaudeModel) = when (m) {
        ClaudeModel.OPUS -> "Deepest ideas and designs, highest cost"
        ClaudeModel.SONNET -> "Fast, balanced quality at half the cost of Opus. Plenty for getting started"
        ClaudeModel.HAIKU -> "Fastest and cheapest, great for light browsing"
    }
    override val deepThinking = "Think deeper"
    override val deepThinkingBody = "Claude thinks longer for better ideas and docs. Takes and costs 30–60% more."
    override val devProfile = "Developer profile"
    override val devProfileBody = "Your experience, tools and team shape every question"
    override val language = "Language"
    override val languageBody = "Changes both the app and Claude's replies."
    override fun languageName(l: LanguageMode) = when (l) {
        LanguageMode.AUTO -> "Use device setting"
        LanguageMode.KO -> "한국어"
        LanguageMode.EN -> "English"
    }
    override val theme = "Theme"
    override fun themeName(t: ThemeMode) = when (t) {
        ThemeMode.SYSTEM -> "Use device setting"
        ThemeMode.LIGHT -> "Light"
        ThemeMode.DARK -> "Dark"
    }
    override val haptics = "Haptic feedback"
    override val usageRequests = "Requests"
    override val usageTokens = "Tokens"
    override val usageCost = "All-time cost"
    override val usageNote = "Estimated from public pricing. See the Anthropic console for exact billing."
    override val resetUsage = "Reset usage"
    override val resetUsageBody = "Sets the request, token and cost counters back to zero."
    override val exportAll = "Export all projects"
    override val exportAllBody = "Share or save a JSON backup"
    override val addSample = "Add the sample project again"
    override val sampleAdded = "Sample project added"
    override val deleteAll = "Delete all projects"
    override val deleteAllBody = "Removes every project on this device. This can't be undone."
    override val deletedAll = "All projects deleted"
    override val about = "About Ember"
    override val privacyNote = "Your key and projects stay on this device. Questions and answers are sent to the Anthropic API only when Claude is called."
    override val aboutBody = "Ember is a design studio that finds game and app ideas that fit you through question cards, shapes them into build-ready design docs, and hands them to Claude."
    override val licenses = "Open-source licenses"
    override val trademarkNote = "Claude and Anthropic are trademarks of Anthropic PBC. Ember is not an official Anthropic app."

    override val profileIntro = "Everything here is shared as background in every interview and design. You can leave it blank."
    override val profileExperience = "Experience"
    override val experienceOptions = listOf("Total beginner", "Under 1 year", "1–3 years", "3+ years", "Professional", "PM / planner (no coding)")
    override val profileTools = "Tools & engines you can use"
    override val toolOptions = listOf("Godot", "Unity", "Unreal Engine", "Flutter", "React Native", "Kotlin/Android", "Swift/iOS", "React/Web", "Python", "No-code tools")
    override val addToolPlaceholder = "Add another tool (press done)"
    override val profileTeam = "Who's building"
    override val teamOptions = listOf("Just me", "2–3 people", "Team of 4+")
    override val profileNotes = "Anything else"
    override val profileNotesPlaceholder = "e.g. I can draw pixel art. I only build on weekends."


    override fun questionOf(n: Int, total: Int) = "Question $n of ~${maxOf(total, n)}"
    override val waitingNote = "This keeps going if you leave the app and is saved to this project."
    override val doLater = "Leave and continue later"
    override val designThisShort = "Design this"
    override val details = "Details"
    override val tryDifferently = "Try something different"
    override val brainstormWithClaude = "Brainstorm with Claude"
    override fun decisionsCount(n: Int) = "$n decisions"
    override fun sectionProgress(done: Int, total: Int) = "Section $done/$total"
    override val writingNote = "Writing continues if you leave the app. Stopping keeps what's written so far."
    override val claudeWebNote = "claude.ai uses your Claude account, separate from your API key. The free plan works too."
    override fun handoffDocName(title: String) = "Sending · $title"
    override val pin = "Pin to top"
    override val unpin = "Unpin"
    override fun costApprox(usd: Double) = if (usd < 0.01) "< $0.01" else "~$" + "%.2f".format(java.util.Locale.ENGLISH, usd)
    override fun costPerDiscovery(cost: String, model: String) = "One exploration $cost ($model)"
    override fun depthMeta(d: DocDepth, cost: String, minutes: String) = when (d) {
        DocDepth.BRIEF -> "2–3 pages · ~3 questions · $cost · ~$minutes"
        DocDepth.STANDARD -> "5–8 pages · ~6 questions · $cost · ~$minutes"
        DocDepth.BUILD_READY -> "10+ pages · ~9 questions · $cost · ~$minutes"
    }
    override fun reviseCost(cost: String) = "Each new version costs $cost"
    override fun modelShort(m: ClaudeModel) = when (m) {
        ClaudeModel.OPUS -> "Opus\u00A05.5"
        ClaudeModel.SONNET -> "Sonnet\u00A05.5"
        ClaudeModel.HAIKU -> "Haiku\u00A05.5"
    }
    override fun modelSetCost(cost: String) = "Exploration + standard doc: $cost"
    override val quickIdeas = "Skip questions, get ideas now"
    override val demoTry = "Try it without a key"
    override val demoBanner = "Demo mode: questions and results are pre-made, so your answers aren't used."
    override val demoConnect = "Connect Claude"
    override val demoTitle = "Demo: Commute game"
    override val keyStoredNote = "Your key stays on this device and is only ever sent to Anthropic."
    override val profileButton = "Profile"
    override fun profileSummary(experience: String, tools: List<String>) =
        listOfNotNull(experience.takeIf { it.isNotBlank() }, tools.firstOrNull()?.let { if (tools.size > 1) "$it +${tools.size - 1}" else it }).joinToString(" · ").ifEmpty { "Set" }
    override val recommended = "Recommended"
    override val moreActions = "More actions"

    override fun minutes(lo: Int, hi: Int) = "$lo–$hi min"

    override fun yourAnswer(a: String) = "Your answer · $a"
    override val previousShort = "Back"
    override val compare = "Compare"
    override val compareTitle = "Compare ideas"
    override val compareSub = "Scope, difficulty, appeal, monetization and edge for each idea, in the same order."
    override fun openIdea(title: String) = "Open “$title”"
    override fun goalShort(g: HandoffGoal) = when (g) {
        HandoffGoal.START_BUILD -> "Jump into code"
        HandoffGoal.CONTINUE_DESIGN -> "Fill in decisions"
        HandoffGoal.REVIEW -> "Check risks"
        HandoffGoal.BRAINSTORM -> "Widen the idea"
    }
    override val exportClaudeMd = "Export CLAUDE.md for Claude Code"
    override val errorSafeNote = "Failed requests aren't billed, and your answers so far are saved."

    override val fieldSimilar = "Similar works"
    override val fieldRisks = "Biggest risks"
    override val fieldValidation = "Cheapest way to validate"
    override val easiest = "Easiest"
    override val exportClaudeMdBody = "A design file Claude Code on your PC reads from the repo"
    override val monthlyBudget = "Monthly budget"
    override val budgetBody = "Requests pause and you're told when this month's estimated cost reaches the budget."
    override val budgetOptionsUsd = listOf(0.0, 5.0, 10.0, 25.0)
    override fun budgetLabel(usd: Double) = if (usd <= 0) "None" else money(usd)
    override fun thisMonth(used: String, budget: String?) = if (budget == null) "This month $used" else "This month $used of $budget"
    override fun budgetWarn(pct: Int) = "You've used $pct% of this month's budget"
    override fun writingNow(title: String) = "Writing · $title"
    override fun remaining(min: Int) = if (min <= 1) "Under a minute left" else "About $min min left"

    override val nextQuestionTag = "Next"
    override val newIdeaHeadline = "Find a new idea"

    override fun costPreview(discovery: String, doc: String) = "On Opus, one exploration is about $discovery and a standard design doc about $doc. Sonnet costs half, Haiku far less."
    override val resend = "Send again"
    override fun compareCount(n: Int) = "$n ideas · swipe sideways"

    override val tabHome = "Home"
    override val tabLibrary = "Library"
    override val tabSettings = "Settings"
}
