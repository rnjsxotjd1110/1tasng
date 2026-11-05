package app.ember.ideas

import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import java.util.concurrent.ConcurrentLinkedQueue

/** 테스트용 작은 HTTP 서버. 보낸 요청을 기록하고, 경로별로 준비한 응답을 순서대로 돌려준다. */
class MockHttp : AutoCloseable {
    data class Req(val method: String, val path: String, val headers: Map<String, String>, val body: String)
    data class Res(val status: Int, val body: String, val contentType: String = "application/json")

    val requests = ConcurrentLinkedQueue<Req>()
    private val routes = LinkedHashMap<String, ArrayDeque<Res>>()
    private val server = MockWebServer()

    init {
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                val path = request.path.orEmpty()
                val method = request.method.orEmpty()
                requests += Req(method, path, request.headers.associate { it.first.lowercase() to it.second }, request.body.readUtf8())
                val res = synchronized(routes) {
                    val key = routes.keys.firstOrNull { path.startsWith(it.substringAfter(' ')) && method == it.substringBefore(' ') }
                    val q = key?.let { routes[it] }
                    (if (q != null && q.size > 1) q.removeFirst() else q?.firstOrNull())
                } ?: Res(404, """{"type":"error","error":{"type":"not_found_error","message":"no route"}}""")
                return MockResponse().setResponseCode(res.status).setHeader("Content-Type", res.contentType).setHeader("request-id", "req_test").setBody(res.body)
            }
        }
        server.start()
    }

    val url: String get() = server.url("/").toString().trimEnd('/')

    /** "POST /v1/messages" 처럼 메서드와 경로 앞부분으로 응답을 등록한다. 마지막 응답은 계속 재사용된다. */
    fun on(route: String, vararg res: Res): MockHttp { synchronized(routes) { routes[route] = ArrayDeque(res.toList()) }; return this }

    fun last(pathPrefix: String): Req = requests.last { it.path.startsWith(pathPrefix) }

    override fun close() = server.shutdown()
}
