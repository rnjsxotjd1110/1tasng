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
    /** 열기 막대 가운데 칸(쇳물이 달아오르는 중간 색). */
    val heat: Color = Color(0xFFFF9A4F),
    /** 담금질한 강철. 완성 표시에만 쓴다. */
    val steel: Color = Color(0xFF8DB8FF),
) {
    val emberSoft: Color get() = ember.copy(alpha = if (isDark) 0.14f else 0.10f)
}

/** 대장간 팔레트: 그을음 바탕, 무쇠 카드, 이음매 테두리, 불씨·쇳물·강철 강조. */
val DarkEmber = EmberColors(
    bg = Color(0xFF141116),
    surface = Color(0xFF1E1A21),
    surface2 = Color(0xFF29242D),
    surface3 = Color(0xFF332D38),
    outline = Color(0xFF3A3340),
    text = Color(0xFFF3EEE8),
    textMuted = Color(0xFFB4AAB5),
    textFaint = Color(0xFF8D8391),
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
    heat = Color(0xFFD9701F),
    steel = Color(0xFF2F64C8),
)

/** IBM Plex Sans KR 하나로 제목부터 작은 글자까지 쓴다(기술 도면 같은 인상, 또렷한 한글). */
val Pretendard = FontFamily(
    Font(R.font.plex_regular, FontWeight.Normal),
    Font(R.font.plex_medium, FontWeight.Medium),
    Font(R.font.plex_semibold, FontWeight.SemiBold),
    Font(R.font.plex_bold, FontWeight.Bold),
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

/**
 * 모서리 위계. 크기가 클수록 조금 더 둥글게 하되 모두 작게 유지해 단단한 인상을 준다.
 * 큰 면(카드·시트) 12, 누르는 것(버튼·선택지·입력칸) 10, 작은 조각(칩) 8, 태그·체크 4.
 */
object EmberShape {
    val panel = RoundedCornerShape(12.dp)
    val control = RoundedCornerShape(10.dp)
    val chip = RoundedCornerShape(8.dp)
    val tag = RoundedCornerShape(4.dp)
    val bar = RoundedCornerShape(2.dp)
    val sheet = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)
}

val EmberShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(10.dp),
    large = RoundedCornerShape(12.dp),
    extraLarge = RoundedCornerShape(16.dp),
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
