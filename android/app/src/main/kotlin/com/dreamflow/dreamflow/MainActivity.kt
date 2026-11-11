package com.dreamflow.dreamflow

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.provider.MediaStore
import androidx.activity.result.contract.ActivityResultContract
import androidx.exifinterface.media.ExifInterface
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.time.Instant
import kotlin.concurrent.thread
import kotlinx.coroutines.runBlocking

/**
 * M9 · 相册选图（头像 / 壁纸）
 *
 * 为什么不用 image_picker 插件：这个需求用一个 `ACTION_PICK` 意图就能做完 ——
 * 选图、裁剪、压缩都在原生侧，Dart 只拿一个处理好的本地路径。
 *
 * 为什么**不需要**「相册权限」：`ACTION_PICK` 由系统相册接手，应用只拿到一个
 * 带临时读授权的 content URI，这里当场拷贝进应用私有目录后立刻放手。
 * 全程不触碰用户的媒体库，比申请 `READ_MEDIA_IMAGES` 更干净。
 *
 * 处理规则（不处理都会变成真机问题）：
 * - **头像**：中心正方裁剪 → 512×512 JPEG。不裁的话圆形头像会把竖图拉扁
 * - **壁纸**：长边压到 1600 以内 JPEG。原图直接拷的话一张 5000×8000 的
 *   照片就是 8MB，而壁纸每帧都画在画布底下
 * - **EXIF 旋转**：手机竖拍的照片像素其实是横着存的，不转会躺下
 */
class MainActivity : AudioServiceActivity() {

    private var pendingResult: MethodChannel.Result? = null
    private var pendingKind: String? = null

