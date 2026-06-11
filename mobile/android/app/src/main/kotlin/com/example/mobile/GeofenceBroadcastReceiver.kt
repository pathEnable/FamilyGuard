package com.example.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Native BroadcastReceiver that fires when Android's GeofencingClient
 * detects the device crossing a geofence boundary.
 *
 * This runs entirely in the OS — no need to wake up the Flutter/Dart engine.
 * It reads auth credentials from SharedPreferences and sends a lightweight
 * HTTP POST to the backend's /geofence-alert endpoint.
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GeofenceReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        if (geofencingEvent == null) {
            Log.e(TAG, "GeofencingEvent is null")
            return
        }
        if (geofencingEvent.hasError()) {
            Log.e(TAG, "Geofencing error code: ${geofencingEvent.errorCode}")
            return
        }

        val transitionType = geofencingEvent.geofenceTransition
        val transitionName = when (transitionType) {
            Geofence.GEOFENCE_TRANSITION_EXIT -> "EXIT"
            Geofence.GEOFENCE_TRANSITION_ENTER -> "ENTER"
            else -> "UNKNOWN"
        }

        val triggeringGeofences = geofencingEvent.triggeringGeofences ?: return
        val prefs = context.getSharedPreferences("familyguard_prefs", Context.MODE_PRIVATE)
        val token = prefs.getString("auth_token", null)
        val profileId = prefs.getInt("current_profile_id", -1)
        val baseUrl = prefs.getString("base_url", null)

        if (token == null || profileId == -1 || baseUrl == null) {
            Log.w(TAG, "Missing auth data in SharedPreferences, cannot report geofence event")
            return
        }

        for (geofence in triggeringGeofences) {
            val zoneName = geofence.requestId // We use the zone name as the requestId
            Log.i(TAG, "Geofence transition: $transitionName for zone '$zoneName'")

            // Send alert to backend in a background thread (no Flutter engine needed)
            thread {
                try {
                    val url = URL("$baseUrl/location/$profileId/geofence-alert")
                    val connection = url.openConnection() as HttpURLConnection
                    connection.requestMethod = "POST"
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("Authorization", "Bearer $token")
                    connection.doOutput = true
                    connection.connectTimeout = 10000
                    connection.readTimeout = 10000

                    val body = """{"zone_name": "$zoneName", "transition_type": "$transitionName"}"""
                    val writer = OutputStreamWriter(connection.outputStream)
                    writer.write(body)
                    writer.flush()
                    writer.close()

                    val responseCode = connection.responseCode
                    Log.i(TAG, "Geofence alert sent for '$zoneName' ($transitionName) — HTTP $responseCode")
                    connection.disconnect()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send geofence alert: ${e.message}")
                }
            }
        }
    }
}
