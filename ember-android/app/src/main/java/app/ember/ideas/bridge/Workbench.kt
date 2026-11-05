package app.ember.ideas.bridge

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import app.ember.ideas.ai.Protocol
import app.ember.ideas.data.SettingsStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.InetSocketAddress
import java.net.Socket

/** PC 브리지와 주고받는 형식. ember-bridge 의 server.go 와 같다. */
object BridgeApi {
    const val SERVICE_TYPE = "_ember._tcp."
    const val DEFAULT_PORT = 47615

    @Serializable data class Info(val id: String = "", val name: String = "", val version: String = "", val os: String = "", val pairingRequired: Boolean = true)
    @Serializable data class PairRequest(val code: String, val deviceName: String)
    @Serializable data class PairResponse(val token: String = "", val name: String = "", val id: String = "")
    @Serializable data class FileEntry(val path: String, val content: String)
    @Serializable data class SendRequest(val title: String, val mode: String, val prompt: String, val files: List<FileEntry>, val folder: String = "")
    @Serializable data class SendResponse(
        val ok: Boolean = false,
        val mode: String = "",
        val folder: String = "",
        val saved: List<String> = emptyList(),
        val message: String = "",
        val claudeFound: Boolean = false,
    )
    @Serializable data class ErrorBody(val error: String = "", val message: String = "")

    const val MODE_CODE = "code"
    const val MODE_CLIPBOARD = "clipboard"
    const val MODE_FILE = "file"
}

/** 브리지 요청이 실패한 이유. [message] 는 브리지가 보낸 설명(한국어)이거나 비어 있다. */
sealed class BridgeError(val detail: String) : Exception(detail) {
    /** PC 에 닿지 못함(꺼짐, 다른 Wi‑Fi, 방화벽). */
    class Unreachable(detail: String) : BridgeError(detail)
    /** 연결 정보가 없거나 PC 에서 연결을 끊음. 다시 페어링해야 한다. */
    class Unauthorized(detail: String) : BridgeError(detail)
    /** 페어링 코드가 틀리거나 만료됨. */
    class BadCode(detail: String) : BridgeError(detail)
    /** 너무 자주 시도함. */
    class RateLimited(detail: String) : BridgeError(detail)
    /** 그 밖의 거절(형식 오류 등). */
    class Rejected(detail: String) : BridgeError(detail)
}

/**
 * 아주 작은 HTTP/1.1 클라이언트. 같은 Wi‑Fi 의 PC 하고만 이야기하므로 TLS 없이 소켓으로 직접 보낸다.
 * (앱 전체의 평문 HTTP 허용을 켜지 않으려고 HttpURLConnection 을 쓰지 않는다.)
 */
internal object MiniHttp {
    data class Response(val status: Int, val body: String)

    private const val CONNECT_TIMEOUT_MS = 2500
    private const val READ_TIMEOUT_MS = 20000
    private const val MAX_BODY = 1 shl 20

    fun request(host: String, port: Int, method: String, path: String, body: String? = null, token: String? = null, readTimeoutMs: Int = READ_TIMEOUT_MS): Response {
        val bytes = body?.toByteArray(Charsets.UTF_8)
        Socket().use { sock ->
            try {
                sock.connect(InetSocketAddress(host, port), CONNECT_TIMEOUT_MS)
            } catch (e: Exception) {
                throw BridgeError.Unreachable(e.message ?: "connect")
            }
            sock.soTimeout = readTimeoutMs
            val head = buildString {
                append("$method $path HTTP/1.1\r\n")
                append("Host: ${if (host.contains(':')) "[$host]" else host}:$port\r\n")
                append("User-Agent: Ember-Android\r\n")
                append("Accept: application/json\r\n")
                append("Connection: close\r\n")
                if (token != null) append("Authorization: Bearer $token\r\n")
                if (bytes != null) {
                    append("Content-Type: application/json; charset=utf-8\r\n")
                    append("Content-Length: ${bytes.size}\r\n")
                }
                append("\r\n")
            }
            val out = sock.getOutputStream()
            out.write(head.toByteArray(Charsets.ISO_8859_1))
            if (bytes != null) out.write(bytes)
            out.flush()
            return try { parse(BufferedInputStream(sock.getInputStream())) } catch (e: BridgeError) { throw e } catch (e: Exception) {
                throw BridgeError.Unreachable(e.message ?: "read")
            }
        }
    }

