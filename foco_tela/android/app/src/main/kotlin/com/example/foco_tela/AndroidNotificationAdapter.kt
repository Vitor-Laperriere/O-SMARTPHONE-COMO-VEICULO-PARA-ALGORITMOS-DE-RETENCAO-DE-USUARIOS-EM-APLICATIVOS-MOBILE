package com.example.foco_tela

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils

internal const val NOTIFICATION_CONTRACT_VERSION = 1

internal interface NotificationSettingsIntentStarter {
    fun openNotificationListenerSettings(): Boolean
}

internal class AndroidNotificationAdapter(
    private val context: Context,
    private val intentStarter: NotificationSettingsIntentStarter
) {
    constructor(activity: Activity) : this(activity, AndroidNotificationSettingsIntentStarter(activity))

    fun hasAccess(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val expectedPrefix = "${context.packageName}/"
        return TextUtils.split(enabledListeners, ":").any { listener ->
            listener.startsWith(expectedPrefix)
        }
    }

    fun openSettings() {
        if (!intentStarter.openNotificationListenerSettings()) {
            throw IllegalStateException("Notification listener settings are unavailable")
        }
    }

    fun dailyCounts(startTimeMillis: Long, endTimeMillis: Long): List<Map<String, Any>> =
        AndroidNotificationStore.dailyCounts(context, startTimeMillis, endTimeMillis)

    fun lastObservation(): Map<String, Any>? =
        AndroidNotificationStore.lastObservation(context)

    fun contentSettings(): Map<String, Any> =
        AndroidNotificationStore.contentSettings(context)

    fun setContentModeEnabled(enabled: Boolean) {
        AndroidNotificationStore.setContentModeEnabled(context, enabled)
    }

    fun authorizeContentPackage(packageName: String) {
        AndroidNotificationStore.authorizeContentPackage(context, packageName)
    }

    fun authorizeContentPackages(packageNames: List<String>) {
        AndroidNotificationStore.authorizeContentPackages(context, packageNames)
    }

    fun revokeContentPackage(packageName: String) {
        AndroidNotificationStore.revokeContentPackage(context, packageName)
    }

    fun storedContent(
        startTimeMillis: Long,
        endTimeMillis: Long,
        packageName: String?
    ): List<Map<String, Any>> =
        AndroidNotificationStore.storedContent(
            context,
            startTimeMillis,
            endTimeMillis,
            packageName
        )

    fun clearStoredContent() {
        AndroidNotificationStore.clearStoredContent(context)
    }
}

private class AndroidNotificationSettingsIntentStarter(
    private val activity: Activity
) : NotificationSettingsIntentStarter {
    override fun openNotificationListenerSettings(): Boolean {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
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

internal object NotificationChannelContract {
    fun accessState(status: String): Map<String, Any> = mapOf(
        "contractVersion" to NOTIFICATION_CONTRACT_VERSION,
        "status" to status
    )

    fun settingsOpened(): Map<String, Any> = mapOf(
        "contractVersion" to NOTIFICATION_CONTRACT_VERSION,
        "opened" to true
    )

    fun counts(counts: List<Map<String, Any>>): Map<String, Any> = mapOf(
        "contractVersion" to NOTIFICATION_CONTRACT_VERSION,
        "counts" to counts
    )

    fun lastObservation(observation: Map<String, Any>?): Map<String, Any?> = mapOf(
        "contractVersion" to NOTIFICATION_CONTRACT_VERSION,
        "observation" to observation
    )

    fun contentSettings(settings: Map<String, Any>): Map<String, Any> =
        mapOf("contractVersion" to NOTIFICATION_CONTRACT_VERSION) + settings

    fun records(records: List<Map<String, Any>>): Map<String, Any> = mapOf(
        "contractVersion" to NOTIFICATION_CONTRACT_VERSION,
        "records" to records
    )

    fun contentAuthentication(authenticated: Boolean): Map<String, Any> = mapOf(
        "contractVersion" to NOTIFICATION_CONTRACT_VERSION,
        "authenticated" to authenticated
    )

    fun ok(): Map<String, Any> = mapOf(
        "contractVersion" to NOTIFICATION_CONTRACT_VERSION,
        "ok" to true
    )
}
