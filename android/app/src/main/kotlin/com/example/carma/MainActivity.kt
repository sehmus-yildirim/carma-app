package com.example.carma

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "carma/chat_tools"
    private val pickPhoneContactRequestCode = 4701
    private var pendingContactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickPhoneContact" -> pickPhoneContact(result)
                    "openMap" -> openMap(call.argument<Double>("latitude"), call.argument<Double>("longitude"), result)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

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
}
