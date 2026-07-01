package com.example.foco_tela

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.Settings

internal const val ASSISTIVE_SETTINGS_CONTRACT_VERSION = 1

internal enum class AssistiveSettingsDestination(val wireValue: String) {
    APP_USAGE_SETTINGS("appUsageSettings"),
    APPLICATION_DETAILS("applicationDetails")
}

internal interface AssistiveSettingsIntentStarter {
    fun openAppUsageSettings(packageName: String): Boolean
    fun openApplicationDetails(packageName: String): Boolean
}

internal class AndroidAssistiveSettingsAdapter(
    private val intentStarter: AssistiveSettingsIntentStarter
) {
    constructor(activity: Activity) : this(AndroidAssistiveSettingsIntentStarter(activity))

    fun openSettings(packageName: String): AssistiveSettingsDestination {
        require(packageName.isNotBlank()) { "packageName is required" }

        if (intentStarter.openAppUsageSettings(packageName)) {
            return AssistiveSettingsDestination.APP_USAGE_SETTINGS
        }
        if (intentStarter.openApplicationDetails(packageName)) {
            return AssistiveSettingsDestination.APPLICATION_DETAILS
        }
        throw IllegalStateException("App settings are unavailable")
    }
}

private class AndroidAssistiveSettingsIntentStarter(
    private val activity: Activity
) : AssistiveSettingsIntentStarter {
    override fun openAppUsageSettings(packageName: String): Boolean = tryStart(
        Intent(Settings.ACTION_APP_USAGE_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
    )

    override fun openApplicationDetails(packageName: String): Boolean = tryStart(
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
    )

    private fun tryStart(intent: Intent): Boolean {
        if (intent.resolveActivity(activity.packageManager) == null) return false
        return try {
            activity.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}

internal object AssistiveSettingsChannelContract {
    fun settingsOpened(destination: AssistiveSettingsDestination): Map<String, Any> = mapOf(
        "contractVersion" to ASSISTIVE_SETTINGS_CONTRACT_VERSION,
        "opened" to true,
        "destination" to destination.wireValue
    )
}