    internal fun parse(input: InputStream): Response {
        val status = readLine(input).split(' ').getOrNull(1)?.toIntOrNull() ?: throw BridgeError.Rejected("bad status line")
        var length = -1
        var chunked = false
        while (true) {
            val line = readLine(input)
            if (line.isEmpty()) break
            val name = line.substringBefore(':').trim().lowercase()
            val value = line.substringAfter(':', "").trim()
            if (name == "content-length") length = value.toIntOrNull() ?: -1
            if (name == "transfer-encoding" && value.lowercase().contains("chunked")) chunked = true
        }
        val buf = ByteArrayOutputStream()
        when {
            chunked -> while (true) {
                val size = readLine(input).substringBefore(';').trim().toInt(16)
                if (size == 0) break
                copy(input, buf, size)
                readLine(input)
            }
            length >= 0 -> copy(input, buf, length)
            else -> {
                val tmp = ByteArray(4096)
                while (true) {
                    val n = input.read(tmp)
                    if (n < 0) break
                    buf.write(tmp, 0, n)
                    if (buf.size() > MAX_BODY) break
                }
            }
        }
        return Response(status, buf.toString(Charsets.UTF_8.name()))
    }

    private fun copy(input: InputStream, out: ByteArrayOutputStream, n: Int) {
        require(n <= MAX_BODY) { "body too large" }
        val tmp = ByteArray(4096)
        var left = n
        while (left > 0) {
            val r = input.read(tmp, 0, minOf(tmp.size, left))
            if (r < 0) break
            out.write(tmp, 0, r)
            left -= r
        }
    }

    private fun readLine(input: InputStream): String {
        val sb = StringBuilder()
        while (true) {
            val b = input.read()
            if (b < 0 || b == '\n'.code) break
            if (b != '\r'.code) sb.append(b.toChar())
            if (sb.length > 8192) break
        }
        return sb.toString()
    }
}

/**
 * 작업대: 같은 Wi‑Fi 에 있는 PC 의 Ember 브리지를 찾고, 페어링하고, 프롬프트를 보낸다.
 * 연결 정보(토큰)는 암호화 저장소에 둔다.
 */
class Workbench(private val context: Context, private val settings: SettingsStore, private val scope: CoroutineScope) {

    data class Found(val name: String, val host: String, val port: Int)

    enum class Status { NONE, CHECKING, ONLINE, OFFLINE, UNPAIRED }

    private val _found = MutableStateFlow<List<Found>>(emptyList())
    /** 지금 찾은 PC 목록. [startDiscovery] 동안 채워진다. */
    val found: StateFlow<List<Found>> = _found.asStateFlow()

    private val _searching = MutableStateFlow(false)
    val searching: StateFlow<Boolean> = _searching.asStateFlow()

    private val _status = MutableStateFlow(Status.NONE)
    val status: StateFlow<Status> = _status.asStateFlow()

    private val nsd: NsdManager? get() = context.getSystemService(NsdManager::class.java)
    private var listener: NsdManager.DiscoveryListener? = null
    /** NsdManager 는 한 번에 하나만 풀 수 있어서 차례로 푼다. */
    private val resolveQueue = ArrayDeque<NsdServiceInfo>()
    private var resolving = false

    val paired: Boolean get() = settings.settings.value.workbenchName.isNotEmpty()

    // ------------------------------------------------------------ 찾기

