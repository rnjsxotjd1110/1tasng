package app.ember.ideas.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ember.ideas.R
import app.ember.ideas.data.ThemeMode

/** Ember 의 색 토큰. 다크가 기본 정체성이고 라이트는 같은 위계를 따른다. */
@Immutable
data class EmberColors(
    val bg: Color,
    val surface: Color,
    val surface2: Color,
    val surface3: Color,
    val outline: Color,
    val text: Color,
    val textMuted: Color,
    val textFaint: Color,
    val ember: Color,
    val emberDeep: Color,
    val gold: Color,
    val onEmber: Color,
    val success: Color,
    val danger: Color,
    val info: Color,
    val selection: Color,
    val control: Color,
    val isDark: Boolean,
) {
    /** 장식용 밝은 그라데이션(아이콘·진행 막대 등 글자가 올라가지 않는 곳). */
    val emberGradient: Brush get() = Brush.linearGradient(listOf(Color(0xFFFFB067), Color(0xFFFF6A3D), Color(0xFFEE3F5C)))
    /** 흰 글자가 올라가는 버튼용 그라데이션. 모든 지점에서 흰 글자 대비 4.5:1 이상. */
    val buttonGradient: Brush get() = Brush.linearGradient(listOf(Color(0xFFCC4126), Color(0xFFC2362F), Color(0xFFB8304A)))
    val emberSoft: Color get() = ember.copy(alpha = if (isDark) 0.14f else 0.10f)
}

val DarkEmber = EmberColors(
    bg = Color(0xFF0F0E13),
    surface = Color(0xFF17161D),
    surface2 = Color(0xFF1F1D27),
    surface3 = Color(0xFF2A2733),
    outline = Color(0xFF353141),
    text = Color(0xFFF4F1EC),
    textMuted = Color(0xFFB0AABB),
    textFaint = Color(0xFF8E889A),
    ember = Color(0xFFFF7A45),
    emberDeep = Color(0xFFF2484E),
    gold = Color(0xFFFFC46B),
    onEmber = Color(0xFF1A0D08),
    success = Color(0xFF5ED3A0),
    danger = Color(0xFFFF6B6B),
    info = Color(0xFF8AB4FF),
    selection = Color(0x33FF7A45),
    control = Color(0xFF6A6478),
    isDark = true,
)

val LightEmber = EmberColors(
    bg = Color(0xFFFAF7F2),
    surface = Color(0xFFFFFFFF),
    surface2 = Color(0xFFF3EEE7),
    surface3 = Color(0xFFEAE3DA),
    outline = Color(0xFFC9BEB0),
    text = Color(0xFF1C1A22),
    textMuted = Color(0xFF5F5969),
    textFaint = Color(0xFF6E6874),
    ember = Color(0xFFC2410C),
    emberDeep = Color(0xFFD9363E),
    gold = Color(0xFF8F5F06),
    onEmber = Color(0xFFFFFFFF),
    success = Color(0xFF16915F),
    danger = Color(0xFFD23C3C),
    info = Color(0xFF2F6BD8),
    selection = Color(0x26E85A26),
    control = Color(0xFF9C9286),
    isDark = false,
)

val Pretendard = FontFamily(
    Font(R.font.pretendard_regular, FontWeight.Normal),
    Font(R.font.pretendard_medium, FontWeight.Medium),
    Font(R.font.pretendard_semibold, FontWeight.SemiBold),
    Font(R.font.pretendard_bold, FontWeight.Bold),
)

private val trim = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None)

private fun style(size: Float, line: Int, weight: FontWeight, spacing: Float = 0f) = TextStyle(
    fontFamily = Pretendard,
    fontWeight = weight,
    fontSize = size.sp,
    lineHeight = line.sp,
    letterSpacing = spacing.sp,
    lineHeightStyle = trim,
)

val EmberTypography = Typography(
    displayLarge = style(40f, 48, FontWeight.Bold, -1.0f),
    displayMedium = style(34f, 42, FontWeight.Bold, -0.8f),
    displaySmall = style(28f, 36, FontWeight.Bold, -0.6f),
    headlineLarge = style(26f, 34, FontWeight.Bold, -0.5f),
    headlineMedium = style(23f, 31, FontWeight.Bold, -0.4f),
    headlineSmall = style(20f, 28, FontWeight.SemiBold, -0.3f),
    titleLarge = style(19f, 26, FontWeight.SemiBold, -0.2f),
    titleMedium = style(16f, 23, FontWeight.SemiBold, -0.1f),
    titleSmall = style(14f, 20, FontWeight.SemiBold),
    bodyLarge = style(16f, 25, FontWeight.Normal),
    bodyMedium = style(14.5f, 22, FontWeight.Normal),
    bodySmall = style(13f, 19, FontWeight.Normal),
    labelLarge = style(15f, 20, FontWeight.SemiBold),
    labelMedium = style(13f, 18, FontWeight.Medium),
    labelSmall = style(11f, 15, FontWeight.Medium, 0.2f),
)

val EmberShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(18.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(32.dp),
)

val LocalEmber = staticCompositionLocalOf { DarkEmber }

object Ember {
    val colors: EmberColors @Composable get() = LocalEmber.current
}

@Composable
fun EmberTheme(mode: ThemeMode = ThemeMode.SYSTEM, content: @Composable () -> Unit) {
    val dark = when (mode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }
    val c = if (dark) DarkEmber else LightEmber
    val scheme = if (dark) {
        darkColorScheme(
            primary = c.ember, onPrimary = c.onEmber, primaryContainer = c.surface3, onPrimaryContainer = c.text,
            secondary = c.gold, onSecondary = c.onEmber, background = c.bg, onBackground = c.text,
            surface = c.surface, onSurface = c.text, surfaceVariant = c.surface2, onSurfaceVariant = c.textMuted,
            surfaceContainerLowest = c.bg, surfaceContainerLow = c.surface, surfaceContainer = c.surface,
            surfaceContainerHigh = c.surface2, surfaceContainerHighest = c.surface3,
            outline = c.outline, outlineVariant = c.outline, error = c.danger, inverseSurface = c.text, inverseOnSurface = c.bg,
        )
    } else {
        lightColorScheme(
            primary = c.ember, onPrimary = c.onEmber, primaryContainer = c.surface3, onPrimaryContainer = c.text,
            secondary = c.gold, onSecondary = c.onEmber, background = c.bg, onBackground = c.text,
            surface = c.surface, onSurface = c.text, surfaceVariant = c.surface2, onSurfaceVariant = c.textMuted,
            surfaceContainerLowest = c.surface, surfaceContainerLow = c.surface, surfaceContainer = c.surface,
            surfaceContainerHigh = c.surface2, surfaceContainerHighest = c.surface3,
            outline = c.outline, outlineVariant = c.outline, error = c.danger, inverseSurface = c.text, inverseOnSurface = c.bg,
        )
    }
    CompositionLocalProvider(LocalEmber provides c) {
        MaterialTheme(colorScheme = scheme, typography = EmberTypography, shapes = EmberShapes, content = content)
    }
}
