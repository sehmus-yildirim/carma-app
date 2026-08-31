package de.plaqa.app

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.location.Geocoder
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaRecorder
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import android.speech.RecognizerIntent
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.BufferedInputStream
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "plaqa/chat_tools"
    private val notificationChannelName = "plaqa/notifications"
    private val pushNotificationChannelId = "plaqa_messages"
    private var notificationMethodChannel: MethodChannel? = null
    private val pickPhoneContactRequestCode = 4701
    private val pickDocumentRequestCode = 4702
    private val recordAudioPermissionRequestCode = 4703
    private val recognizePlateSpeechRequestCode = 4704
    private var pendingContactResult: MethodChannel.Result? = null
    private var pendingDocumentResult: MethodChannel.Result? = null
    private var pendingVoiceMemoStartResult: MethodChannel.Result? = null
    private var pendingPlateSpeechResult: MethodChannel.Result? = null
    private var voiceMemoRecorder: MediaRecorder? = null
    private var voiceMemoFile: File? = null
    private var voiceMemoStartedAt: Long = 0L
    private var voiceMemoPlayer: MediaPlayer? = null
    private var messageRingtone: Ringtone? = null
    private val allowedDocumentMimeTypes = arrayOf(
        "text/*",
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/vnd.ms-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "application/rtf",
        "application/octet-stream",
    )
    private val maxImageBytes = 15L * 1024L * 1024L
    private val maxVoiceMemoBytes = 15L * 1024L * 1024L
    private val maxDocumentBytes = 25L * 1024L * 1024L
    private val maxVideoBytes = 80L * 1024L * 1024L
    private val networkConnectTimeoutMs = 10_000
    private val networkReadTimeoutMs = 20_000

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        notificationMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "showNotification" -> showPushNotification(
                        id = call.argument<Int>("id"),
                        title = call.argument<String>("title"),
                        body = call.argument<String>("body"),
                        type = call.argument<String>("type"),
                        resourceId = call.argument<String>("resourceId"),
                        result = result,
                    )
                    else -> result.notImplemented()
                }
            }
        }
        createPushNotificationChannel()
        dispatchLocalNotificationIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickPhoneContact" -> pickPhoneContact(result)
                    "openMap" -> openMap(call.argument<Double>("latitude"), call.argument<Double>("longitude"), result)
                    "reverseGeocodeLocation" -> reverseGeocodeLocation(call.argument<Double>("latitude"), call.argument<Double>("longitude"), result)
                    "pickDocumentFile" -> pickDocumentFile(result)
                    "openDocumentUrl" -> openDocumentUrl(call.argument<String>("url"), call.argument<String>("contentType"), result)
                    "shareText" -> shareText(call.argument<String>("text"), result)
                    "saveImageToGallery" -> saveImageToGallery(call.argument<String>("url"), call.argument<String>("fileName"), call.argument<String>("contentType"), result)
                    "saveVideoToGallery" -> saveVideoToGallery(call.argument<String>("url"), call.argument<String>("fileName"), call.argument<String>("contentType"), result)
                    "saveDocumentToDownloads" -> saveDocumentToDownloads(call.argument<String>("url"), call.argument<String>("fileName"), call.argument<String>("contentType"), result)
                    "startVoiceMemo" -> startVoiceMemo(result)
                    "stopVoiceMemo" -> stopVoiceMemo(result)
                    "cancelVoiceMemo" -> cancelVoiceMemo(result)
                    "playVoiceMemo" -> playVoiceMemo(call.argument<String>("url"), result)
                    "stopVoiceMemoPlayback" -> stopVoiceMemoPlayback(result)
                    "recognizePlateSpeech" -> recognizePlateSpeech(result)
                    "getAppPermissionStatuses" -> getAppPermissionStatuses(result)
                    "openAppSettings" -> openAppSettings(result)
                    "playMessageSound" -> playMessageSound(result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchLocalNotificationIntent(intent)
    }

    private fun showPushNotification(
        id: Int?,
        title: String?,
        body: String?,
        type: String?,
        resourceId: String?,
        result: MethodChannel.Result,
    ) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.success(false)
            return
        }

        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createPushNotificationChannel()

        val notificationId = id ?: (System.currentTimeMillis() and 0x7fffffff).toInt()
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("plaqaLocalNotification", true)
            putExtra("type", type)
            putExtra("resourceId", resourceId)
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            notificationId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, pushNotificationChannelId)
            .setSmallIcon(R.drawable.plaqa_notification_icon)
            .setContentTitle(title?.trim().takeUnless { it.isNullOrEmpty() } ?: "plaqa")
            .setContentText(body?.trim().orEmpty())
            .setStyle(NotificationCompat.BigTextStyle().bigText(body?.trim().orEmpty()))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        notificationManager.notify(notificationId, notification)
        result.success(true)
    }

    private fun createPushNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(
            NotificationChannel(
                pushNotificationChannelId,
                "Nachrichten und Hinweise",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Mitteilungen zu Chats, Anfragen und wichtigen Hinweisen"
            },
        )
    }

    private fun dispatchLocalNotificationIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("plaqaLocalNotification", false) != true) return

        val payload = mapOf(
            "type" to intent.getStringExtra("type"),
            "resourceId" to intent.getStringExtra("resourceId"),
        )
        intent.removeExtra("plaqaLocalNotification")
        notificationMethodChannel?.invokeMethod("notificationOpened", payload)
    }

    private fun playMessageSound(result: MethodChannel.Result) {
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        val notificationsAudible =
            audioManager.ringerMode == AudioManager.RINGER_MODE_NORMAL &&
                audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION) > 0

        if (!notificationsAudible) {
            result.success(false)
            return
        }

        try {
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, soundUri)
            if (ringtone == null) {
                result.success(false)
                return
            }

            ringtone.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            messageRingtone?.stop()
            messageRingtone = ringtone
            ringtone.play()
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun getAppPermissionStatuses(result: MethodChannel.Result) {
        val statuses = mapOf(
            "platform" to "android",
            "sdkInt" to Build.VERSION.SDK_INT,
            "camera" to permissionState(Manifest.permission.CAMERA),
            "microphone" to permissionState(Manifest.permission.RECORD_AUDIO),
            "location" to locationPermissionState(),
            "media" to mediaPermissionState(),
            "contacts" to "notRequired",
        )
        result.success(statuses)
    }

    private fun openAppSettings(result: MethodChannel.Result) {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName"),
        ).apply {
            addCategory(Intent.CATEGORY_DEFAULT)
        }

        try {
            startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.error(
                "app_settings_unavailable",
                "Android app settings could not be opened.",
                null,
            )
        }
    }

    private fun permissionState(permission: String): String {
        return if (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        ) {
            "granted"
        } else {
            "denied"
        }
    }

    private fun locationPermissionState(): String {
        val fineGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED

        return if (fineGranted || coarseGranted) "granted" else "denied"
    }

    private fun mediaPermissionState(): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val imagesGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_MEDIA_IMAGES,
            ) == PackageManager.PERMISSION_GRANTED
            val videosGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_MEDIA_VIDEO,
            ) == PackageManager.PERMISSION_GRANTED
            val selectedGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
            ) == PackageManager.PERMISSION_GRANTED

            return when {
                imagesGranted && videosGranted -> "granted"
                selectedGranted || imagesGranted || videosGranted -> "restricted"
                else -> "denied"
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val imagesGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_MEDIA_IMAGES,
            ) == PackageManager.PERMISSION_GRANTED
            val videosGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_MEDIA_VIDEO,
            ) == PackageManager.PERMISSION_GRANTED

            return when {
                imagesGranted && videosGranted -> "granted"
                imagesGranted || videosGranted -> "restricted"
                else -> "denied"
            }
        }

        return permissionState(Manifest.permission.READ_EXTERNAL_STORAGE)
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
            putExtra(Intent.EXTRA_MIME_TYPES, allowedDocumentMimeTypes)
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

    private fun reverseGeocodeLocation(latitude: Double?, longitude: Double?, result: MethodChannel.Result) {
        if (latitude == null || longitude == null) {
            result.error("invalid_location", "Latitude and longitude are required.", null)
            return
        }

        Thread {
            try {
                val geocoder = Geocoder(this, Locale.getDefault())
                val places = geocoder.getFromLocation(latitude, longitude, 5).orEmpty()
                    .mapNotNull { address ->
                        val city = address.locality?.trim().orEmpty()
                            .ifBlank { address.subLocality?.trim().orEmpty() }
                            .ifBlank { address.subAdminArea?.trim().orEmpty() }
                        val region = address.adminArea?.trim().orEmpty()
                        val country = address.countryName?.trim().orEmpty()
                        val street = address.thoroughfare?.trim().orEmpty()
                        val feature = address.featureName?.trim().orEmpty()
                        val houseNumber = address.subThoroughfare?.trim().orEmpty()
                            .ifBlank {
                                feature.takeIf {
                                    it.isNotBlank() &&
                                        it != street &&
                                        it != city &&
                                        it.any(Char::isDigit)
                                }.orEmpty()
                            }
                        val streetLine = listOf(street, houseNumber)
                            .map { it.trim() }
                            .filter { it.isNotEmpty() }
                            .distinct()
                            .joinToString(" ")
                            .ifBlank { feature }
                        val cityOrRegion = city.ifBlank { region }
                        val labelParts = listOf(streetLine, cityOrRegion)
                            .map { it.trim() }
                            .filter { it.isNotEmpty() }
                            .distinct()
                        val label = labelParts.joinToString(", ").ifBlank {
                            "%.5f, %.5f".format(Locale.US, latitude, longitude)
                        }

                        if (label.isBlank()) {
                            null
                        } else {
                            mapOf(
                                "label" to label,
                                "city" to city,
                                "region" to region,
                                "country" to country,
                            )
                        }
                    }

                runOnUiThread {
                    result.success(mapOf("places" to places))
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("reverse_geocode_failed", "Location could not be resolved.", error.message)
                }
            }
        }.start()
    }

    private fun openDocumentUrl(url: String?, contentType: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("invalid_document_url", "Document URL is required.", null)
            return
        }
        val normalizedContentType = normalizeDocumentContentType(contentType)
        if (normalizedContentType == null) {
            result.error("invalid_document_type", "Document type is not allowed.", null)
            return
        }

        Thread {
            try {
                val sourceFile = materializeSafeSource(
                    value = url,
                    fileName = "document_${System.currentTimeMillis()}",
                    contentType = normalizedContentType,
                    maxBytes = maxDocumentBytes,
                )
                val contentUri = FileProvider.getUriForFile(
                    this,
                    "$packageName.secure-files",
                    sourceFile,
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(contentUri, normalizedContentType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                runOnUiThread {
                    try {
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "document_open_unavailable",
                            "No app is available to open this document.",
                            error.message,
                        )
                    }
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "invalid_document_source",
                        "Document source is not allowed.",
                        error.message,
                    )
                }
            }
        }.start()
    }

    private fun shareText(text: String?, result: MethodChannel.Result) {
        if (text.isNullOrBlank()) {
            result.error("invalid_share_text", "Text is required.", null)
            return
        }

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }

        try {
            startActivity(Intent.createChooser(intent, "Teilen"))
            result.success(null)
        } catch (error: Exception) {
            result.error("share_unavailable", "No app is available for sharing.", error.message)
        }
    }

    private fun saveImageToGallery(
        url: String?,
        fileName: String?,
        contentType: String?,
        result: MethodChannel.Result,
    ) {
        saveFileToMediaStore(
            url = url,
            fileName = fileName?.ifBlank { null } ?: "plaqa_image_${System.currentTimeMillis()}.jpg",
            contentType = contentType?.ifBlank { null } ?: "image/jpeg",
            isImage = true,
            result = result,
        )
    }

    private fun saveVideoToGallery(
        url: String?,
        fileName: String?,
        contentType: String?,
        result: MethodChannel.Result,
    ) {
        saveFileToMediaStore(
            url = url,
            fileName = fileName?.ifBlank { null } ?: "plaqa_video_${System.currentTimeMillis()}.mp4",
            contentType = contentType?.ifBlank { null } ?: "video/mp4",
            isImage = true,
            result = result,
        )
    }

    private fun saveDocumentToDownloads(
        url: String?,
        fileName: String?,
        contentType: String?,
        result: MethodChannel.Result,
    ) {
        saveFileToMediaStore(
            url = url,
            fileName = fileName?.ifBlank { null } ?: "plaqa_document_${System.currentTimeMillis()}",
            contentType = contentType?.ifBlank { null } ?: "application/octet-stream",
            isImage = false,
            result = result,
        )
    }

    private fun saveFileToMediaStore(
        url: String?,
        fileName: String,
        contentType: String,
        isImage: Boolean,
        result: MethodChannel.Result,
    ) {
        if (url.isNullOrBlank()) {
            result.error("invalid_save_url", "File URL is required.", null)
            return
        }
        val normalizedContentType = normalizeSaveContentType(contentType, isImage)
        if (normalizedContentType == null) {
            result.error("invalid_save_type", "File type is not allowed.", null)
            return
        }

        Thread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    saveFileWithScopedStorage(
                        url,
                        fileName,
                        normalizedContentType,
                        isImage,
                    )
                } else {
                    saveFileLegacy(
                        url,
                        fileName,
                        normalizedContentType,
                        isImage,
                    )
                }

                runOnUiThread {
                    result.success(null)
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("file_save_failed", "File could not be saved.", error.message)
                }
            }
        }.start()
    }

    private fun saveFileWithScopedStorage(
        url: String,
        fileName: String,
        contentType: String,
        isImage: Boolean,
    ) {
        val isVideoMedia = isImage && contentType.startsWith("video/")
        val targetCollection = if (isImage) {
            if (isVideoMedia) {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
        } else {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        }
        val relativePath = if (isImage) {
            if (isVideoMedia) {
                Environment.DIRECTORY_MOVIES + "/plaqa"
            } else {
                Environment.DIRECTORY_PICTURES + "/plaqa"
            }
        } else {
            Environment.DIRECTORY_DOWNLOADS + "/plaqa"
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, sanitizeFileName(fileName))
            put(MediaStore.MediaColumns.MIME_TYPE, contentType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val targetUri = contentResolver.insert(targetCollection, values)
            ?: throw IllegalStateException("Could not create target media entry.")

        try {
            contentResolver.openOutputStream(targetUri).use { output ->
                if (output == null) {
                    throw IllegalStateException("Could not open target file.")
                }

                openSourceStream(
                    url,
                    contentType,
                    maximumBytesFor(contentType),
                ).use { input ->
                    copyStreamWithLimit(
                        input,
                        output,
                        maximumBytesFor(contentType),
                    )
                }
            }

            val completedValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            contentResolver.update(targetUri, completedValues, null, null)
        } catch (error: Exception) {
            contentResolver.delete(targetUri, null, null)
            throw error
        }
    }

    private fun saveFileLegacy(url: String, fileName: String, contentType: String, isImage: Boolean) {
        val isVideoMedia = isImage && contentType.startsWith("video/")
        val baseDirectory = if (isImage) {
            if (isVideoMedia) {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
            } else {
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            }
        } else {
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        }
        val targetDirectory = File(baseDirectory, "plaqa").apply { mkdirs() }
        val targetFile = File(targetDirectory, sanitizeFileName(fileName))

        FileOutputStream(targetFile).use { output ->
            openSourceStream(
                url,
                contentType,
                maximumBytesFor(contentType),
            ).use { input ->
                copyStreamWithLimit(
                    input,
                    output,
                    maximumBytesFor(contentType),
                )
            }
        }

        if (isImage) {
            sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(targetFile)))
        }
    }

    private fun openSourceStream(
        value: String,
        contentType: String,
        maxBytes: Long,
    ): InputStream {
        val trimmedValue = value.trim()
        val rawStream = if (isTrustedFirebaseStorageUrl(trimmedValue)) {
            openTrustedRemoteStream(trimmedValue, contentType, maxBytes)
        } else {
            val localFile = resolveAppOwnedFile(trimmedValue)
                ?: throw SecurityException("Only app-owned local files are allowed.")
            if (!localFile.isFile || localFile.length() <= 0L || localFile.length() > maxBytes) {
                throw SecurityException("Local file size is not allowed.")
            }
            FileInputStream(localFile)
        }
        val buffered = BufferedInputStream(rawStream)
        verifyContentSignature(buffered, contentType)
        return buffered
    }

    private fun materializeSafeSource(
        value: String,
        fileName: String,
        contentType: String,
        maxBytes: Long,
    ): File {
        resolveAppOwnedFile(value)?.let { localFile ->
            if (!localFile.isFile || localFile.length() <= 0L || localFile.length() > maxBytes) {
                throw SecurityException("Local file size is not allowed.")
            }
            BufferedInputStream(FileInputStream(localFile)).use { input ->
                verifyContentSignature(input, contentType)
            }
            return localFile
        }
        if (!isTrustedFirebaseStorageUrl(value)) {
            throw SecurityException("Remote source is not trusted.")
        }
        val targetDirectory = File(cacheDir, "secure_shared_media").apply { mkdirs() }
        val extension = extensionForContentType(contentType)
        val targetFile = File(
            targetDirectory,
            "${sanitizeFileName(fileName)}$extension",
        ).canonicalFile
        try {
            FileOutputStream(targetFile).use { output ->
                openSourceStream(value, contentType, maxBytes).use { input ->
                    copyStreamWithLimit(input, output, maxBytes)
                }
            }
            return targetFile
        } catch (error: Exception) {
            targetFile.delete()
            throw error
        }
    }

    private fun isTrustedFirebaseStorageUrl(value: String): Boolean {
        return try {
            val url = URL(value.trim())
            val path = url.path.orEmpty()
            val queryParts = url.query?.split('&').orEmpty()
            val altParts = queryParts.filter { it == "alt=media" }
            val tokenParts = queryParts.filter { part ->
                part.startsWith("token=") &&
                    part.removePrefix("token=").let { token ->
                        token.isNotEmpty() && token.length <= 512 &&
                            token.matches(Regex("^[A-Za-z0-9_%.,-]+$"))
                    }
            }
            url.protocol == "https" &&
                url.host == "firebasestorage.googleapis.com" &&
                url.userInfo == null &&
                path.matches(
                    Regex(
                        "^/v0/b/(carma-a84e4\\.firebasestorage\\.app|" +
                            "carma-a84e4\\.appspot\\.com)/o/[^/]+$",
                    ),
                ) &&
                altParts.size == 1 && tokenParts.size <= 1 &&
                queryParts.size == altParts.size + tokenParts.size
        } catch (_: Exception) {
            false
        }
    }

    private fun isAllowedRedirectUrl(url: URL): Boolean {
        val host = url.host.lowercase(Locale.US)
        return url.protocol == "https" && url.userInfo == null &&
            (host == "firebasestorage.googleapis.com" ||
                host == "storage.googleapis.com" ||
                host.endsWith(".googleusercontent.com"))
    }

    private fun openTrustedRemoteStream(
        value: String,
        expectedContentType: String,
        maxBytes: Long,
    ): InputStream {
        var currentUrl = URL(value)
        repeat(4) { redirectCount ->
            val connection = currentUrl.openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = networkConnectTimeoutMs
            connection.readTimeout = networkReadTimeoutMs
            connection.requestMethod = "GET"
            connection.setRequestProperty("Accept", expectedContentType)
            connection.connect()
            val responseCode = connection.responseCode
            if (responseCode in 300..399) {
                val location = connection.getHeaderField("Location")
                    ?: throw SecurityException("Remote redirect has no location.")
                connection.disconnect()
                if (redirectCount >= 3) {
                    throw SecurityException("Too many remote redirects.")
                }
                currentUrl = URL(currentUrl, location)
                if (!isAllowedRedirectUrl(currentUrl)) {
                    throw SecurityException("Remote redirect is not trusted.")
                }
                return@repeat
            }
            if (responseCode !in 200..299) {
                connection.disconnect()
                throw IllegalStateException("Remote source returned HTTP $responseCode.")
            }
            val contentLength = connection.contentLengthLong
            if (contentLength <= 0L || contentLength > maxBytes) {
                connection.disconnect()
                throw SecurityException("Remote file size is not allowed.")
            }
            val actualContentType = connection.contentType
                ?.substringBefore(';')
                ?.trim()
                ?.lowercase(Locale.US)
                .orEmpty()
            if (!contentTypesMatch(expectedContentType, actualContentType)) {
                connection.disconnect()
                throw SecurityException("Remote content type does not match.")
            }
            return connection.inputStream
        }
        throw SecurityException("Remote source could not be resolved.")
    }

    private fun resolveAppOwnedFile(value: String): File? {
        val trimmedValue = value.trim()
        if (trimmedValue.startsWith("content://") ||
            trimmedValue.startsWith("http://") ||
            trimmedValue.startsWith("https://")) {
            return null
        }
        val candidate = try {
            if (trimmedValue.startsWith("file://")) {
                File(Uri.parse(trimmedValue).path ?: return null)
            } else {
                File(trimmedValue)
            }.canonicalFile
        } catch (_: Exception) {
            return null
        }
        val roots = listOf(cacheDir.canonicalFile, filesDir.canonicalFile)
        return candidate.takeIf { file ->
            roots.any { root ->
                file.path == root.path || file.path.startsWith(root.path + File.separator)
            }
        }
    }

    private fun normalizeDocumentContentType(value: String?): String? {
        val normalized = value
            ?.substringBefore(';')
            ?.trim()
            ?.lowercase(Locale.US)
            .orEmpty()
        if (normalized.isEmpty()) return null
        return normalized.takeIf { contentType ->
            allowedDocumentMimeTypes.any { allowed ->
                allowed.endsWith("/*") && contentType.startsWith(allowed.removeSuffix("*")) ||
                    allowed == contentType
            }
        }
    }

    private fun normalizeSaveContentType(value: String, isMedia: Boolean): String? {
        val normalized = value.substringBefore(';').trim().lowercase(Locale.US)
        if (isMedia) {
            return normalized.takeIf {
                it == "image/jpeg" || it == "image/png" ||
                    it == "image/webp" || it == "video/mp4"
            }
        }
        return normalizeDocumentContentType(normalized)
    }

    private fun maximumBytesFor(contentType: String): Long {
        return when {
            contentType.startsWith("image/") -> maxImageBytes
            contentType.startsWith("video/") -> maxVideoBytes
            contentType.startsWith("audio/") -> maxVoiceMemoBytes
            else -> maxDocumentBytes
        }
    }

    private fun contentTypesMatch(expected: String, actual: String): Boolean {
        if (actual.isEmpty()) return false
        if (expected == "application/octet-stream") {
            return actual == expected || normalizeDocumentContentType(actual) != null
        }
        if (expected.startsWith("text/")) return actual.startsWith("text/")
        return expected == actual
    }

    private fun extensionForContentType(contentType: String): String {
        return when (contentType) {
            "application/pdf" -> ".pdf"
            "application/rtf" -> ".rtf"
            "image/jpeg" -> ".jpg"
            "image/png" -> ".png"
            "image/webp" -> ".webp"
            "video/mp4" -> ".mp4"
            "audio/mp4" -> ".m4a"
            else -> ".bin"
        }
    }

    private fun copyStreamWithLimit(
        input: InputStream,
        output: OutputStream,
        maxBytes: Long,
    ) {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0L
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            total += count
            if (total > maxBytes) {
                throw SecurityException("File exceeds the allowed size.")
            }
            output.write(buffer, 0, count)
        }
        if (total <= 0L) throw SecurityException("File is empty.")
    }

    private fun verifyContentSignature(input: BufferedInputStream, contentType: String) {
        input.mark(32)
        val header = ByteArray(16)
        val count = input.read(header)
        input.reset()
        if (count <= 0) throw SecurityException("File is empty.")
        fun startsWith(vararg bytes: Int): Boolean {
            return count >= bytes.size && bytes.indices.all { index ->
                header[index].toInt() and 0xff == bytes[index]
            }
        }
        val isJpeg = startsWith(0xff, 0xd8, 0xff)
        val isPng = startsWith(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)
        val isWebp = count >= 12 &&
            String(header, 0, 4, Charsets.US_ASCII) == "RIFF" &&
            String(header, 8, 4, Charsets.US_ASCII) == "WEBP"
        val isMp4 = count >= 12 && String(header, 4, 4, Charsets.US_ASCII) == "ftyp"
        val isPdf = String(header, 0, minOf(count, 5), Charsets.US_ASCII) == "%PDF-"
        val isZip = startsWith(0x50, 0x4b, 0x03, 0x04)
        val isCompoundOffice = startsWith(0xd0, 0xcf, 0x11, 0xe0)
        val isRtf = String(header, 0, minOf(count, 5), Charsets.US_ASCII) == "{\\rtf"
        val isExecutable = startsWith(0x4d, 0x5a) || startsWith(0x7f, 0x45, 0x4c, 0x46)
        val valid = when {
            contentType == "image/jpeg" -> isJpeg
            contentType == "image/png" -> isPng
            contentType == "image/webp" -> isWebp
            contentType == "video/mp4" || contentType == "audio/mp4" -> isMp4
            contentType == "application/pdf" -> isPdf
            contentType == "application/rtf" -> isRtf
            contentType.startsWith("text/") -> header.take(count).none { it.toInt() == 0 }
            contentType.contains("officedocument") -> isZip
            contentType == "application/msword" ||
                contentType == "application/vnd.ms-excel" ||
                contentType == "application/vnd.ms-powerpoint" -> isCompoundOffice
            contentType == "application/octet-stream" -> !isExecutable
            else -> false
        }
        if (!valid) throw SecurityException("File signature does not match its type.")
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

    private fun playVoiceMemo(url: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("invalid_voice_memo_url", "Voice memo URL is required.", null)
            return
        }

        stopVoiceMemoPlayer()
        Thread {
            try {
                val sourceFile = materializeSafeSource(
                    value = url,
                    fileName = "voice_${System.currentTimeMillis()}",
                    contentType = "audio/mp4",
                    maxBytes = maxVoiceMemoBytes,
                )
                runOnUiThread {
                    try {
                        val player = MediaPlayer().apply {
                            setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                    .setUsage(AudioAttributes.USAGE_MEDIA)
                                    .build(),
                            )
                            setDataSource(sourceFile.absolutePath)
                            setOnCompletionListener { stopVoiceMemoPlayer() }
                            setOnErrorListener { _, _, _ ->
                                stopVoiceMemoPlayer()
                                true
                            }
                            setOnPreparedListener { it.start() }
                            prepareAsync()
                        }
                        voiceMemoPlayer = player
                        result.success(null)
                    } catch (error: Exception) {
                        stopVoiceMemoPlayer()
                        result.error(
                            "voice_memo_play_failed",
                            "Voice memo could not be played.",
                            error.message,
                        )
                    }
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "invalid_voice_memo_source",
                        "Voice memo source is not allowed.",
                        error.message,
                    )
                }
            }
        }.start()
    }

    private fun stopVoiceMemoPlayback(result: MethodChannel.Result) {
        stopVoiceMemoPlayer()
        result.success(null)
    }

    private fun stopVoiceMemoPlayer() {
        try {
            voiceMemoPlayer?.stop()
        } catch (_: Exception) {
        }

        try {
            voiceMemoPlayer?.release()
        } catch (_: Exception) {
        }

        voiceMemoPlayer = null
    }

    private fun recognizePlateSpeech(result: MethodChannel.Result) {
        if (pendingPlateSpeechResult != null) {
            result.error("plate_speech_busy", "Speech recognition is already running.", null)
            return
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.GERMAN.toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, Locale.GERMAN.toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PROMPT, "Kennzeichen sprechen")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
        }

        pendingPlateSpeechResult = result

        try {
            startActivityForResult(intent, recognizePlateSpeechRequestCode)
        } catch (error: Exception) {
            pendingPlateSpeechResult = null
            result.error(
                "plate_speech_unavailable",
                "Keine Spracheingabe ist auf diesem Gerät verfügbar.",
                error.message,
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == recognizePlateSpeechRequestCode) {
            val result = pendingPlateSpeechResult ?: return
            pendingPlateSpeechResult = null

            if (resultCode != Activity.RESULT_OK) {
                result.success(null)
                return
            }

            val matches = data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.mapNotNull { value -> value?.trim()?.takeIf { it.isNotEmpty() } }
                .orEmpty()

            result.success(
                mapOf(
                    "transcript" to (matches.firstOrNull() ?: ""),
                    "alternatives" to matches,
                )
            )
            return
        }

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
            val contentType = normalizeDocumentContentType(
                contentResolver.getType(documentUri) ?: "application/octet-stream",
            ) ?: throw SecurityException("Document type is not allowed.")
            val targetDirectory = File(cacheDir, "chat_documents").apply { mkdirs() }
            val targetFile = File(targetDirectory, "${System.currentTimeMillis()}_${sanitizeFileName(displayName)}")
            try {
                contentResolver.openInputStream(documentUri).use { rawInput ->
                    if (rawInput == null) {
                        throw IllegalStateException("Document could not be opened.")
                    }
                    BufferedInputStream(rawInput).use { input ->
                        verifyContentSignature(input, contentType)
                        FileOutputStream(targetFile).use { output ->
                            copyStreamWithLimit(input, output, maxDocumentBytes)
                        }
                    }
                }
            } catch (error: Exception) {
                targetFile.delete()
                throw error
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
