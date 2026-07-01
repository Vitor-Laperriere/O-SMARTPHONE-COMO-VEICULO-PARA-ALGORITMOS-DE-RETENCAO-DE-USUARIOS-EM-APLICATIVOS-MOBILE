package com.example.foco_tela

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val usageStatsChannel = "com.foco_tela/usage_stats"
    private val appIdentityChannel = "com.foco_tela/app_identity"
    private val usageAccessChannel = "com.foco_tela/usage_access"
    private val assistiveSettingsChannel = "com.foco_tela/assistive_settings"
    private val notificationChannel = "com.foco_tela/notifications"
    private val notificationContentAuthRequestCode = 4207
    private var pendingNotificationContentAuth: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == notificationContentAuthRequestCode) {
            pendingNotificationContentAuth?.success(
                NotificationChannelContract.contentAuthentication(
                    resultCode == Activity.RESULT_OK
                )
            )
            pendingNotificationContentAuth = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val usageAccessAdapter = AndroidUsageAccessAdapter(this)
        val usageEventsAdapter = AndroidUsageEventsAdapter(this)
        val appIdentityAdapter = AndroidAppIdentityAdapter(this)
        val assistiveSettingsAdapter = AndroidAssistiveSettingsAdapter(this)
        val notificationAdapter = AndroidNotificationAdapter(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNotificationAccessState" -> {
                        result.success(
                            NotificationChannelContract.accessState(
                                if (notificationAdapter.hasAccess()) "granted" else "denied"
                            )
                        )
                    }
                    "openNotificationListenerSettings" -> {
                        try {
                            notificationAdapter.openSettings()
                            result.success(NotificationChannelContract.settingsOpened())
                        } catch (error: Exception) {
                            result.error(
                                "SETTINGS_UNAVAILABLE",
                                "Notification listener settings are unavailable",
                                error.message
                            )
                        }
                    }
                    "getDailyNotificationCounts" -> {
                        val startTime = call.argument<Long>("startTimeMillis")
                        val endTime = call.argument<Long>("endTimeMillis")
                        if (startTime == null || endTime == null || startTime >= endTime) {
                            result.error(
                                "INVALID_ARGUMENTS",
                                "A valid interval start and end are required",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        if (!notificationAdapter.hasAccess()) {
                            result.success(NotificationChannelContract.counts(emptyList()))
                            return@setMethodCallHandler
                        }
                        result.success(
                            NotificationChannelContract.counts(
                                notificationAdapter.dailyCounts(startTime, endTime)
                            )
                        )
                    }
                    "getLastNotificationObservation" -> {
                        result.success(
                            NotificationChannelContract.lastObservation(
                                notificationAdapter.lastObservation()
                            )
                        )
                    }
                    "getContentSettings" -> result.success(
                        NotificationChannelContract.contentSettings(
                            notificationAdapter.contentSettings()
                        )
                    )
                    "setContentModeEnabled" -> {
                        notificationAdapter.setContentModeEnabled(
                            call.argument<Boolean>("enabled") == true
                        )
                        result.success(NotificationChannelContract.ok())
                    }
                    "authorizeContentPackage" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "packageName is required", null)
                            return@setMethodCallHandler
                        }
                        notificationAdapter.authorizeContentPackage(packageName)
                        result.success(NotificationChannelContract.ok())
                    }
                    "authorizeContentPackages" -> {
                        val packageNames = call.argument<List<String>>("packageNames")
                        if (packageNames == null) {
                            result.error("INVALID_ARGUMENTS", "packageNames is required", null)
                            return@setMethodCallHandler
                        }
                        notificationAdapter.authorizeContentPackages(packageNames)
                        result.success(NotificationChannelContract.ok())
                    }
                    "revokeContentPackage" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "packageName is required", null)
                            return@setMethodCallHandler
                        }
                        notificationAdapter.revokeContentPackage(packageName)
                        result.success(NotificationChannelContract.ok())
                    }
                    "authenticateContentViewing" -> authenticateNotificationContentViewing(result)
                    "getStoredContent" -> {
                        val startTime = call.argument<Long>("startTimeMillis")
                        val endTime = call.argument<Long>("endTimeMillis")
                        if (startTime == null || endTime == null || startTime >= endTime) {
                            result.error(
                                "INVALID_ARGUMENTS",
                                "A valid interval start and end are required",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        result.success(
                            NotificationChannelContract.records(
                                notificationAdapter.storedContent(
                                    startTime,
                                    endTime,
                                    call.argument<String>("packageName")
                                )
                            )
                        )
                    }
                    "clearStoredContent" -> {
                        notificationAdapter.clearStoredContent()
                        result.success(NotificationChannelContract.ok())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, assistiveSettingsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAppUsageSettings" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error(
                                "INVALID_ARGUMENTS",
                                "packageName is required",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            val destination = assistiveSettingsAdapter.openSettings(packageName)
                            result.success(
                                AssistiveSettingsChannelContract.settingsOpened(destination)
                            )
                        } catch (error: Exception) {
                            result.error(
                                "SETTINGS_UNAVAILABLE",
                                "App settings are unavailable",
                                error.message
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appIdentityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledAppIdentities" -> {
                        val packageNames = call.argument<List<String>>("packageNames")
                        if (packageNames == null) {
                            result.error(
                                "INVALID_ARGUMENTS",
                                "packageNames is required",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        result.success(appIdentityAdapter.resolveMany(packageNames))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, usageAccessChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUsageAccessState" -> {
                        result.success(
                            UsageAccessChannelContract.accessState(
                                usageAccessAdapter.hasAccess()
                            )
                        )
                    }
                    "openUsageAccessSettings" -> {
                        try {
                            usageAccessAdapter.openSettings()
                            result.success(UsageAccessChannelContract.settingsOpened())
                        } catch (error: Exception) {
                            result.error(
                                "SETTINGS_UNAVAILABLE",
                                "Usage access settings are unavailable",
                                error.message
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, usageStatsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUsageEventsForInterval" -> {
                        if (!usageAccessAdapter.hasAccess()) {
                            result.error(
                                "NO_PERMISSION",
                                "Usage access permission not granted",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val startTime = call.argument<Long>("startTimeMillis")
                        val endTime = call.argument<Long>("endTimeMillis")
                        if (startTime == null || endTime == null || startTime >= endTime) {
                            result.error(
                                "INVALID_ARGUMENTS",
                                "A valid interval start and end are required",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        result.success(
                            usageEventsAdapter.queryInterval(startTime, endTime)
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun authenticateNotificationContentViewing(result: MethodChannel.Result) {
        if (pendingNotificationContentAuth != null) {
            result.error(
                "AUTH_IN_PROGRESS",
                "Notification content authentication is already in progress",
                null
            )
            return
        }

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!keyguardManager.isDeviceSecure) {
            result.error(
                "AUTH_UNAVAILABLE",
                "Device credential is required to view notification content",
                null
            )
            return
        }

        val intent = keyguardManager.createConfirmDeviceCredentialIntent(
            "Consultar conteúdo de notificações",
            "Confirme sua identidade para visualizar títulos e textos armazenados localmente."
        )
        if (intent == null) {
            result.error(
                "AUTH_UNAVAILABLE",
                "Device credential confirmation is unavailable",
                null
            )
            return
        }

        pendingNotificationContentAuth = result
        startActivityForResult(intent, notificationContentAuthRequestCode)
    }
}
