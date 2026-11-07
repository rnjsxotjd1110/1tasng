package app.ember.ideas.account

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.consumePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import app.ember.ideas.ai.AiError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** 화면에 보여 줄 크레딧 상품. 가격은 Play 가 사용자 국가 통화로 알려 준다. */
data class CreditPack(val productId: String, val credits: Int, val price: String?)

/** 결제 진행 상태. 화면은 이것만 보고 안내 문구를 고른다. */
sealed interface PurchaseState {
    data object Idle : PurchaseState
    data object Unavailable : PurchaseState
    data object Working : PurchaseState
    data object Pending : PurchaseState
    data class Done(val credits: Int) : PurchaseState
    data class Failed(val error: AiError?) : PurchaseState
}

/**
 * Google Play 결제. 구매 → 서버가 영수증을 확인하고 크레딧 지급 → 소비(다시 살 수 있게) 순서로 처리한다.
 * 서버 확인 전에 앱이 꺼져도 다음 실행 때 [restore] 가 남은 구매를 마저 처리한다.
 */
class BillingManager(context: Context, private val account: CreditAccount, private val scope: CoroutineScope) {

    private val _packs = MutableStateFlow(ServerConfig.products.map { (id, c) -> CreditPack(id, c, null) })
    val packs: StateFlow<List<CreditPack>> = _packs.asStateFlow()

    private val _state = MutableStateFlow<PurchaseState>(PurchaseState.Idle)
    val state: StateFlow<PurchaseState> = _state.asStateFlow()

    private val details = mutableMapOf<String, ProductDetails>()

    private val listener = PurchasesUpdatedListener { result, purchases ->
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> purchases.orEmpty().forEach { handle(it) }
            BillingClient.BillingResponseCode.USER_CANCELED -> _state.value = PurchaseState.Idle
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> restore()
            else -> _state.value = PurchaseState.Failed(null)
        }
    }

    private val client: BillingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener(listener)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    @Volatile private var connected = false

    /** Play 에 연결하고 상품 가격을 읽은 뒤, 처리하지 못한 구매가 있으면 마저 처리한다. */
    fun start() {
        if (!ServerConfig.creditsEnabled) return
        if (connected) { restore(); return }
        // Play 스토어가 없는 기기(에뮬레이터·테스트)에서는 연결 자체가 실패할 수 있다.
        runCatching { connect() }.onFailure { _state.value = PurchaseState.Unavailable }
    }

    private fun connect() {
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    _state.value = PurchaseState.Unavailable
                    return
                }
                connected = true
                scope.launch { loadProducts() }
                restore()
            }

            override fun onBillingServiceDisconnected() { connected = false }
        })
    }

    private suspend fun loadProducts() {
        val params = QueryProductDetailsParams.newBuilder().setProductList(
            ServerConfig.products.map { (id, _) ->
                QueryProductDetailsParams.Product.newBuilder().setProductId(id).setProductType(BillingClient.ProductType.INAPP).build()
            },
        ).build()
        val result = client.queryProductDetails(params)
        val list = result.productDetailsList.orEmpty()
        list.forEach { details[it.productId] = it }
        _packs.value = ServerConfig.products.map { (id, credits) ->
            CreditPack(id, credits, details[id]?.oneTimePurchaseOfferDetails?.formattedPrice)
        }
        if (list.isEmpty()) _state.value = PurchaseState.Unavailable
    }

    fun buy(activity: Activity, productId: String) {
        val pd = details[productId]
        if (!connected || pd == null) {
            _state.value = PurchaseState.Unavailable
            start()
            return
        }
        _state.value = PurchaseState.Working
        val flow = BillingFlowParams.newBuilder().setProductDetailsParamsList(
            listOf(BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(pd).build()),
        ).build()
        val r = client.launchBillingFlow(activity, flow)
        if (r.responseCode != BillingClient.BillingResponseCode.OK) _state.value = PurchaseState.Failed(null)
    }

    /** 결제했지만 크레딧을 받지 못한 구매를 다시 처리한다. */
    fun restore() {
        if (!connected) return
        scope.launch {
            val r = client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build())
            r.purchasesList.forEach { handle(it) }
        }
    }

    fun clearState() { _state.value = PurchaseState.Idle }

    private fun handle(purchase: Purchase) {
        when (purchase.purchaseState) {
            Purchase.PurchaseState.PENDING -> _state.value = PurchaseState.Pending
            Purchase.PurchaseState.PURCHASED -> scope.launch {
                _state.value = PurchaseState.Working
                try {
                    var credits = 0
                    purchase.products.forEach { id -> credits = account.redeem(id, purchase.purchaseToken) }
                    // 서버가 Google 에 직접 소비 처리를 한 뒤 크레딧을 준다. 여기서의 소비는 예전 서버를 위한 보조라서
                    // 실패해도(이미 소비됨 등) 다시 시도하지 않는다. 실패할 때마다 복원을 부르면 무한히 되풀이된다.
                    runCatching { client.consumePurchase(ConsumeParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()) }
                    _state.value = PurchaseState.Done(credits)
                } catch (e: AiError) {
                    _state.value = PurchaseState.Failed(e)
                }
            }
            else -> Unit
        }
    }
}
