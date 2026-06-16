package com.example.mobile

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.net.VpnService
import android.app.usage.UsageStatsManager
import android.app.AppOpsManager
import android.os.Process
import java.util.Calendar
import android.content.BroadcastReceiver
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val LOCK_CHANNEL = "com.familyguard/lock"
    private val PIN_CHANNEL = "com.familyguard/pin"
    private val GEOFENCE_CHANNEL = "com.familyguard/geofence"
    private val DEVICE_ADMIN_CHANNEL = "com.familyguard/device_admin"
    private val VPN_CHANNEL = "com.familyguard/vpn"
    private val USAGE_STATS_CHANNEL = "com.familyguard/usage_stats"
    private val WEB_FILTER_EVENT_CHANNEL = "com.familyguard/web_filter_events"
    private val OVERLAY_PERMISSION_REQ_CODE = 1234
    private val DEVICE_ADMIN_REQ_CODE = 1235
    private val VPN_REQ_CODE = 1236

    private lateinit var geofencingClient: GeofencingClient
    private var pendingBlockedApps: List<String> = emptyList()
    private var pendingIsExamMode: Boolean = false
    private var pendingAllowedApps: Array<String> = emptyArray()
    private var pendingLockReason: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        geofencingClient = LocationServices.getGeofencingClient(this)

        // ── Lock/Unlock Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLock" -> {
                    val allowedApps = call.argument<List<String>>("allowedApps") ?: emptyList()
                    val isExamMode = call.argument<Boolean>("isExamMode") ?: false
                    val reason = call.argument<String>("reason")
                    checkOverlayPermissionAndStart(isExamMode, allowedApps.toTypedArray(), reason)
                    result.success(null)
                }
                "stopLock" -> {
                    stopLockService()
                    result.success(null)
                }
                "hasOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivityForResult(intent, OVERLAY_PERMISSION_REQ_CODE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── PIN Sync Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setPin" -> {
                    val pin = call.argument<String>("pin") ?: ""
                    getSharedPreferences("familyguard_prefs", Context.MODE_PRIVATE)
                        .edit()
                        .putString("lock_pin", pin)
                        .apply()
                    result.success(true)
                }
                "getPin" -> {
                    val pin = getSharedPreferences("familyguard_prefs", Context.MODE_PRIVATE)
                        .getString("lock_pin", "") ?: ""
                    result.success(pin)
                }
                "clearPin" -> {
                    getSharedPreferences("familyguard_prefs", Context.MODE_PRIVATE)
                        .edit()
                        .remove("lock_pin")
                        .apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Geofence Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEOFENCE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setupGeofences" -> {
                    @Suppress("UNCHECKED_CAST")
                    val zones = call.argument<List<Map<String, Any>>>("zones") ?: emptyList()
                    setupNativeGeofences(zones)
                    result.success(true)
                }
                "syncAuthData" -> {
                    val token = call.argument<String>("token") ?: ""
                    val profileId = call.argument<Int>("profileId") ?: -1
                    val baseUrl = call.argument<String>("baseUrl") ?: ""
                    getSharedPreferences("familyguard_prefs", Context.MODE_PRIVATE)
                        .edit()
                        .putString("auth_token", token)
                        .putInt("current_profile_id", profileId)
                        .putString("base_url", baseUrl)
                        .apply()
                    result.success(true)
                }
                "removeAllGeofences" -> {
                    geofencingClient.removeGeofences(getGeofencePendingIntent())
                        .addOnSuccessListener { result.success(true) }
                        .addOnFailureListener { result.success(false) }
                }
                else -> result.notImplemented()
            }
        }

        // ── Device Admin Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_ADMIN_CHANNEL).setMethodCallHandler { call, result ->
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val compName = ComponentName(this, FamilyGuardDeviceAdminReceiver::class.java)

            when (call.method) {
                "isDeviceAdminEnabled" -> {
                    result.success(dpm.isAdminActive(compName))
                }
                "requestDeviceAdmin" -> {
                    if (!dpm.isAdminActive(compName)) {
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, compName)
                        intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                            "Activer l'administration de l'appareil empêchera la désinstallation non autorisée de FamilyGuard par l'enfant.")
                        startActivityForResult(intent, DEVICE_ADMIN_REQ_CODE)
                        result.success(true)
                    } else {
                        result.success(true) // Already active
                    }
                }
                "requestNotificationListenerPermission" -> {
                    val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── VPN Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val apps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    val vpnIntent = VpnService.prepare(this)
                    if (vpnIntent != null) {
                        pendingBlockedApps = apps
                        startActivityForResult(vpnIntent, VPN_REQ_CODE)
                        // Note: actual start happens in onActivityResult
                        result.success(false)
                    } else {
                        // Permission already granted
                        startFamilyGuardVpn(apps)
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    val intent = Intent(this, FamilyGuardVpnService::class.java)
                    intent.action = FamilyGuardVpnService.ACTION_STOP_VPN
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ── Usage Stats Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_STATS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> {
                    val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                    val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
                    result.success(mode == AppOpsManager.MODE_ALLOWED)
                }
                "requestUsageStatsPermission" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }
                "getDailyAppUsage" -> {
                    val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                    val calendar = Calendar.getInstance()
                    val endTime = calendar.timeInMillis
                    calendar.set(Calendar.HOUR_OF_DAY, 0)
                    calendar.set(Calendar.MINUTE, 0)
                    calendar.set(Calendar.SECOND, 0)
                    val startTime = calendar.timeInMillis

                    val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
                    val usageMap = mutableMapOf<String, Map<String, Any>>()
                    val pm = packageManager
                    
                    if (stats != null) {
                        for (stat in stats) {
                            val minutes = (stat.totalTimeInForeground / 60000).toInt()
                            if (minutes > 0) {
                                val existing = usageMap[stat.packageName]
                                val currentMinutes = (existing?.get("minutes") as? Int) ?: 0
                                val appName = try {
                                    val appInfo = pm.getApplicationInfo(stat.packageName, 0)
                                    pm.getApplicationLabel(appInfo).toString()
                                } catch (e: Exception) {
                                    stat.packageName.substringAfterLast(".")
                                        .replace("_", " ").replaceFirstChar { it.uppercase() }
                                }
                                usageMap[stat.packageName] = mapOf(
                                    "minutes" to (currentMinutes + minutes),
                                    "app_name" to appName
                                )
                            }
                        }
                    }
                    result.success(usageMap)
                }
                else -> result.notImplemented()
            }
        }

        // ── Web Filter Event Channel ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WEB_FILTER_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                private var receiver: BroadcastReceiver? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            if (intent?.action == WebFilterAccessibilityService.ACTION_URL_DETECTED) {
                                val url = intent.getStringExtra("url")
                                events?.success(mapOf("type" to "url", "value" to url))
                            } else if (intent?.action == WebFilterAccessibilityService.ACTION_TEXT_DETECTED) {
                                val text = intent.getStringExtra("text")
                                val word = intent.getStringExtra("word")
                                events?.success(mapOf("type" to "text", "text" to text, "word" to word))
                            }
                        }
                    }
                    val filter = IntentFilter().apply {
                        addAction(WebFilterAccessibilityService.ACTION_URL_DETECTED)
                        addAction(WebFilterAccessibilityService.ACTION_TEXT_DETECTED)
                    }
                    registerReceiver(receiver, filter)
                }

                override fun onCancel(arguments: Any?) {
                    receiver?.let { unregisterReceiver(it) }
                    receiver = null
                }
            }
        )
    }

    // ── Geofencing Helpers ──

    private fun setupNativeGeofences(zones: List<Map<String, Any>>) {
        // First remove existing geofences, then add new ones
        geofencingClient.removeGeofences(getGeofencePendingIntent())
            .addOnCompleteListener {
                val geofenceList = mutableListOf<Geofence>()

                for (zone in zones) {
                    val name = zone["name"] as? String ?: continue
                    val lat = (zone["latitude"] as? Number)?.toDouble() ?: continue
                    val lng = (zone["longitude"] as? Number)?.toDouble() ?: continue
                    val radius = (zone["radius"] as? Number)?.toFloat() ?: 200f

                    geofenceList.add(
                        Geofence.Builder()
                            .setRequestId(name) // Zone name as ID
                            .setCircularRegion(lat, lng, radius)
                            .setExpirationDuration(Geofence.NEVER_EXPIRE)
                            .setTransitionTypes(
                                Geofence.GEOFENCE_TRANSITION_EXIT or
                                Geofence.GEOFENCE_TRANSITION_ENTER
                            )
                            .build()
                    )
                }

                if (geofenceList.isEmpty()) {
                    Log.w("Geofence", "No valid zones to register")
                    return@addOnCompleteListener
                }

                val request = GeofencingRequest.Builder()
                    .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_EXIT)
                    .addGeofences(geofenceList)
                    .build()

                try {
                    geofencingClient.addGeofences(request, getGeofencePendingIntent())
                        .addOnSuccessListener {
                            Log.i("Geofence", "Successfully registered ${geofenceList.size} geofences")
                        }
                        .addOnFailureListener { e ->
                            Log.e("Geofence", "Failed to add geofences: ${e.message}")
                        }
                } catch (e: SecurityException) {
                    Log.e("Geofence", "Missing location permission: ${e.message}")
                }
            }
    }

    private fun getGeofencePendingIntent(): PendingIntent {
        val intent = Intent(this, GeofenceBroadcastReceiver::class.java)
        return PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }

    // ── Lock Service Helpers ──

    private fun checkOverlayPermissionAndStart(isExamMode: Boolean, allowedApps: Array<String>, reason: String? = null) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            pendingIsExamMode = isExamMode
            pendingAllowedApps = allowedApps
            pendingLockReason = reason
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, OVERLAY_PERMISSION_REQ_CODE)
        } else {
            startLockService(isExamMode, allowedApps, reason)
        }
    }

    private fun startLockService(isExamMode: Boolean, allowedApps: Array<String>, reason: String? = null) {
        val intent = Intent(this, LockService::class.java).apply {
            action = LockService.ACTION_START_LOCK
            putExtra("isExamMode", isExamMode)
            putExtra("allowedApps", allowedApps)
            if (reason != null) {
                putExtra("reason", reason)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLockService() {
        val intent = Intent(this, LockService::class.java)
        stopService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == OVERLAY_PERMISSION_REQ_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    startLockService(pendingIsExamMode, pendingAllowedApps, pendingLockReason)
                }
            }
        } else if (requestCode == VPN_REQ_CODE) {
            if (resultCode == RESULT_OK) {
                startFamilyGuardVpn(pendingBlockedApps)
            }
        }
    }

    private fun startFamilyGuardVpn(apps: List<String>) {
        val intent = Intent(this, FamilyGuardVpnService::class.java)
        intent.action = FamilyGuardVpnService.ACTION_START_VPN
        intent.putExtra(FamilyGuardVpnService.EXTRA_BLOCKED_APPS, apps.toTypedArray())
        startService(intent)
    }
}
