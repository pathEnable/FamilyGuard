package com.example.mobile

import android.app.Service
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log

class FamilyGuardVpnService : VpnService() {
    companion object {
        private const val TAG = "FamilyGuardVpnService"
        const val ACTION_START_VPN = "com.familyguard.START_VPN"
        const val ACTION_STOP_VPN = "com.familyguard.STOP_VPN"
        const val EXTRA_BLOCKED_APPS = "blocked_apps"
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var blockedApps: List<String> = emptyList()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return Service.START_NOT_STICKY

        when (intent.action) {
            ACTION_START_VPN -> {
                val apps = intent.getStringArrayExtra(EXTRA_BLOCKED_APPS)?.toList() ?: emptyList()
                Log.d(TAG, "Starting VPN to block apps: $apps")
                blockedApps = apps
                setupVpn()
            }
            ACTION_STOP_VPN -> {
                Log.d(TAG, "Stopping VPN")
                stopVpn()
            }
        }
        return Service.START_STICKY
    }

    private fun setupVpn() {
        if (vpnInterface != null) {
            try {
                vpnInterface?.close()
                vpnInterface = null
            } catch (e: Exception) {
                Log.e(TAG, "Error closing existing VPN interface", e)
            }
        }

        if (blockedApps.isEmpty()) {
            Log.d(TAG, "No apps to block, stopping VPN interface.")
            return
        }

        val builder = Builder()
            .setSession("FamilyGuard Firewall")
            // We assign a local IP to the VPN tunnel
            .addAddress("10.0.0.2", 32)
            .addRoute("0.0.0.0", 0)

        // Only the blocked apps will have their traffic routed to this dead-end tunnel
        for (app in blockedApps) {
            try {
                builder.addAllowedApplication(app)
                Log.d(TAG, "Added $app to VPN blocked list.")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to add application to VPN: $app", e)
            }
        }

        try {
            vpnInterface = builder.establish()
            Log.i(TAG, "VPN established. Traffic for blocked apps is now dropping into a black hole.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN", e)
        }
    }

    private fun stopVpn() {
        try {
            vpnInterface?.close()
            vpnInterface = null
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping VPN", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVpn()
    }
}
