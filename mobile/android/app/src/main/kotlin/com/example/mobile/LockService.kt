package com.example.mobile

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.app.usage.UsageStatsManager
import android.os.Handler
import android.os.Looper

class LockService : Service() {

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    
    private var isExamMode: Boolean = false
    private var allowedApps: Array<String> = emptyArray()
    
    private val handler = Handler(Looper.getMainLooper())
    private val checkForegroundRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, 2000) // Check every 2 seconds
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        showLockScreen()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // If the PIN was passed via intent, store it for offline verification
        intent?.getStringExtra("pin")?.let { pin ->
            if (pin.isNotEmpty()) {
                getSharedPreferences("familyguard_prefs", Context.MODE_PRIVATE)
                    .edit()
                    .putString("lock_pin", pin)
                    .apply()
            }
        }
        
        isExamMode = intent?.getBooleanExtra("isExamMode", false) ?: false
        allowedApps = intent?.getStringArrayExtra("allowedApps") ?: emptyArray()
        
        if (isExamMode && allowedApps.isNotEmpty()) {
            handler.post(checkForegroundRunnable)
        }
        
        return START_STICKY // Restart if killed by the system
    }

    private fun checkForegroundApp() {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 1000 * 10, time)
        
        var topPackageName: String? = null
        if (stats != null) {
            var lastUsedApp: android.app.usage.UsageStats? = null
            for (usageStats in stats) {
                if (lastUsedApp == null || lastUsedApp.lastTimeUsed < usageStats.lastTimeUsed) {
                    lastUsedApp = usageStats
                }
            }
            topPackageName = lastUsedApp?.packageName
        }
        
        // If the top app is in the allowed list, remove the lock screen temporarily.
        // Otherwise, show the lock screen.
        // We also allow our own package so the user can access the FamilyGuard app.
        if (topPackageName != null && (allowedApps.contains(topPackageName) || topPackageName == packageName)) {
            removeLockScreen()
        } else {
            showLockScreen()
        }
    }

    private fun showLockScreen() {
        if (overlayView != null) return

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            // Allow the EditText to be focusable for PIN input
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        )
        layoutParams.gravity = Gravity.CENTER

        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        overlayView = inflater.inflate(R.layout.lock_screen, null)

        // Wire up the PIN unlock logic
        val pinInput = overlayView?.findViewById<EditText>(R.id.pinInput)
        val unlockButton = overlayView?.findViewById<Button>(R.id.unlockButton)
        val pinError = overlayView?.findViewById<TextView>(R.id.pinError)

        unlockButton?.setOnClickListener {
            val enteredPin = pinInput?.text?.toString() ?: ""
            val storedPin = getStoredPin()

            if (storedPin.isEmpty()) {
                // No PIN configured — any entry unlocks
                removeLockScreen()
                stopSelf()
            } else if (enteredPin == storedPin) {
                // PIN matches — unlock
                removeLockScreen()
                stopSelf()
            } else {
                // Wrong PIN
                pinError?.text = "Code PIN incorrect"
                pinError?.visibility = View.VISIBLE
                pinInput?.text?.clear()
            }
        }

        windowManager.addView(overlayView, layoutParams)
    }

    private fun getStoredPin(): String {
        val prefs: SharedPreferences =
            getSharedPreferences("familyguard_prefs", Context.MODE_PRIVATE)
        return prefs.getString("lock_pin", "") ?: ""
    }

    private fun removeLockScreen() {
        if (overlayView != null) {
            windowManager.removeView(overlayView)
            overlayView = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(checkForegroundRunnable)
        removeLockScreen()
    }
}
