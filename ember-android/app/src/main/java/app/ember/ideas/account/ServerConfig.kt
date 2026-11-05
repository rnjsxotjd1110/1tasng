package app.ember.ideas.account

import app.ember.ideas.BuildConfig

/**
 * 출시 빌드 설정. 빌드 때 gradle 속성으로 들어오며, 테스트에서는 [override] 로 바꿀 수 있다.
 * 서버 주소가 비어 있으면 크레딧 모드를 숨기고 '내 API 키' 방식만 보여 준다.
 */
object ServerConfig {
    data class Values(
        val serverUrl: String = BuildConfig.EMBER_SERVER_URL,
        val reportEmail: String = BuildConfig.REPORT_EMAIL,
        val privacyUrl: String = BuildConfig.PRIVACY_URL,
        val creditMarkup: Double = BuildConfig.CREDIT_MARKUP,
        val freeCredits: Int = BuildConfig.FREE_CREDITS,
    )

    @Volatile var override: Values? = null

    val values: Values get() = override ?: Values()
    val serverUrl: String get() = values.serverUrl.trimEnd('/')
    val creditsEnabled: Boolean get() = serverUrl.startsWith("https://") || serverUrl.startsWith("http://")

    /** Play 콘솔에 등록할 인앱 상품 ID 와 지급 크레딧(서버 PRODUCTS 기본값과 같다). */
    val products: List<Pair<String, Int>> = listOf(
        "ember_credits_500" to 500,
        "ember_credits_1500" to 1650,
        "ember_credits_5000" to 5750,
    )

    /** API 비용(USD)을 크레딧으로 바꾼다. 1 크레딧 = 수수료를 포함한 $0.01. */
    fun creditsFor(usd: Double): Int = kotlin.math.ceil(usd * 100 * values.creditMarkup).toInt().coerceAtLeast(1)
}
