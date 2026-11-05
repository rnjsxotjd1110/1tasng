package app.ember.ideas.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * 참고 이미지를 앱 저장소로 복사한다. Claude 가 읽기 좋은 크기(긴 변 1568px)로 줄이고 JPEG 로 저장해
 * 요청 크기와 비용을 줄인다. 원본 사진의 위치 정보(EXIF)는 옮기지 않는다.
 */
class ImageStore(context: Context) {
    private val app = context.applicationContext
    private val dir = File(app.filesDir, "images").apply { mkdirs() }

    suspend fun import(uri: Uri): String? = withContext(Dispatchers.IO) {
        runCatching {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            app.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@runCatching null
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_SIDE) sample *= 2
            val decoded = app.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
            } ?: return@runCatching null
            val rotation = app.contentResolver.openInputStream(uri)?.use { s ->
                when (ExifInterface(s).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                    else -> 0f
                }
            } ?: 0f
            val scale = minOf(1f, MAX_SIDE.toFloat() / maxOf(decoded.width, decoded.height))
            val m = Matrix().apply { postScale(scale, scale); postRotate(rotation) }
            val bmp = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, m, true)
            val f = File(dir, "img_${System.currentTimeMillis()}_${(1000..9999).random()}.jpg")
            f.outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 85, it) }
            f.absolutePath
        }.getOrNull()
    }

    fun delete(path: String) { File(path).takeIf { it.parentFile == dir }?.delete() }

    /** 어느 프로젝트도 쓰지 않는 이미지를 지운다(하루 넘은 것만: 홈 화면에 첨부만 해 둔 것은 남긴다). */
    fun cleanup(inUse: Set<String>, all: Boolean = false) {
        val dayAgo = System.currentTimeMillis() - 86_400_000L
        dir.listFiles()?.forEach { f -> if (f.absolutePath !in inUse && (all || f.lastModified() < dayAgo)) f.delete() }
    }

    companion object {
        const val MAX_SIDE = 1568
        const val MAX_IMAGES = 3
    }
}
