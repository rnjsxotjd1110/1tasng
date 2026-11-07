package app.ember.ideas.ui.strings

import android.content.Context
import app.ember.ideas.BuildConfig
import app.ember.ideas.account.ServerConfig

/**
 * 약관·개인정보 처리방침. 본문은 assets/legal 폴더의 Markdown 하나만 두고 앱 화면과 웹 페이지(tools/gen_legal.py)가 함께 쓴다.
 * 사업자 정보는 gradle.properties(ember.biz.*)에서 채우고, 비어 있으면 [미입력]으로 보인다.
 */
object Legal {
    enum class Doc(val file: String) { PRIVACY("privacy"), TERMS("terms") }

    /** 빈칸 이름 → 값. 웹 페이지를 만드는 스크립트도 같은 이름을 쓴다. */
    fun values(korean: Boolean): Map<String, String> {
        val missing = if (korean) "[미입력]" else "[not set]"
        fun v(x: String) = x.ifBlank { missing }
        return mapOf(
            "BIZ_NAME" to v(BuildConfig.BIZ_NAME),
            "BIZ_CEO" to v(BuildConfig.BIZ_CEO),
            "BIZ_REG_NO" to v(BuildConfig.BIZ_REG_NO),
            "BIZ_SALES_NO" to v(BuildConfig.BIZ_SALES_NO),
            "BIZ_ADDRESS" to v(BuildConfig.BIZ_ADDRESS),
            "BIZ_PHONE" to v(BuildConfig.BIZ_PHONE),
            "BIZ_EMAIL" to v(BuildConfig.BIZ_EMAIL.ifBlank { ServerConfig.values.reportEmail }),
            "PRIVACY_OFFICER" to v(BuildConfig.BIZ_PRIVACY_OFFICER),
            "DB_REGION" to v(BuildConfig.BIZ_DB_REGION),
            "DELETE_URL" to v(BuildConfig.DELETE_URL),
            "EFFECTIVE_DATE" to v(BuildConfig.LEGAL_EFFECTIVE),
        )
    }

    fun fill(markdown: String, korean: Boolean): String =
        values(korean).entries.fold(markdown) { acc, (k, v) -> acc.replace("{{$k}}", v) }

    fun load(context: Context, doc: Doc, korean: Boolean): String {
        val name = "legal/${doc.file}_${if (korean) "ko" else "en"}.md"
        val raw = runCatching { context.assets.open(name).bufferedReader().use { it.readText() } }.getOrDefault("")
        return fill(raw, korean)
    }

    /** 정보 화면에 보여 줄 사업자 정보(전자상거래법 표시 의무). */
    fun businessLines(korean: Boolean): List<Pair<String, String>> {
        val v = values(korean)
        return if (korean) listOf(
            "상호" to v.getValue("BIZ_NAME"), "대표자" to v.getValue("BIZ_CEO"), "사업자등록번호" to v.getValue("BIZ_REG_NO"),
            "통신판매업 신고" to v.getValue("BIZ_SALES_NO"), "주소" to v.getValue("BIZ_ADDRESS"), "전화" to v.getValue("BIZ_PHONE"),
            "이메일" to v.getValue("BIZ_EMAIL"), "개인정보 보호책임자" to v.getValue("PRIVACY_OFFICER"),
        ) else listOf(
            "Company" to v.getValue("BIZ_NAME"), "CEO" to v.getValue("BIZ_CEO"), "Business reg. no." to v.getValue("BIZ_REG_NO"),
            "Mail-order business no." to v.getValue("BIZ_SALES_NO"), "Address" to v.getValue("BIZ_ADDRESS"), "Phone" to v.getValue("BIZ_PHONE"),
            "Email" to v.getValue("BIZ_EMAIL"), "Privacy officer" to v.getValue("PRIVACY_OFFICER"),
        )
    }
}
