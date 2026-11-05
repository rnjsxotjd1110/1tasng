package app.ember.ideas

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Inventory2
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import app.ember.ideas.data.LanguageMode
import app.ember.ideas.data.Project
import app.ember.ideas.data.ThemeMode
import app.ember.ideas.ui.components.EmberBackground
import app.ember.ideas.ui.screens.AboutScreen
import app.ember.ideas.ui.screens.ApiKeyScreen
import app.ember.ideas.ui.screens.HomeScreen
import app.ember.ideas.ui.screens.LibraryScreen
import app.ember.ideas.ui.screens.OnboardingScreen
import app.ember.ideas.ui.screens.ProfileScreen
import app.ember.ideas.ui.screens.SettingsScreen
import app.ember.ideas.ui.screens.project.ProjectScreen
import app.ember.ideas.ui.strings.LocalStrings
import app.ember.ideas.ui.strings.stringsFor
import app.ember.ideas.ui.theme.DarkEmber
import app.ember.ideas.ui.theme.Ember
import app.ember.ideas.ui.theme.EmberTheme
import app.ember.ideas.ui.theme.LightEmber
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        val settings = container.settings
        setContent {
            val st by settings.settings.collectAsState()
            val dark = when (st.theme) {
                ThemeMode.DARK -> true
                ThemeMode.LIGHT -> false
                ThemeMode.SYSTEM -> (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
            }
            androidx.compose.runtime.LaunchedEffect(dark) {
                val bg = (if (dark) DarkEmber.bg else LightEmber.bg).toArgb()
                enableEdgeToEdge(
                    statusBarStyle = if (dark) SystemBarStyle.dark(bg) else SystemBarStyle.light(bg, bg),
                    navigationBarStyle = if (dark) SystemBarStyle.dark(bg) else SystemBarStyle.light(bg, bg),
                )
            }
            EmberRoot(st.theme, st.language, st.onboarded)
        }
    }
}

@Composable
fun EmberRoot(theme: ThemeMode, language: LanguageMode, onboarded: Boolean, startRoute: String? = null) {
    EmberTheme(theme) {
        CompositionLocalProvider(LocalStrings provides stringsFor(language)) {
            val nav = rememberNavController()
            EmberNavHost(nav, startRoute ?: if (onboarded) "main" else "onboarding")
        }
    }
}

@Composable
fun EmberNavHost(nav: NavHostController, start: String) {
    val ctx = LocalContext.current
    val settings = ctx.container.settings
    NavHost(
        nav,
        startDestination = start,
        enterTransition = { slideInHorizontally(tween(260)) { it / 5 } + fadeIn(tween(260)) },
        exitTransition = { fadeOut(tween(180)) },
        popEnterTransition = { fadeIn(tween(220)) },
        popExitTransition = { slideOutHorizontally(tween(220)) { it / 5 } + fadeOut(tween(220)) },
    ) {
        composable("onboarding") {
            OnboardingScreen(onFinish = {
                settings.setOnboarded(true)
                if (settings.settings.value.hasKey) {
                    nav.navigate("main") { popUpTo("onboarding") { inclusive = true } }
                } else {
                    nav.navigate("key?from=onboarding") { popUpTo("onboarding") { inclusive = true } }
                }
            })
        }
        composable("key?from={from}", arguments = listOf(navArgument("from") { type = NavType.StringType; defaultValue = "settings" })) { entry ->
            val from = entry.arguments?.getString("from") ?: "settings"
            val fromOnboarding = from == "onboarding"
            ApiKeyScreen(
                fromSettings = !fromOnboarding,
                onDone = {
                    if (fromOnboarding) nav.navigate("main") { popUpTo(0) { inclusive = true } } else nav.popBackStack()
                },
                onBack = if (fromOnboarding) null else ({ nav.popBackStack() }),
            )
        }
        composable("main") {
            MainTabs(
                onOpenProject = { nav.navigate("project/$it") },
                onOpenKey = { nav.navigate("key?from=settings") },
                onOpenProfile = { nav.navigate("profile") },
                onOpenAbout = { nav.navigate("about") },
            )
        }
        composable("project/{id}") { entry ->
            val id = entry.arguments?.getString("id") ?: ""
            ProjectScreen(id, onBack = { nav.popBackStack() }, onFixKey = { nav.navigate("key?from=settings") })
        }
        composable("profile") { ProfileScreen { nav.popBackStack() } }
        composable("about") { AboutScreen { nav.popBackStack() } }
    }
}

