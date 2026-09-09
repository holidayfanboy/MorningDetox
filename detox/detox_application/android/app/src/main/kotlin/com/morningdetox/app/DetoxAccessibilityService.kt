package com.morningdetox.app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * Pulls the user back to MainActivity (and from there, Dart's own
 * resume-lifecycle guard shows the Detox lock screen again) if they switch
 * away from the app while a detox session is active.
 *
 * Reads the same `shared_preferences` file Dart writes to directly, rather
 * than going through a MethodChannel, so this works even if the Flutter
 * engine isn't currently running. IMPORTANT: the `shared_preferences`
 * plugin prefixes every key with "flutter." and stores Dart `int` values
 * via `putLong`, not `putInt` -- see DetoxSessionService in the Dart code
 * for the key names this must match exactly.
 */
class DetoxAccessibilityService : AccessibilityService() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_ACTIVE = "flutter.detox_active"
        private const val KEY_END_AT_MILLIS = "flutter.detox_end_at_millis"
        private const val KEY_ALLOWED_PACKAGES = "flutter.allowed_packages"
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val eventPackage = event.packageName?.toString() ?: return
        if (eventPackage == packageName) return

        if (!isDetoxSessionActive()) return
        if (isPackageAllowed(eventPackage)) return

        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        startActivity(intent)
    }

    private fun isDetoxSessionActive(): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ACTIVE, false)) return false
        val endAt = prefs.getLong(KEY_END_AT_MILLIS, -1L)
        if (endAt < 0) return false
        return endAt > System.currentTimeMillis()
    }

    // The allow-list is written by AllowedAppsService as a plain JSON
    // array string (e.g. `["com.a","com.b"]`), not a `StringList` --
    // deliberately, since the `shared_preferences` plugin's on-disk
    // encoding for a `StringList` is an implementation detail not worth
    // relying on here. Re-read and re-parsed on every event rather than
    // cached: events are infrequent and the list is small.
    private fun isPackageAllowed(pkg: String): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_ALLOWED_PACKAGES, null) ?: return false
        return try {
            val allowed = org.json.JSONArray(json)
            (0 until allowed.length()).any { allowed.getString(it) == pkg }
        } catch (e: Exception) {
            false
        }
    }

    override fun onInterrupt() {
        // Nothing to clean up.
    }
}
