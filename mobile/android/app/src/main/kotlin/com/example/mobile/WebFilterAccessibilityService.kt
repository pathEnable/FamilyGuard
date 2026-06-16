package com.example.mobile

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.content.Intent
import android.util.Log

class WebFilterAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "WebFilter"
        const val ACTION_URL_DETECTED = "com.familyguard.URL_DETECTED"
        const val ACTION_TEXT_DETECTED = "com.familyguard.TEXT_DETECTED"
    }

    // Mots-clés sensibles (à enrichir ou synchroniser avec le backend)
    private val badWords = listOf("porn", "sex", "xxx", "suicide", "drogue")

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            val rootNode = rootInActiveWindow ?: return
            
            // Cherche la barre d'adresse de Chrome
            val urlNodes = rootNode.findAccessibilityNodeInfosByViewId("com.android.chrome:id/url_bar")
            if (urlNodes != null && urlNodes.isNotEmpty()) {
                val urlBar = urlNodes[0]
                val url = urlBar.text?.toString()
                if (url != null && url.isNotEmpty()) {
                    Log.d(TAG, "URL détectée: $url")
                    val intent = Intent(ACTION_URL_DETECTED)
                    intent.putExtra("url", url)
                    sendBroadcast(intent)
                }
            }

            // Vérification de contenu textuel basique (recherches Google, etc)
            checkNodeTextForBadWords(rootNode)
        }
    }

    private fun checkNodeTextForBadWords(node: AccessibilityNodeInfo?) {
        if (node == null) return
        val text = node.text?.toString()?.lowercase()
        if (text != null) {
            for (word in badWords) {
                if (text.contains(word)) {
                    Log.d(TAG, "Mot sensible détecté: $word")
                    val intent = Intent(ACTION_TEXT_DETECTED)
                    intent.putExtra("text", text)
                    intent.putExtra("word", word)
                    sendBroadcast(intent)
                    
                    // Optionnel : Forcer un retour ou lancer le LockService ici.
                    // performGlobalAction(GLOBAL_ACTION_HOME)
                    break
                }
            }
        }

        for (i in 0 until node.childCount) {
            checkNodeTextForBadWords(node.getChild(i))
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Service interrompu")
    }
}