    fun startDiscovery() {
        if (listener != null) return
        val mgr = nsd ?: return
        _found.value = emptyList()
        val l = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) { _searching.value = true }
            override fun onDiscoveryStopped(serviceType: String) { _searching.value = false }
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) { _searching.value = false; listener = null }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) { _searching.value = false }
            override fun onServiceFound(info: NsdServiceInfo) {
                synchronized(resolveQueue) { resolveQueue.addLast(info) }
                resolveNext()
            }
            override fun onServiceLost(info: NsdServiceInfo) {
                _found.update { list -> list.filter { it.name != info.serviceName } }
            }
        }
        listener = l
        runCatching { mgr.discoverServices(BridgeApi.SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, l) }.onFailure { listener = null }
    }

    fun stopDiscovery() {
        val l = listener ?: return
        listener = null
        runCatching { nsd?.stopServiceDiscovery(l) }
        _searching.value = false
    }

    @Suppress("DEPRECATION")
    private fun resolveNext() {
        val mgr = nsd ?: return
        val next = synchronized(resolveQueue) {
            if (resolving) return
            resolveQueue.removeFirstOrNull()?.also { resolving = true }
        } ?: return
        runCatching {
            mgr.resolveService(next, object : NsdManager.ResolveListener {
                override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) { done() }
                override fun onServiceResolved(info: NsdServiceInfo) {
                    val host = info.host?.hostAddress
                    if (host != null) {
                        val f = Found(info.serviceName, host.substringBefore('%'), info.port)
                        _found.update { list -> (list.filter { it.name != f.name } + f).sortedBy { it.name } }
                        // 연결해 둔 PC 의 주소가 바뀌었으면 고쳐 둔다.
                        val st = settings.settings.value
                        if (st.workbenchName.isNotEmpty() && st.workbenchName == f.name && (st.workbenchHost != f.host || st.workbenchPort != f.port)) {
                            settings.updateWorkbenchAddress(f.host, f.port)
                        }
                    }
                    done()
                }
                private fun done() {
                    synchronized(resolveQueue) { resolving = false }
                    resolveNext()
                }
            })
        }.onFailure {
            synchronized(resolveQueue) { resolving = false }
        }
    }

    // ------------------------------------------------------------ 페어링

    suspend fun info(host: String, port: Int): BridgeApi.Info = io {
        val r = MiniHttp.request(host, port, "GET", "/ember/info", readTimeoutMs = 4000)
        if (r.status != 200) throw errorOf(r)
        Protocol.json.decodeFromString(BridgeApi.Info.serializer(), r.body)
    }

    /** 6자리 코드로 연결한다. 성공하면 토큰을 저장한다. */
    suspend fun pair(host: String, port: Int, code: String): BridgeApi.PairResponse = io {
        val body = Protocol.json.encodeToString(BridgeApi.PairRequest.serializer(), BridgeApi.PairRequest(code.filter { it.isDigit() }, deviceName()))
        val r = MiniHttp.request(host, port, "POST", "/ember/pair", body)
        if (r.status != 200) throw errorOf(r)
        val res = Protocol.json.decodeFromString(BridgeApi.PairResponse.serializer(), r.body)
        if (res.token.isBlank()) throw BridgeError.Rejected("")
        settings.setWorkbench(res.token, host, port, res.name.ifBlank { host }, res.id)
        _status.value = Status.ONLINE
        res
    }

    /** 연결을 끊는다. PC 에 닿지 않아도 이 기기의 연결 정보는 지운다. */
    fun unpair() {
        val st = settings.settings.value
        val token = settings.workbenchToken()
        settings.setWorkbench(null)
        _status.value = Status.NONE
        if (token != null && st.workbenchHost.isNotEmpty()) {
            scope.launch(Dispatchers.IO) { runCatching { MiniHttp.request(st.workbenchHost, st.workbenchPort, "POST", "/ember/unpair", "{}", token, 4000) } }
        }
    }

    /** 연결한 PC 가 지금 켜져 있는지 확인한다. */
    fun refreshStatus() {
        val st = settings.settings.value
        val token = settings.workbenchToken()
        if (st.workbenchName.isEmpty() || token == null) { _status.value = Status.NONE; return }
        _status.value = Status.CHECKING
        scope.launch {
            _status.value = runCatching {
                io { MiniHttp.request(st.workbenchHost, st.workbenchPort, "GET", "/ember/ping", token = token, readTimeoutMs = 4000) }
            }.fold(
                onSuccess = { r -> when (r.status) { 200 -> Status.ONLINE; 401 -> Status.UNPAIRED; else -> Status.OFFLINE } },
                onFailure = { Status.OFFLINE },
            )
        }
    }

    // ------------------------------------------------------------ 보내기

    suspend fun send(req: BridgeApi.SendRequest): BridgeApi.SendResponse {
        val st = settings.settings.value
        val token = settings.workbenchToken() ?: throw BridgeError.Unauthorized("")
        return io {
            val body = Protocol.json.encodeToString(BridgeApi.SendRequest.serializer(), req)
            val r = MiniHttp.request(st.workbenchHost, st.workbenchPort, "POST", "/ember/send", body, token)
            if (r.status == 401) _status.value = Status.UNPAIRED
            if (r.status != 200) throw errorOf(r)
            _status.value = Status.ONLINE
            Protocol.json.decodeFromString(BridgeApi.SendResponse.serializer(), r.body)
        }
    }

    private fun errorOf(r: MiniHttp.Response): BridgeError {
        val e = runCatching { Protocol.json.decodeFromString(BridgeApi.ErrorBody.serializer(), r.body) }.getOrNull()
        val msg = e?.message.orEmpty()
        return when {
            r.status == 401 -> BridgeError.Unauthorized(msg)
            r.status == 403 || e?.error == "bad_code" -> BridgeError.BadCode(msg)
            r.status == 429 -> BridgeError.RateLimited(msg)
            else -> BridgeError.Rejected(msg)
        }
    }

    private suspend fun <T> io(block: () -> T): T = withContext(Dispatchers.IO) { block() }

    private fun deviceName(): String = listOf(Build.MANUFACTURER, Build.MODEL).filter { !it.isNullOrBlank() }.joinToString(" ").ifBlank { "Android" }

    companion object {
        /** "192.168.0.12" 또는 "192.168.0.12:47615" 를 주소와 포트로 나눈다. 틀리면 null. */
        fun parseAddress(text: String): Pair<String, Int>? {
            val t = text.trim().removePrefix("http://").removeSuffix("/")
            if (t.isEmpty()) return null
            val host = t.substringBeforeLast(':', t).trim()
            val port = if (t.contains(':')) t.substringAfterLast(':').toIntOrNull() ?: return null else BridgeApi.DEFAULT_PORT
            if (port !in 1..65535) return null
            if (!Regex("^[A-Za-z0-9.\\-]+$").matches(host)) return null
            return host to port
        }
    }
}
