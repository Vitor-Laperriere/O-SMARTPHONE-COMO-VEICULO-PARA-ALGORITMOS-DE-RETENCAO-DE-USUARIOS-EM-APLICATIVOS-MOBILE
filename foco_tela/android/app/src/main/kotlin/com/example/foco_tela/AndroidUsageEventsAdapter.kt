package com.example.foco_tela

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager

internal const val USAGE_EVENTS_CONTRACT_VERSION = 2

internal object AndroidUsageEventTypeNormalizer {
    @Suppress("DEPRECATION")
    fun kindFor(eventType: Int): String? = when (eventType) {
        // MOVE_TO_* (API 21) and ACTIVITY_* (API 29) share these values.
        UsageEvents.Event.MOVE_TO_FOREGROUND -> "foreground"
        UsageEvents.Event.MOVE_TO_BACKGROUND -> "background"
        UsageEvents.Event.KEYGUARD_HIDDEN -> "unlock"
        UsageEvents.Event.SCREEN_INTERACTIVE -> "screenInteractive"
        UsageEvents.Event.SCREEN_NON_INTERACTIVE -> "screenNonInteractive"
        else -> null
    }
}

internal class AndroidUsageEventsAdapter(
    context: Context,
) {
    private val usageStatsManager =
        context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    private val packageManager = context.packageManager

    fun queryInterval(
        startTimeMillis: Long,
        endTimeMillis: Long,
    ): Map<String, Any> {
        require(startTimeMillis < endTimeMillis) {
            "Usage event interval must have a positive duration"
        }

        val usageEvents = usageStatsManager.queryEvents(
            startTimeMillis,
            endTimeMillis,
        )
        val event = UsageEvents.Event()
        val packageNameToLabel = mutableMapOf<String, String>()
        val normalizedEvents = mutableListOf<Map<String, Any?>>()

        while (usageEvents.getNextEvent(event)) {
            normalize(event, packageNameToLabel)?.let(normalizedEvents::add)
        }

        return mapOf(
            "contractVersion" to USAGE_EVENTS_CONTRACT_VERSION,
            "intervalStartMillis" to startTimeMillis,
            "intervalEndMillis" to endTimeMillis,
            "events" to normalizedEvents,
        )
    }

    private fun normalize(
        event: UsageEvents.Event,
        packageNameToLabel: MutableMap<String, String>,
    ): Map<String, Any?>? {
        val kind = AndroidUsageEventTypeNormalizer.kindFor(event.eventType)
            ?: return null
        val packageName = event.packageName?.takeUnless { it == "android" }
        val appName = packageName?.let {
            resolveAppLabel(it, packageNameToLabel)
        }

        return buildMap {
            put("timestampMillis", event.timeStamp)
            put("kind", kind)
            packageName?.let { put("packageName", it) }
            appName?.let { put("appName", it) }
        }
    }

    private fun resolveAppLabel(
        packageName: String,
        cache: MutableMap<String, String>,
    ): String {
        cache[packageName]?.let { return it }

        val label = try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
        cache[packageName] = label
        return label
    }
}
