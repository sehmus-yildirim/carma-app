package com.example.carma

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.media.MediaRecorder
import android.net.Uri
import android.provider.ContactsContract
import android.provider.OpenableColumns
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "carma/chat_tools"
    private val pickPhoneContactRequestCode = 4701
    private val pickDocumentRequestCode = 4702
    private val recordAudioPermissionRequestCode = 4703
    private var pendingContactResult: MethodChannel.Result? = null
    private var pendingDocumentResult: MethodChannel.Result? = null
    private var pendingVoiceMemoStartResult: MethodChannel.Result? = null
    private var voiceMemoRecorder: MediaRecorder? = null
    private var voiceMemoFile: File? = null
    private var voiceMemoStartedAt: Long = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickPhoneContact" -> pickPhoneContact(result)
                    "openMap" -> openMap(call.argument<Double>("latitude"), call.argument<Double>("longitude"), result)
                    "pickDocumentFile" -> pickDocumentFile(result)
                    "openDocumentUrl" -> openDocumentUrl(call.argument<String>("url"), call.argument<String>("contentType"), result)
                    "startVoiceMemo" -> startVoiceMemo(result)
                    "stopVoiceMemo" -> stopVoiceMemo(result)
                    "cancelVoiceMemo" -> cancelVoiceMemo(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickPhoneContact(result: MethodChannel.Result) {
        if (pendingContactResult != null) {
            result.error("contact_picker_busy", "Contact picker is already open.", null)
            return
        }

        pendingContactResult = result

        val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)

        try {
            startActivityForResult(intent, pickPhoneContactRequestCode)
        } catch (error: Exception) {
            pendingContactResult = null
            result.error("contact_picker_unavailable", "No contact picker is available.", error.message)
        }
    }

    private fun pickDocumentFile(result: MethodChannel.Result) {
        if (pendingDocumentResult != null) {
            result.error("document_picker_busy", "Document picker is already open.", null)
            return
        }

        pendingDocumentResult = result

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }

        try {
            startActivityForResult(intent, pickDocumentRequestCode)
        } catch (error: Exception) {
            pendingDocumentResult = null
            result.error("document_picker_unavailable", "No document picker is available.", error.message)
        }
    }

    private fun openMap(latitude: Double?, longitude: Double?, result: MethodChannel.Result) {
        if (latitude == null || longitude == null) {
            result.error("invalid_location", "Latitude and longitude are required.", null)
            return
        }

        val uri = Uri.parse("geo:$latitude,$longitude?q=$latitude,$longitude")
        val intent = Intent(Intent.ACTION_VIEW, uri)

        try {
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("map_unavailable", "No map app is available.", error.message)
        }
    }

    private fun openDocumentUrl(url: String?, contentType: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("invalid_document_url", "Document URL is required.", null)
            return
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(url), contentType?.ifBlank { "*/*" } ?: "*/*")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))

            try {
                startActivity(fallbackIntent)
                result.success(null)
            } catch (fallbackError: Exception) {
                result.error("document_open_unavailable", "No app is available to open this document.", fallbackError.message)
            }
        }
    }

    private fun startVoiceMemo(result: MethodChannel.Result) {
        if (voiceMemoRecorder != null) {
            result.error("voice_memo_running", "Voice memo is already recording.", null)
            return
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            if (pendingVoiceMemoStartResult != null) {
                result.error("voice_memo_permission_busy", "Audio permission request is already running.", null)
                return
            }

            pendingVoiceMemoStartResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                recordAudioPermissionRequestCode,
            )
            return
        }

        beginVoiceMemo(result)
    }

    private fun beginVoiceMemo(result: MethodChannel.Result) {
        val targetDirectory = File(cacheDir, "chat_voice_memos").apply { mkdirs() }
        val targetFile = File(targetDirectory, "${System.currentTimeMillis()}_voice_memo.m4a")

        try {
            val recorder = MediaRecorder().apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
                setOutputFile(targetFile.absolutePath)
                prepare()
                start()
            }

            voiceMemoRecorder = recorder
            voiceMemoFile = targetFile
            voiceMemoStartedAt = System.currentTimeMillis()
            result.success(null)
        } catch (error: Exception) {
            voiceMemoRecorder = null
            voiceMemoFile = null
            voiceMemoStartedAt = 0L
            targetFile.delete()
            result.error("voice_memo_start_failed", "Voice memo could not be started.", error.message)
        }
    }

    private fun stopVoiceMemo(result: MethodChannel.Result) {
        val recorder = voiceMemoRecorder
        val file = voiceMemoFile

        if (recorder == null || file == null) {
            result.error("voice_memo_not_running", "No voice memo is currently recording.", null)
            return
        }

        val durationMs = (System.currentTimeMillis() - voiceMemoStartedAt).coerceAtLeast(0L)

        try {
            recorder.stop()
            recorder.reset()
            recorder.release()

            voiceMemoRecorder = null
            voiceMemoFile = null
            voiceMemoStartedAt = 0L

            if (!file.exists() || file.length() <= 0L) {
                result.error("voice_memo_empty", "Voice memo file is empty.", null)
                return
            }

            result.success(
                mapOf(
                    "path" to file.absolutePath,
                    "name" to "Sprachmemo.m4a",
                    "sizeBytes" to file.length(),
                    "contentType" to "audio/mp4",
                    "durationMs" to durationMs,
                )
            )
        } catch (error: Exception) {
            try {
                recorder.reset()
                recorder.release()
            } catch (_: Exception) {
            }

            voiceMemoRecorder = null
            voiceMemoFile = null
            voiceMemoStartedAt = 0L
            file.delete()
            result.error("voice_memo_stop_failed", "Voice memo could not be stopped.", error.message)
        }
    }

    private fun cancelVoiceMemo(result: MethodChannel.Result) {
        val recorder = voiceMemoRecorder
        val file = voiceMemoFile

        try {
            recorder?.reset()
            recorder?.release()
            file?.delete()
            result.success(null)
        } catch (error: Exception) {
            result.error("voice_memo_cancel_failed", "Voice memo could not be cancelled.", error.message)
        } finally {
            voiceMemoRecorder = null
            voiceMemoFile = null
            voiceMemoStartedAt = 0L
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == pickDocumentRequestCode) {
            handleDocumentResult(resultCode, data)
            return
        }

        if (requestCode != pickPhoneContactRequestCode) {
            return
        }

        val result = pendingContactResult ?: return
        pendingContactResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val contactUri = data.data!!
        var cursor: Cursor? = null

        try {
            cursor = contentResolver.query(
                contactUri,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                ),
                null,
                null,
                null,
            )

            if (cursor == null || !cursor.moveToFirst()) {
                result.success(null)
                return
            }

            val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val name = if (nameIndex >= 0) cursor.getString(nameIndex) ?: "" else ""
            val phoneNumber = if (numberIndex >= 0) cursor.getString(numberIndex) ?: "" else ""

            result.success(
                mapOf(
                    "name" to name,
                    "phoneNumber" to phoneNumber,
                )
            )
        } catch (error: Exception) {
            result.error("contact_read_failed", "Contact could not be read.", error.message)
        } finally {
            cursor?.close()
        }
    }

    private fun handleDocumentResult(resultCode: Int, data: Intent?) {
        val result = pendingDocumentResult ?: return
        pendingDocumentResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val documentUri = data.data!!

        try {
            val displayName = documentDisplayName(documentUri)
            val contentType = contentResolver.getType(documentUri) ?: "application/octet-stream"
            val targetDirectory = File(cacheDir, "chat_documents").apply { mkdirs() }
            val targetFile = File(targetDirectory, "${System.currentTimeMillis()}_${sanitizeFileName(displayName)}")

            contentResolver.openInputStream(documentUri).use { input ->
                if (input == null) {
                    result.error("document_read_failed", "Document could not be opened.", null)
                    return
                }

                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }

            result.success(
                mapOf(
                    "path" to targetFile.absolutePath,
                    "name" to displayName,
                    "sizeBytes" to targetFile.length(),
                    "contentType" to contentType,
                )
            )
        } catch (error: Exception) {
            result.error("document_read_failed", "Document could not be read.", error.message)
        }
    }

    private fun documentDisplayName(uri: Uri): String {
        var cursor: Cursor? = null

        try {
            cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )

            if (cursor != null && cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)

                if (nameIndex >= 0) {
                    val name = cursor.getString(nameIndex)

                    if (!name.isNullOrBlank()) {
                        return name
                    }
                }
            }
        } finally {
            cursor?.close()
        }

        return "Dokument"
    }

    private fun sanitizeFileName(value: String): String {
        return value.replace(Regex("[^a-zA-Z0-9._-]+"), "_").ifBlank { "document" }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != recordAudioPermissionRequestCode) {
            return
        }

        val result = pendingVoiceMemoStartResult ?: return
        pendingVoiceMemoStartResult = null

        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            beginVoiceMemo(result)
        } else {
            result.error("voice_memo_permission_denied", "Microphone permission was denied.", null)
        }
    }
}
