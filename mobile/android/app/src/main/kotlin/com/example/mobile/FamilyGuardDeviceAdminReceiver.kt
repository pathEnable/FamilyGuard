package com.example.mobile

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class FamilyGuardDeviceAdminReceiver : DeviceAdminReceiver() {
    companion object {
        private const val TAG = "DeviceAdminReceiver"
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.i(TAG, "Device Administrator is enabled.")
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        // This message is shown to the user when they try to deactivate the Device Admin.
        // It serves as a deterrent.
        return "Si vous désactivez l'administration, FamilyGuard ne pourra plus protéger cet appareil. Demandez à vos parents avant de continuer."
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.i(TAG, "Device Administrator is disabled.")
    }
}
