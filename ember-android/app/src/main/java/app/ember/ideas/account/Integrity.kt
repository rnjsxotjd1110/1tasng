package app.ember.ideas.account

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * Play Integrity classic 요청. 서버가 준 nonce 문자열을 그대로 넣는다(서버 README '앱 연동' 참고).
 * Play 스토어가 없거나 실패하면 null 을 돌려주고, 그때는 토큰 없이 가입한다.
 */
object Integrity {
    private const val TIMEOUT_MS = 15_000L

    suspend fun token(context: Context, nonce: String): String? = withTimeoutOrNull(TIMEOUT_MS) {
        suspendCancellableCoroutine { cont ->
            runCatching {
                IntegrityManagerFactory.create(context.applicationContext)
                    .requestIntegrityToken(IntegrityTokenRequest.builder().setNonce(nonce).build())
                    .addOnSuccessListener { if (cont.isActive) cont.resume(it.token()) }
                    .addOnFailureListener { if (cont.isActive) cont.resume(null) }
            }.onFailure { if (cont.isActive) cont.resume(null) }
        }
    }
}
