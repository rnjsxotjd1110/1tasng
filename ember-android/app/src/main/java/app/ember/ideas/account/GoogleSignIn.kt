package app.ember.ideas.account

import android.content.Context
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import app.ember.ideas.BuildConfig

/** Google 로그인 결과. idToken 은 서버로만 보내고 저장하지 않는다. */
data class GoogleAccount(val idToken: String, val email: String)

/** 로그인이 안 된 이유. 화면에서 알맞은 안내를 고른다. */
sealed class GoogleSignInError(message: String) : Exception(message) {
    /** 사용자가 창을 닫았다. 안내 없이 그대로 둔다. */
    class Cancelled : GoogleSignInError("cancelled")
    /** 기기에 Google 계정이 없거나 Google Play 서비스를 쓸 수 없다. */
    class NoAccount : GoogleSignInError("no_account")
    /** 앱에 OAuth 클라이언트 ID 가 설정되지 않았다(개발용 빌드). */
    class NotConfigured : GoogleSignInError("not_configured")
    class Failed(detail: String) : GoogleSignInError(detail)
}

/**
 * Credential Manager 의 'Google 계정으로 로그인'.
 * 서버는 받은 ID 토큰의 sub(계정 고유 번호)만 쓰고 이메일·이름은 저장하지 않는다.
 * 이메일은 화면에 '연결된 계정'으로 보여 주려고 이 기기에만 둔다.
 */
object GoogleSignIn {
    val configured: Boolean get() = BuildConfig.GOOGLE_WEB_CLIENT_ID.isNotBlank()

    /** [activityContext] 는 Activity 여야 계정 선택 창이 뜬다. */
    suspend fun signIn(activityContext: Context): GoogleAccount {
        if (!configured) throw GoogleSignInError.NotConfigured()
        val option = GetSignInWithGoogleOption.Builder(BuildConfig.GOOGLE_WEB_CLIENT_ID).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        val result = try {
            CredentialManager.create(activityContext).getCredential(activityContext, request)
        } catch (e: GetCredentialCancellationException) {
            throw GoogleSignInError.Cancelled()
        } catch (e: NoCredentialException) {
            throw GoogleSignInError.NoAccount()
        } catch (e: GetCredentialException) {
            throw GoogleSignInError.Failed(e.type)
        }
        val cred = result.credential
        if (cred is CustomCredential && cred.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            val g = runCatching { GoogleIdTokenCredential.createFrom(cred.data) }.getOrElse { throw GoogleSignInError.Failed("parse") }
            return GoogleAccount(g.idToken, g.id)
        }
        throw GoogleSignInError.Failed("unexpected credential")
    }

    /** 다음에 로그인할 때 계정을 다시 고를 수 있게 이 기기의 로그인 상태를 지운다. */
    suspend fun signOut(context: Context) {
        runCatching { CredentialManager.create(context).clearCredentialState(ClearCredentialStateRequest()) }
    }
}