    /// M13：健康数据授权页（系统弹的，不是我们画的）
    ///
    /// 为什么不用 `registerForActivityResult`：`FlutterActivity` 继承的是
    /// `android.app.Activity`，不是 `ComponentActivity`，拿不到 ActivityResultLauncher。
    /// 这里直接用 contract 的 `createIntent` / `parseResult` 走老的
    /// `startActivityForResult` —— 同一个 contract，只是调用方式退一档。
    private val healthPermissionContract: ActivityResultContract<Set<String>, Set<String>> =
        PermissionController.createRequestPermissionResultContract()
    private var healthPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickImage" -> {
                        // 已有一次选图在进行：直接回 null，不让第二次点击把第一次的结果顶掉
                        if (pendingResult != null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val kind = call.argument<String>("kind") ?: KIND_WALLPAPER
                        val intent =
                            Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                        try {
                            pendingResult = result
                            pendingKind = kind
                            startActivityForResult(intent, REQ_PICK)
                        } catch (e: Exception) {
                            // 没有相册应用（极少见）：静默失败，Dart 侧收到 null 自行提示
                            pendingResult = null
                            pendingKind = null
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HEALTH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> healthStatus(result)
                    "requestPermission" -> requestHealthPermission(result)
                    "readSleep" -> {
                        val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
                        val endMs = call.argument<Number>("endMs")?.toLong() ?: 0L
                        readSleep(startMs, endMs, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── M13 健康数据（只读） ────────────────────────────────────────────────

    /**
     * 状态：available / needsUpdate / unavailable + 是否已授权。
     *
     * 只读**一项**权限：SLEEP。不申请心率、不申请写入 —— 报告要的就是睡眠，
     * 多要一项都是对用户的不必要索取。
     *
     * `getGrantedPermissions()` 是 suspend，且要查 Health Connect 的连接状态，
     * 所以整段丢到后台线程，算完再回主线程回包。
     */
    private fun healthStatus(result: MethodChannel.Result) {
        thread(start = true) {
            val payload: Map<String, Any> = try {
                val state = when (HealthConnectClient.getSdkStatus(applicationContext)) {
                    HealthConnectClient.SDK_AVAILABLE -> "available"
                    HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "needsUpdate"
                    else -> "unavailable"
                }
                var granted = false
                if (state == "available") {
                    val client = HealthConnectClient.getOrCreate(applicationContext)
                    granted = runBlocking {
                        client.permissionController.getGrantedPermissions()
                    }.contains(HEALTH_SLEEP_PERMISSION)
                }
                mapOf("state" to state, "granted" to granted)
            } catch (e: Exception) {
                mapOf("state" to "unavailable", "granted" to false)
            }
            runOnUiThread { result.success(payload) }
        }
    }

    private fun requestHealthPermission(result: MethodChannel.Result) {
        if (healthPermissionResult != null) {
            result.success(false) // 已经有一个授权页在等结果，别叠第二个
            return
        }
        healthPermissionResult = result
        try {
            val intent =
                healthPermissionContract.createIntent(this, setOf(HEALTH_SLEEP_PERMISSION))
            startActivityForResult(intent, REQ_HEALTH)
        } catch (e: Exception) {
            // 没装 Health Connect / 系统版本不支持：静默降级，报告继续用推算
            healthPermissionResult = null
            result.success(false)
        }
    }

    /**
     * 读睡眠记录。
     *
     * 跨线程：`readRecords` 会查 Health Connect 的数据库，放在主线程上
     * 首帧就会卡一下。这里丢到后台线程，读完再回主线程把结果交给 Dart。
     */
    private fun readSleep(startMs: Long, endMs: Long, result: MethodChannel.Result) {
        thread(start = true) {
            try {
                val client = HealthConnectClient.getOrCreate(applicationContext)
                val response = runBlocking {
                    client.readRecords(
                        ReadRecordsRequest(
                            recordType = SleepSessionRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(
                                Instant.ofEpochMilli(startMs),
                                Instant.ofEpochMilli(endMs)
                            ),
                            ascendingOrder = true
                        )
                    )
                }
                val out = ArrayList<Map<String, Any?>>()
                for (record in response.records) {
                    val stages = ArrayList<Map<String, Any?>>()
                    for (stage in record.stages) {
                        stages.add(
                            mapOf(
                                "start" to stage.startTime.toEpochMilli(),
                                "end" to stage.endTime.toEpochMilli(),
                                "stage" to stage.stage
                            )
                        )
                    }
                    out.add(
                        mapOf(
                            "start" to record.startTime.toEpochMilli(),
                            "end" to record.endTime.toEpochMilli(),
                            "stages" to stages
                        )
                    )
                }
                runOnUiThread { result.success(out) }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("health_read_failed", e.message ?: "read failed", null)
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        // M13：健康数据授权回来。用户点「拒绝」时 resultCode 是 RESULT_CANCELED，
        // parseResult 会给空集合 —— 这里不区分「拒绝」和「取消」，都回 false。
        if (requestCode == REQ_HEALTH) {
            val pending = healthPermissionResult
            healthPermissionResult = null
            val granted: Set<String> = try {
                healthPermissionContract.parseResult(resultCode, data)
            } catch (e: Exception) {
                emptySet()
            }
            pending?.success(granted.contains(HEALTH_SLEEP_PERMISSION))
            return
        }

        if (requestCode != REQ_PICK) return
        val result = pendingResult
        val kind = pendingKind
        pendingResult = null
        pendingKind = null
        if (result == null) return

        val uri = data?.data
        if (uri == null) {
            result.success(null) // 用户取消
            return
        }
        val path = try {
            saveCopy(uri, kind ?: KIND_WALLPAPER)
        } catch (e: Exception) {
            null
        }
        result.success(path)
    }

    /** 把选中的图裁剪 / 压缩后拷进应用私有目录，返回绝对路径；失败返回 null。 */
    private fun saveCopy(uri: Uri, kind: String): String? {
        val resolver = contentResolver

        // ① 只读尺寸，不读像素
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, bounds)
        } ?: return null
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        // ② 按目标尺寸算采样率，避免整张 8000 万像素的图解进内存
        val target = if (kind == KIND_AVATAR) AVATAR_SIZE else WALLPAPER_MAX
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= target) sample *= 2

        val src = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(
                it, null, BitmapFactory.Options().apply { inSampleSize = sample }
            )
        } ?: return null

        // ③ EXIF 旋转（要用新的流重新读一次，EXIF 不在解码出的像素里）
        val orientation = resolver.openInputStream(uri)?.use { stream ->
            try {
                ExifInterface(stream).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
                )
            } catch (e: Exception) {
                ExifInterface.ORIENTATION_NORMAL
            }
        } ?: ExifInterface.ORIENTATION_NORMAL
        val degrees = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        var bmp = src
        if (degrees != 0f) {
            val m = Matrix().apply { postRotate(degrees) }
            bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
        }

        // ④ 裁剪 / 缩放
        bmp = if (kind == KIND_AVATAR) {
            val side = minOf(bmp.width, bmp.height)
            val x = (bmp.width - side) / 2
            val y = (bmp.height - side) / 2
            Bitmap.createScaledBitmap(
                Bitmap.createBitmap(bmp, x, y, side, side), AVATAR_SIZE, AVATAR_SIZE, true
            )
        } else {
            val longest = maxOf(bmp.width, bmp.height)
            if (longest > WALLPAPER_MAX) {
                val scale = WALLPAPER_MAX.toFloat() / longest
                Bitmap.createScaledBitmap(
                    bmp, (bmp.width * scale).toInt(), (bmp.height * scale).toInt(), true
                )
            } else bmp
        }

        // ⑤ 落盘到应用私有目录。**这里不删旧文件** —— 删除是 Dart 侧落盘成功后的事，
        //    在这删了，万一 Dart 侧写 account.json 失败就没有回退了
        val dir = File(filesDir, "media").apply { mkdirs() }
        val out = File(dir, "${kind}_${System.currentTimeMillis()}.jpg")
        FileOutputStream(out).use { bmp.compress(Bitmap.CompressFormat.JPEG, 88, it) }
        return out.absolutePath
    }

    companion object {
        const val CHANNEL = "dreamflow/media"
        const val REQ_PICK = 4001
        const val KIND_AVATAR = "avatar"
        const val KIND_WALLPAPER = "wallpaper"
        const val AVATAR_SIZE = 512
        const val WALLPAPER_MAX = 1600

        const val HEALTH_CHANNEL = "dreamflow/health"
        const val REQ_HEALTH = 4002

        /** Health Connect 的睡眠只读权限（不申请写入，也不申请心率） */
        const val HEALTH_SLEEP_PERMISSION = "android.permission.health.READ_SLEEP"
    }
}
