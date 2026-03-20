package com.biliaudioclipper.bilibili_audio_clipper

import android.content.ContentValues
import android.media.MediaExtractor
import android.media.MediaMuxer
import android.media.MediaFormat
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val TRIM_CHANNEL = "com.biliaudioclipper/audio_trimmer"
    private val SAVER_CHANNEL = "com.biliaudioclipper/file_saver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRIM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "trimAudio" -> {
                    val inputPath = call.argument<String>("inputPath")!!
                    val outputPath = call.argument<String>("outputPath")!!
                    val startUs = call.argument<Long>("startUs")!!
                    val endUs = call.argument<Long>("endUs")!!
                    try {
                        trimAudio(inputPath, outputPath, startUs, endUs)
                        result.success(outputPath)
                    } catch (e: Exception) {
                        result.error("TRIM_ERROR", "裁剪失败: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAVER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val srcPath = call.argument<String>("srcPath")!!
                    val fileName = call.argument<String>("fileName")!!
                    val mimeType = call.argument<String>("mimeType") ?: "audio/mp4"
                    try {
                        saveToDownloads(srcPath, fileName, mimeType)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", "保存失败: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(srcPath: String, fileName: String, mimeType: String) {
        val srcFile = File(srcPath)
        if (!srcFile.exists()) throw Exception("源文件不存在")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ 使用 MediaStore
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("无法创建文件")
            contentResolver.openOutputStream(uri)?.use { output ->
                srcFile.inputStream().use { input -> input.copyTo(output) }
            } ?: throw Exception("无法写入文件")
        } else {
            // Android 9 及以下直接复制到 Downloads 目录
            val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadDir.exists()) downloadDir.mkdirs()
            srcFile.copyTo(File(downloadDir, fileName), overwrite = true)
        }
    }

    private fun trimAudio(inputPath: String, outputPath: String, startUs: Long, endUs: Long) {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        // Find audio track
        var audioTrackIndex = -1
        var audioFormat: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                audioFormat = format
                break
            }
        }
        if (audioTrackIndex == -1 || audioFormat == null) {
            throw Exception("未找到音频轨道")
        }

        extractor.selectTrack(audioTrackIndex)

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val outputTrackIndex = muxer.addTrack(audioFormat)
        muxer.start()

        val buffer = ByteBuffer.allocate(1024 * 1024) // 1MB buffer
        val bufferInfo = android.media.MediaCodec.BufferInfo()

        // Seek to start position
        extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

        while (true) {
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break

            val sampleTime = extractor.sampleTime
            if (sampleTime > endUs) break

            if (sampleTime >= startUs) {
                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = sampleTime - startUs
                bufferInfo.flags = extractor.sampleFlags
                muxer.writeSampleData(outputTrackIndex, buffer, bufferInfo)
            }

            extractor.advance()
        }

        muxer.stop()
        muxer.release()
        extractor.release()
    }
}