@Composable
fun MainTabs(
    onOpenProject: (String) -> Unit,
    onOpenKey: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenAbout: () -> Unit,
    initialTab: Int = 0,
) {
    val s = LocalStrings.current
    val c = Ember.colors
    val ctx = LocalContext.current
    var tab by rememberSaveable { mutableIntStateOf(initialTab) }
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    fun onDeleted(p: Project) {
        scope.launch {
            val r = snackbar.showSnackbar(s.deletedProject(p.title), actionLabel = s.undo, duration = SnackbarDuration.Long)
            if (r == SnackbarResult.ActionPerformed) ctx.container.engine.restore(p)
        }
    }

    EmberBackground(glow = tab == 0) {
        Column(Modifier.fillMaxSize()) {
            Box(Modifier.weight(1f)) {
                AnimatedContent(tab, transitionSpec = { fadeIn(tween(180)) togetherWith fadeOut(tween(120)) }, label = "tab") { t ->
                    when (t) {
                        0 -> HomeScreen(onOpenProject, onNeedKey = onOpenKey, onOpenProfile = onOpenProfile, onOpenLibrary = { tab = 1 })
                        1 -> LibraryScreen(onOpenProject, onStartNew = { tab = 0 }, onDeleted = ::onDeleted)
                        else -> SettingsScreen(onOpenKey, onOpenProfile, onOpenAbout)
                    }
                }
                SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter).padding(16.dp)) { data ->
                    Snackbar(
                        data,
                        containerColor = c.surface3,
                        contentColor = c.text,
                        actionColor = c.ember,
                        shape = RoundedCornerShape(16.dp),
                    )
                }
            }
            BottomBar(tab) { tab = it }
        }
    }
}

@Composable
private fun BottomBar(selected: Int, onSelect: (Int) -> Unit) {
    val s = LocalStrings.current
    val c = Ember.colors
    Column(Modifier.fillMaxWidth().background(c.bg)) {
        Box(Modifier.fillMaxWidth().height(1.dp).background(c.outline.copy(alpha = 0.6f)))
        Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 12.dp, vertical = 6.dp)) {
            TabItem(Icons.Rounded.Home, s.tabHome, selected == 0, Modifier.weight(1f)) { onSelect(0) }
            TabItem(Icons.Rounded.Inventory2, s.tabLibrary, selected == 1, Modifier.weight(1f)) { onSelect(1) }
            TabItem(Icons.Rounded.Settings, s.tabSettings, selected == 2, Modifier.weight(1f)) { onSelect(2) }
        }
    }
}

@Composable
private fun TabItem(icon: ImageVector, label: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val c = Ember.colors
    val haptic = LocalHapticFeedback.current
    Column(
        modifier
            .clip(RoundedCornerShape(16.dp))
            .clickable(role = Role.Tab) {
                haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.TextHandleMove)
                onClick()
            }
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier
                .clip(CircleShape)
                .background(if (selected) c.emberSoft else androidx.compose.ui.graphics.Color.Transparent)
                .padding(horizontal = 18.dp, vertical = 4.dp),
        ) {
            Icon(icon, label, tint = if (selected) c.ember else c.textFaint, modifier = Modifier.size(24.dp))
        }
        Spacer(Modifier.height(2.dp))
        Text(label, style = MaterialTheme.typography.labelSmall, color = if (selected) c.text else c.textFaint)
    }
}
