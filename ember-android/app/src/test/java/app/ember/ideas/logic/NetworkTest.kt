package app.ember.ideas.logic

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import app.ember.ideas.MockHttp
import app.ember.ideas.MockHttp.Res
import app.ember.ideas.account.CreditAccount
import app.ember.ideas.account.ServerConfig
import app.ember.ideas.ai.AiError
import app.ember.ideas.data.SettingsStore
import app.ember.ideas.data.Usage
import app.ember.ideas.handoff.GitHubClient
import app.ember.ideas.handoff.GitHubError
import app.ember.ideas.handoff.RepoFile
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** 크레딧 서버와 GitHub 요청을 가짜 서버에 보내 요청 모양과 오류 처리를 확인한다. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class NetworkTest {
    private lateinit var mock: MockHttp
    private lateinit var settings: SettingsStore

    @Before fun setUp() {
        mock = MockHttp()
        ServerConfig.override = ServerConfig.Values(serverUrl = mock.url, reportEmail = "", privacyUrl = "", creditMarkup = 1.5, freeCredits = 100)
        settings = SettingsStore(ApplicationProvider.getApplicationContext<Application>())
        settings.clearAll()
    }

    @After fun tearDown() {
        mock.close()
        ServerConfig.override = null
    }

    @Test fun creditsRegisterRefreshRedeem() = runBlocking {
        mock.on("POST /ember/register", Res(200, """{"token":"tok_1","credits":100,"freeGranted":true}"""))
            .on("GET /ember/balance", Res(200, """{"credits":64}"""))
            .on("POST /ember/purchase", Res(200, """{"credits":564,"granted":500}"""))
        val acc = CreditAccount(settings)
        assertEquals(100, acc.connect(app.ember.ideas.account.GoogleAccount("id-token-1", "me@example.com")))
        val st = settings.settings.value
        assertTrue(st.creditsReady && st.usingCredits && st.ready)
        assertEquals("me@example.com", st.googleEmail)
        val reg = mock.last("/ember/register").body
        assertTrue(reg.contains(settings.installId()) && reg.contains("id-token-1"))
        // 이메일은 서버로 보내지 않는다(ID 토큰 안에만 있다).
        assertTrue(!reg.contains("me@example.com"))

        // 크레딧으로 쓴 요청은 서버 확인 전에 잔액을 미리 줄인다($0.10 × 1.5 = 15).
        settings.addUsage(Usage(costUsd = 0.10, requests = 1))
        assertEquals(85, settings.settings.value.credits)
        assertEquals(64, acc.refresh())
        assertEquals("tok_1", mock.last("/ember/balance").headers["x-api-key"])

        assertEquals(564, acc.redeem("ember_credits_500", "purchase-token"))
        val body = mock.last("/ember/purchase").body
        assertTrue(body.contains("ember_credits_500") && body.contains("purchase-token"))
    }

    @Test fun expiredTokenSignsOut() = runBlocking {
        // 토큰이 무효면 몰래 새 계정을 만들지 않고 연결을 푼다(다시 Google 로그인).
        settings.setCreditAccount("old", 10)
        mock.on("GET /ember/balance", Res(401, """{"type":"error","error":{"type":"authentication_error","message":"bad"}}"""))
        assertEquals(0, CreditAccount(settings).refresh())
        assertEquals(null, settings.creditToken())
        assertTrue(mock.requests.none { it.path.startsWith("/ember/register") })
    }

    @Test fun deleteAccountClearsLocalState() = runBlocking {
        settings.setCreditAccount("tok", 30)
        settings.setGoogleEmail("me@example.com")
        mock.on("DELETE /ember/account", Res(200, """{"deleted":true}"""))
        CreditAccount(settings).deleteAccount()
        assertEquals("tok", mock.last("/ember/account").headers["x-api-key"])
        assertEquals(null, settings.creditToken())
        assertEquals("", settings.settings.value.googleEmail)
    }

    @Test fun outOfCreditsMapsTo402() = runBlocking {
        settings.setCreditAccount("tok", 0)
        mock.on("POST /ember/report", Res(402, """{"type":"error","error":{"type":"insufficient_credits","message":"no"}}"""))
        try {
            CreditAccount(settings).report("idea", "기타", "내용", "", "1.2.0")
            fail()
        } catch (e: AiError) {
            assertEquals(AiError.OutOfCredits, e)
        }
    }

    @Test fun reportingNeverCreatesAccount() = runBlocking {
        // 내 키로 쓰는 사람이 신고해도 크레딧 계정을 몰래 만들지 않는다(로그인하지 않았으면 메일로 보낸다).
        settings.setApiKey("sk-ant-test-0000000000000000000000000000000000")
        try {
            CreditAccount(settings).report("idea", "기타", "내용", "", "1.2.0")
            fail()
        } catch (e: AiError) {
            assertEquals(AiError.NoKey, e)
        }
        assertTrue(mock.requests.none { it.path.startsWith("/ember/register") })
        assertFalse(settings.settings.value.creditsReady)
    }

    @Test fun preferKeyWhenNotChosen() {
        settings.setApiKey("sk-ant-test-0000000000000000000000000000000000")
        settings.setCreditAccount("tok", 50)
        settings.setPreferCredits(false)
        assertFalse(settings.settings.value.usingCredits)
        settings.setPreferCredits(true)
        assertTrue(settings.settings.value.usingCredits)
        ServerConfig.override = ServerConfig.Values(serverUrl = "")
        assertFalse(settings.settings.value.usingCredits)
    }

    @Test fun githubCreateRepoUploadsFiles() = runBlocking {
        mock.on("GET /user", Res(200, """{"login":"octo"}"""))
            .on("POST /user/repos", Res(201, """{"full_name":"octo/lamp","html_url":"https://github.com/octo/lamp"}"""))
            .on("PUT /repos/octo/lamp/contents/", Res(201, """{"content":{}}"""))
            .on("POST /repos/octo/lamp/issues", Res(201, """{"html_url":"https://github.com/octo/lamp/issues/1"}"""))
        val gh = GitHubClient(baseUrl = mock.url)
        assertEquals("octo", gh.verify("ghp_x"))
        val url = gh.createRepo("ghp_x", "lamp", "설명", true, listOf(RepoFile("README.md", "# 등불"), RepoFile("docs/DESIGN.md", "## 1")))
        assertEquals("https://github.com/octo/lamp", url)
        val puts = mock.requests.filter { it.method == "PUT" }
        assertEquals(listOf("/repos/octo/lamp/contents/README.md", "/repos/octo/lamp/contents/docs/DESIGN.md"), puts.map { it.path })
        val encoded = java.util.Base64.getEncoder().encodeToString("# 등불".toByteArray())
        assertTrue(puts.first().body.contains(encoded))
        assertEquals("Bearer ghp_x", mock.last("/user/repos").headers["authorization"])
        assertTrue(mock.last("/user/repos").body.contains("\"private\":true"))
        assertEquals("https://github.com/octo/lamp/issues/1", gh.createIssue("ghp_x", "octo/lamp", "제목", "본문"))
    }

    @Test fun githubErrors() = runBlocking {
        mock.on("GET /user", Res(401, """{"message":"Bad credentials"}"""))
            .on("POST /user/repos", Res(422, """{"message":"Repository creation failed.","errors":[{"message":"name already exists on this account"}]}"""))
        val gh = GitHubClient(baseUrl = mock.url)
        try { gh.verify("x"); fail() } catch (e: GitHubError) { assertEquals(GitHubError.BadToken, e) }
        try { gh.createRepo("x", "lamp", "", true, emptyList()); fail() } catch (e: GitHubError) { assertEquals(GitHubError.NameTaken, e) }
    }
}
