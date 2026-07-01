package com.example.foco_tela

import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.provider.Settings

internal const val USAGE_ACCESS_CONTRACT_VERSION = 1

internal class AndroidUsageAccessAdapter(
    private val activity: Activity
) {
    fun hasAccess(): Boolean {
        val appOps = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            activity.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun openSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        if (intent.resolveActivity(activity.packageManager) == null) {
            throw IllegalStateException("Usage access settings are unavailable")
        }
        activity.startActivity(intent)
    }
}

internal object UsageAccessChannelContract {
    fun accessState(granted: Boolean): Map<String, Any> = mapOf(
        "contractVersion" to USAGE_ACCESS_CONTRACT_VERSION,
        "status" to if (granted) "granted" else "denied"
    )

    fun settingsOpened(): Map<String, Any> = mapOf(
        "contractVersion" to USAGE_ACCESS_CONTRACT_VERSION,
        "opened" to true
    )
}

