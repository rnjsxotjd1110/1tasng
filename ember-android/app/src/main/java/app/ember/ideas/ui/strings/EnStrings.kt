package app.ember.ideas.ui.strings

import app.ember.ideas.ai.AiError
import app.ember.ideas.ai.ClaudeModel
import app.ember.ideas.data.DepthMode
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
        AiError.DuplicateIdeas -> "No new ideas came back"
        AiError.OutOfCredits -> "You're out of Ember credits"
        AiError.CreditCapped -> "The answer was cut short by your low balance"
        AiError.AccountHeld -> "Your credit usage is being checked"
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
        AiError.DuplicateIdeas -> "Claude repeated earlier ideas. Try again, or use More questions to steer in a new direction."
        AiError.OutOfCredits -> "Top up in Settings → Claude connection, or connect your own API key to keep going."
        AiError.CreditCapped -> "With few credits left, answers can only be short. Top up in Workshop → Claude connection and try again."
        AiError.AccountHeld -> "The server paused this account while it checks a usage record. Try again shortly, and contact us from About if it continues."
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
    override val seedPlaceholder = "Any words on your mind? (optional) e.g. cats, my commute"
    override val inspireMe = "Inspire me"
    override val inspirations = listOf(
        "Rainy days by the window", "A 20-minute subway commute", "Old photo albums", "Growing houseplants", "Studying alone",
        "A tiny corner shop", "Five minutes before sleep", "Letters between friends", "A day on a space station", "Retro handhelds",
        "Walking the dog", "Budget tracking", "Board game night", "A small island village", "Dream journals", "Collecting city maps",
    )
    override val pickKindFirst = "Pick a category first"
    override val connectToStart = "Connect Claude to start"
    override val startDiscovery = "Start with questions"
    override val noKeyHint = "Without a key you can still browse the sample projects in your Library."
    override val continueSection = "Continue"
    override val recentDocs = "Recent design docs"
    override val seeAll = "See all"
    override val setProfileShort = "Profile"
    override val myProfile = "Profile"
    override val profileTipTitle = "Tell Ember about you"
    override val profileTipBody = "Knowing your experience and tools means fewer questions and more realistic ideas."
    override fun stageLabel(stage: ProjectStage) = when (stage) {
        ProjectStage.INTERVIEW -> "Asking"
        ProjectStage.IDEAS -> "Picking ideas"
        ProjectStage.DESIGN_INTERVIEW -> "Designing"
        ProjectStage.DOCUMENT -> "Design doc"
    }
    override fun answeredN(n: Int) = "$n answered"
    override fun ideasCount(n: Int) = "$n ideas"

    override fun questionN(n: Int) = "Question $n"
    override fun answersSoFar(n: Int) = "See all $n struck answers"
    override val multiHint = "Pick as many as you like"
    override val singleHint = "Pick one"
    override val customAnswer = "Write my own"
    override val customPlaceholder = "Say it in your own words, or mix options like \"B+E\""
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
    override fun difficulty(d: Int) = difficultyEmoji(d) + " Difficulty $d/5 " + difficultyName(d)
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
    override val designThis = "Make a design doc"
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

    override val libraryTitle = "Blueprints"
    override val searchPlaceholder = "Search projects and ideas"
    override fun tabProjects(n: Int) = "Projects $n"
    override fun tabSavedIdeas(n: Int) = "Saved ideas $n"
    override fun filterLabel(f: LibraryFilter) = when (f) {
        LibraryFilter.ALL -> "All"
        LibraryFilter.FAVORITE -> "Pinned"
        LibraryFilter.EXPLORING -> "Asking"
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

    override val settingsTitle = "Workshop"
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
    override val experienceOptions = listOf("Total beginner", "Under 1 year", "1–3 years", "3+ years", "Professional")
    override val profileTools = "Tools & engines you can use"
    override val toolOptions = listOf("Godot", "Unity", "Unreal Engine", "Flutter", "React Native", "Kotlin/Android", "Swift/iOS", "React/Web", "Python", "No-code tools")
    override val addToolPlaceholder = "Add another tool (press done)"
    override val profileTeam = "Who's building"
    override val teamOptions = listOf("Just me", "2–3 people", "Team of 4+", "I plan, others build")
    override val profileNotes = "Anything else"
    override val profileNotesPlaceholder = "e.g. I can draw pixel art. I only build on weekends."


    override fun questionOf(n: Int, total: Int) = "Question $n of ~${maxOf(total, n)}"
    override val waitingNote = "This keeps going if you leave the app and is saved to this project."
    override val doLater = "Leave and continue later"
    override val designThisShort = "Make design doc"
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
    override val demoTitle = "Demo project"
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

    override fun costPreview(discovery: String, doc: String) = "On Opus, one exploration costs $discovery and a standard design doc $doc. Sonnet costs half, Haiku far less."
    override val resend = "Send again"
    override fun compareCount(n: Int) = "$n ideas · swipe sideways"

    override fun moreSections(n: Int) = "$n more sections to go"

    override val editDocument = "Edit directly"
    override val editDocumentSub = "Edit the Markdown as-is. Saving creates a new version at no cost."
    override val editedNote = "Edited directly"
    override fun rewriteSection(title: String) = "Rewrite only the “$title” section in more detail. Keep every other section unchanged."
    override val rewriteSectionShort = "Rewrite this section"
    override val prepaidNote = "The API needs prepaid credits from the console first (from $5)."

    override val rewriteShort = "Rewrite"
    override val saveClaudeMd = "Save CLAUDE.md"

    override val accessTabCredits = "Ember credits"
    override val accessTabKey = "My API key"
    override val creditsHeadline = "Start now, no sign-up"
    override fun creditsBody(free: Int, discoveries: Int) = "You get $free free credits, enough for about $discoveries idea sessions. When they run out, top up with Google Play."
    override val creditsStart = "Get free credits"
    override val creditsContinue = "Get started"
    override val creditsBalance = "Credits left"
    override fun creditsWorth(discoveries: Int, docs: Int) = "About $discoveries idea sessions or $docs standard design docs"
    override fun creditsUnit(discovery: Int, doc: Int) = "Credits only go down by what you use: about $discovery per idea session and $doc per standard design doc (Opus 5.5)."
    override val creditsPacks = "Top up"
    override fun creditsAmount(n: Int) = "%,d credits".format(java.util.Locale.ENGLISH, n)
    override val creditsPriceLoading = "Checking price"
    override val creditsRestore = "Restore purchases"
    override val creditsPrefer = "Use credits for requests"
    override val creditsPreferBody = "Uses credits even when an API key is connected. Turn off to use your key."
    override val creditsPending = "Your payment is pending. Credits are added as soon as it clears."
    override fun creditsAdded(total: Int) = "Topped up. You now have ${"%,d".format(java.util.Locale.ENGLISH, total)} credits."
    override val creditsFailed = "The purchase didn't finish. If you were charged but have no credits, tap Restore purchases."
    override val creditsUnavailable = "Google Play billing isn't available right now. Make sure the app came from the Play Store and you're signed in."
    override val creditsNote = "Credits belong to Ember on this device. With Android backup on they follow you to a new phone; uninstalling without a backup loses them."
    override val topUp = "Top up credits"
    override val accessTitle = "Claude connection"
    override fun creditsApprox(n: Int) = "~${"%,d".format(java.util.Locale.ENGLISH, n)} credits"

    override val reportAi = "Report AI content"
    override val reportTitle = "Report AI-generated content"
    override val reportSub = "Tell us about offensive, harmful, or wrong content. Reports are only used to fix the results."
    override val reportReasons = listOf("Offensive or harmful", "Factually wrong", "Possible copyright or trademark issue", "Contains personal information", "Something else")
    override val reportNoteHint = "What was wrong? (optional)"
    override fun reportIncludes(what: String) = "Sent along with your report: $what"
    override val reportWhatQuestion = "the question and options on screen"
    override val reportWhatIdeas = "the latest batch of ideas"
    override val reportWhatIdea = "this idea"
    override val reportWhatDocument = "the current design doc"
    override val reportSend = "Send report"
    override val reportSent = "Report sent. We'll review it and fix what we can."
    override val reportByEmail = "Your email app will open. Check the message and send it."
    override val privacyPolicy = "Privacy policy"
    override val privacyUpdated = "Effective November 5, 2026"
    override val privacySections = EnPolicy.sections

    override val contactUs = "Email support"

    override val notifChannelWork = "Work in progress"
    override val notifChannelDone = "Finished work"
    override fun notifWorking(count: Int, title: String) = if (count > 1) "Working on $count tasks" else "Working on “$title”"
    override val notifWorkingBody = "This keeps going if you leave the app. You'll get a notification when it's done."
    override fun notifDone(kind: app.ember.ideas.data.OpKind) = when (kind) { app.ember.ideas.data.OpKind.ASKING -> "Your next question is ready"; app.ember.ideas.data.OpKind.IDEAS -> "New ideas are in"; app.ember.ideas.data.OpKind.DESIGN_ASKING -> "Your design question is ready"; app.ember.ideas.data.OpKind.WRITING -> "Your design doc is done"; app.ember.ideas.data.OpKind.REVISING -> "Your design doc was updated" }
    override val notifFailed = "The task couldn't finish"
    override val notifyDoneSetting = "Notify when done"
    override val notifyDoneBody = "Get notified when questions, ideas, or docs are ready while you're away."

    override val crashTitle = "Ember closed unexpectedly last time"
    override val crashBody = "Sending the crash report helps us find the cause. It only contains device info and where the error happened, never your projects or keys."
    override val crashSend = "Send report"
    override val crashRow = "Send crash report"
    override fun crashCount(n: Int) = if (n == 0) "None" else "$n"

    override val webSearchSetting = "Search real works"
    override fun webSearchBody(cost: String) = "When suggesting ideas, Claude looks up similar games and apps on the web and leaves links. Each search adds $cost (up to 3)."
    override val fastQuestionsSetting = "Faster questions"
    override val fastQuestionsBody = "Question cards come from Sonnet 5.5 to cut waiting and cost. Ideas and docs still use your chosen model."
    override val fieldReferences = "Sources checked"

    override val attachImage = "Add image"
    override val removeImage = "Remove image"
    override val imageHint = "Add a sketch or reference screen and Claude reads its mood into the questions."
    override val imageFailed = "Couldn't load that image. Try another one."
    override fun imagesAttached(n: Int) = if (n == 1) "1 reference image" else "$n reference images"

    override val github = "Send to GitHub"
    override val githubConnect = "Connect GitHub"
    override val githubTokenBody = "Paste a GitHub personal access token. It's encrypted on this phone and only ever sent to GitHub."
    override val githubTokenSteps = listOf("Go to github.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens.", "Tap Generate new token and set Repository access to All repositories.", "Under Permissions, set Administration, Contents, and Issues to Read and write.", "Copy the token (github_pat_…) and paste it here.")
    override val githubOpenTokens = "Open the token page"
    override fun githubConnected(user: String) = "Connected as @$user"
    override val githubDisconnect = "Disconnect"
    override val githubNewRepo = "New repository"
    override val githubIssue = "Send as issues"
    override val githubRepoName = "Repository name"
    override val githubPrivate = "Private repository"
    override val githubPrivateBody = "Only you and people you invite can see it."
    override val githubRepoFiles = "Uploads README.md, CLAUDE.md, and docs/DESIGN.md. Clone it and Claude Code reads CLAUDE.md right away."
    override val githubCreateRepo = "Create repository"
    override val githubPickRepo = "Repository"
    override val githubPerSection = "One issue per section"
    override fun githubPerSectionBody(n: Int) = "Creates $n issues, one per top-level section. Off sends the whole doc as one issue."
    override fun githubSendIssues(n: Int) = if (n > 1) "Create $n issues" else "Create issue"
    override val githubNoRepos = "No repositories with issues yet. Create a new one first."
    override val githubDone = "Sent to GitHub"
    override val githubOpen = "Open on GitHub"
    override fun githubError(e: app.ember.ideas.handoff.GitHubError) = when (e) { app.ember.ideas.handoff.GitHubError.BadToken -> "The token is wrong or expired. Connect a new one."; app.ember.ideas.handoff.GitHubError.NoPermission -> "The token lacks permissions. Set Administration, Contents, and Issues to Read and write."; app.ember.ideas.handoff.GitHubError.NameTaken -> "A repository with that name already exists. Pick another name."; app.ember.ideas.handoff.GitHubError.Offline -> "Check your internet connection."; is app.ember.ideas.handoff.GitHubError.Other -> "GitHub rejected the request (${e.detail})." }

    override val importAll = "Import from file"
    override val importAllBody = "Merges projects from an exported backup (.json). For duplicates, the newer copy wins."
    override fun imported(n: Int) = if (n == 0) "Nothing new to import" else "Imported $n projects"
    override val importFailed = "That's not an Ember backup. Pick a file made with Export all projects."
    override val backupNote = "With Android backup on, projects and settings are backed up to your Google account. Keys and tokens are never included."
    override val eraseAll = "Erase all data"
    override val eraseAllBody = "Deletes projects, settings, API key, GitHub token, reference images, and crash logs from this phone, then starts over. This can't be undone."

    override val showChanges = "Changes"
    override fun diffTitle(from: Int, to: Int) = "Changes from v$from to v$to"
    override fun diffStats(added: Int, removed: Int) = "$added lines added, $removed removed"
    override fun diffSkip(n: Int) = "$n unchanged lines"
    override val diffNone = "These two versions are identical."

    override val editShort = "Edit"
    override fun editSectionTitle(name: String) = "Edit “$name”"
    override val editSectionSub = "Only this section changes. Saving makes a new version at no cost."
    override fun editedSectionNote(name: String) = "Edited “$name”"
    override val tabEdit = "Edit"
    override val tabPreview = "Preview"

    override val writingQuestion = "Writing your question"

    override val newIdeasNow = "Get new ideas"
    override fun extraQuestionOf(n: Int, total: Int) = "Extra question $n of $total"
    override val extraIdeasHeader = "Ideas from your extra answers"
    override fun combinedOf(label: String) = "Mix of $label"

    override val designResumeBody = "This stopped before the first design question arrived. Resume to get design questions for the chosen idea."
    override val docResumeTitle = "The design doc stopped before it was written"
    override val docResumeBody = "Resume to write the doc again from the decisions you've made."
    override val openDesignShort = "View doc"
    override val openDesign = "View this idea's design doc"

    override val tabOres = "Ores"
    override val heatStages = listOf("Ore", "Heat", "Forge", "Blueprint")
    override fun heatNow(stage: String, pct: Int) = "$stage $pct%"
    override val plateAnswer = "Answer"
    override val plateMold = "Mold"
    override val strike = "Strike"
    override val depthTitle = "Depth"
    override fun depthLabel(d: DepthMode) = when (d) { DepthMode.SHORT -> "Short"; DepthMode.NORMAL -> "Normal"; DepthMode.LONG -> "Long" }
    override fun depthHint(d: DepthMode) = when (d) { DepthMode.SHORT -> "About 5 questions"; DepthMode.NORMAL -> "About 9 questions"; DepthMode.LONG -> "Until you stop" }
    override fun depthSubtitle(d: DepthMode) = "Depth: " + depthLabel(d) + (if (d == DepthMode.LONG) " (no limit)" else "")
    override val dailySpark = "Today's spark"
    override val dailySparkBody = "A new theme every morning. If it catches you, start from it."
    override val startWithSpark = "Use this spark"
    override val otherSpark = "Another spark"
    override val forgeNew = "Start something new"
    override val whatToMake = "What will you make"
    override val moldsSkip = "Skip questions with a mold (saved answers)"
    override val manage = "Manage"
    override fun moldSkips(n: Int) = if (n == 1) "Skips 1 question" else "Skips $n questions"
    override val newMold = "New mold"
    override val seedForgePlaceholder = "A word or thought to start from"
    override val onTheFire = "On the fire"
    override fun countN(n: Int) = "$n"
    override val blueprintDone = "Doc ready"
    override val fromOreBox = "From notes"
    override val memoQuick = "Quick note"
    override val oreBoxTitle = "Ore box"
    override fun memosTab(n: Int) = "Notes $n"
    override fun savedTab(n: Int) = "Saved $n"
    override fun moldsTab(n: Int) = "Molds $n"
    override val memoPrompt = "Write it down before it fades"
    override val memoPlaceholder = "e.g. drawing roads with raindrops on a bus window #game"
    override val memoSave = "Keep"
    override val memoVoice = "Dictate"
    override val memoPhoto = "Attach photo"
    override val tagHint = "#tag"
    override val allTags = "All"
    override val pinned = "Pinned"
    override val forgeThisOre = "Start from this note"
    override fun ledToIdeas(n: Int) = if (n == 1) "Led to 1 idea" else "Led to $n ideas"
    override val memoEmptyTitle = "Your ore box is empty"
    override val memoEmptyBody = "Even one line from a walk counts. Keep it here and forge it whenever you like."
    override val savedEmptyTitle = "No saved ideas yet"
    override val savedEmptyBody = "Tap the heart on an idea card to keep it here."
    override val moldsEmptyTitle = "No molds yet"
    override val moldsEmptyBody = "Save the answers you always give (purpose, platform, genre) and those questions get skipped."
    override val memoDeleted = "Ore discarded"
    override val voiceUnavailable = "Voice input isn't available on this device."
    override fun fromProject(title: String) = "from $title"
    override val photoMemo = "Photo"
    override val moldTitle = "Mold"
    override val moldName = "Mold name"
    override val moldNamePlaceholder = "e.g. Weekend vibe coding"
    override fun moldCountLine(n: Int) = if (n == 1) "question skipped." else "questions skipped."
    override val moldCountBody = "What you set here won't be asked. The rest goes deeper."
    override val startWithMold = "Start with this mold"
    override val moldCustom = "Custom"
    override val moldCustomHint = "Type your own answer"
    override val deleteMold = "Delete mold"
    override val moldNeedsName = "Give it a name"
    override val depthDefault = "Default"
    override fun usedTimes(n: Int) = if (n == 1) "Used once" else "Used $n times"
    override val oresTitle = "New ideas"
    override val extraReflected = "Reflects extra answers"
    override val scoreFun = "Fun"
    override val scoreEase = "Ease"
    override val scoreNovel = "Novelty"
    override val detailsShort = "Details"
    override val temperedDone = "Tempered"
    override val sendToBench = "Send to workbench"
    override fun benchConnected(name: String) = "Workbench connected: $name"
    override val benchOffline = "Workbench is offline"
    override val benchNone = "Connect a workbench (PC) to send design docs straight to it"
    override val whatToSend = "What to send"
    override val sendStart = "Start building"
    override val sendNext = "Next task"
    override val sendFiles = "Design doc + CLAUDE.md"
    override val howToOpen = "How to open it on the PC"
    override val howCode = "Run in Claude Code"
    override fun howCodeDesc(folder: String) = "Folder: $folder"
    override val howClip = "Put on the PC clipboard"
    override val howClipDesc = "Paste it wherever you like"
    override val howFile = "Save files in the project folder"
    override val sendAgain = "Send again"
    override val phoneShort = "Phone"
    override val benchShort = "Workbench"
    override fun sentCode(claudeFound: Boolean) = if (claudeFound) "Claude Code opened on the PC and started the first task." else "Claude Code wasn't found on the PC, so the prompt went to the clipboard and was saved as a file."
    override val sentClip = "It's on the PC clipboard. Just paste it."
    override fun sentFiles(n: Int, folder: String) = "Saved $n files in $folder."
    override val changeShort = "Change"
    override val benchOnlineLine = "Same Wi‑Fi, Ember Bridge on"
    override val benchChecking = "Checking the workbench"
    override val benchOfflineBody = "Turn on Ember Bridge on the PC and make sure you're on the same Wi‑Fi."
    override val benchUnpaired = "The PC removed this phone. Pair it again."
    override val claudeAppShort = "Claude app"
    override val shareAsFile = "Share as file"
    override val benchSection = "Workbench (PC)"
    override val benchConnect = "Connect a PC"
    override val benchSearching = "Looking for Ember Bridge on this Wi‑Fi"
    override val benchNoneFound = "Nothing found yet. Check that the bridge is running and you're on the same Wi‑Fi, or enter the address yourself."
    override val benchManual = "Enter address"
    override val benchAddressHint = "Address on the PC screen (e.g. 192.168.0.12)"
    override val benchCodeTitle = "The 8-digit code on the PC screen"
    override val benchPair = "Pair"
    override val benchBadCode = "That code is wrong or expired. Check the code on the PC screen."
    override val benchRateLimited = "Too many tries. Wait a moment and try again."
    override val benchUnreachable = "Couldn't reach the PC. Check the bridge is running and you're on the same Wi‑Fi."
    override val benchRejected = "The PC refused the request."
    override fun benchPaired(name: String) = "Paired with $name"
    override val benchDisconnect = "Disconnect"
    override val benchFolder = "Default folder"
    override val benchFolderHint = "Leave empty to name it after the design doc"
    override val benchHowTo = "Install Ember Bridge on your PC"
    override val benchHowToBody = "1. Download the file for your OS from ember-bridge/dist in the Ember repository and run it on your PC.\n2. Type the 8-digit code shown on the PC here.\n3. On the same Wi‑Fi you can send from any blueprint."
    override val benchPrivacy = "What you send goes straight to the PC over your Wi‑Fi without any server. It isn't encrypted, so use it only on a Wi‑Fi you trust."
    override val corruptTitle = "Couldn't read your projects file"
    override val corruptBody = "The save file was damaged, so Ember started empty. The original is kept aside. Export it so you can try to recover it later."
    override val corruptExport = "Export original"

    override fun verifiedWorks(n: Int) = if (n == 1) "1 real work checked" else "$n real works checked"

    override val freeSonnetNote = "While you only have free credits, Sonnet answers instead of Opus. Buy credits once to unlock Opus."

    override fun kindShort(k: ProjectKind) = when (k) { ProjectKind.GAME -> "Game"; ProjectKind.APP -> "App"; ProjectKind.WEB -> "Web"; ProjectKind.ANY -> "Not sure" }

    override fun difficultyEmoji(d: Int) = when (d.coerceIn(1, 5)) { 1 -> "🌱"; 2 -> "🙂"; 3 -> "🔥"; 4 -> "⚡"; else -> "🌋" }
    override fun difficultyName(d: Int) = when (d.coerceIn(1, 5)) { 1 -> "Very easy"; 2 -> "Easy"; 3 -> "Moderate"; 4 -> "Hard"; else -> "Very hard" }
    override val devDifficulty = "Dev difficulty"
    override fun selectedN(n: Int) = "$n selected"
    override val selectAll = "Select all"
    override fun deleteIdeasTitle(n: Int) = if (n == 1) "Delete 1 idea?" else "Delete $n ideas?"
    override val deleteIdeasBody = "Deleted ideas can't be restored, and the same ideas won't be suggested again."
    override fun deleteIdeasDesignNote(n: Int) = if (n == 1) "One of them has a design doc. It will be deleted too." else "$n of them have design docs. Those will be deleted too."
    override fun ideasDeleted(n: Int) = if (n == 1) "Deleted 1 idea" else "Deleted $n ideas"
    override val longPressHint = "Long-press to select several and delete"
    override val noIdeasLeft = "No ideas left. Strike more or mine new ores below."
    override val busyCantDelete = "You can delete once the current task finishes."

    override fun deleteProjectsTitle(n: Int) = if (n == 1) "Delete 1 project?" else "Delete $n projects?"
    override val deleteProjectsBody = "Their ideas and design docs go too. You can undo right after from the notice at the bottom."
    override fun projectsDeleted(n: Int) = if (n == 1) "Deleted 1 project" else "Deleted $n projects"
    override val longPressProjectsHint = "Long-press to select several and delete"

    override val conceptEntry = "Write a concept, get ideas"
    override val conceptEntrySub = "4 ideas true to your concept, no questions"
    override val conceptTitle = "Ideas from your concept"
    override val conceptSub = "What you write stays as is. Only the parts you leave open are filled in differently for each idea. The more detail, the closer it gets."
    override val conceptPlaceholder = "e.g. Pixel-art idle RPG, 100 jobs, the fun is job combos in raids. Mobile portrait, 5-minute runs."
    override fun conceptMoldNote(name: String) = "Mold \"$name\" answers are kept too"
    override val conceptGo = "Get 4 ideas"

    override val pickMany = "Pick several"

    override val oreBoxSub = "Your notes, saved ideas and molds (saved answers)"
    override val librarySub = "All your projects and design docs"
    override val settingsSub = "Settings, Claude access and your PC (workbench)"

    override val tabHome = "Forge"
    override val tabLibrary = "Blueprints"
    override val tabSettings = "Workshop"
}
