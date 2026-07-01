package com.example.foco_tela

import android.app.Notification
import android.content.Context
import android.service.notification.StatusBarNotification
import android.util.Base64
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.MessageDigest
import java.util.Calendar
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties

internal object AndroidNotificationStore {
    private const val COUNTS_PREFS = "foco_notification_counts_v2"
    private const val DEDUPE_PREFS = "foco_notification_dedupe_v2"
    private const val SETTINGS_PREFS = "foco_notification_settings_v1"
    private const val CONTENT_PREFS = "foco_notification_content_v1"
    private const val CONTENT_ENABLED = "content_enabled"
    private const val AUTHORIZED_PACKAGES = "authorized_packages"
    private const val LAST_OBSERVED_AT = "last_observed_at"
    private const val LAST_OBSERVED_PACKAGE = "last_observed_package"
    private const val LAST_OBSERVED_DAILY_COUNT = "last_observed_daily_count"
    private const val KEY_ALIAS = "foco_tela_notification_content_v1"
    private const val MAX_TEXT_LENGTH = 240
    private const val RETENTION_MILLIS = 7L * 24L * 60L * 60L * 1000L

    fun recordPosted(context: Context, sbn: StatusBarNotification) {
        val packageName = sbn.packageName ?: return
        if (shouldIgnoreForCount(sbn)) return
        val postedAt = sbn.postTime
        val dayStart = dayStartMillis(postedAt)
        pruneDedupeKeys(context, postedAt)
        val notificationKey = notificationKeyFor(sbn)
        val dedupeKey = "$dayStart|$packageName|${sha256(notificationKey)}"
        val dedupe = context.getSharedPreferences(DEDUPE_PREFS, Context.MODE_PRIVATE)
        if (dedupe.contains(dedupeKey)) return

        val counts = context.getSharedPreferences(COUNTS_PREFS, Context.MODE_PRIVATE)
        val countKey = "$dayStart|$packageName"
        val dailyCount = counts.getInt(countKey, 0) + 1
        dedupe.edit().putLong(dedupeKey, postedAt).apply()
        counts.edit()
            .putInt(countKey, dailyCount)
            .putLong(LAST_OBSERVED_AT, postedAt)
            .putString(LAST_OBSERVED_PACKAGE, packageName)
            .putInt(LAST_OBSERVED_DAILY_COUNT, dailyCount)
            .apply()

        if (!canPersistContent(context, packageName)) return
        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString().orEmpty()
            .take(MAX_TEXT_LENGTH)
        val text = (
            extras.getCharSequence("android.bigText")
                ?: extras.getCharSequence("android.text")
        )?.toString().orEmpty().take(MAX_TEXT_LENGTH)
        if (title.isBlank() && text.isBlank()) return

        val payload = JSONObject()
            .put("packageName", packageName)
            .put("postedAtMillis", postedAt)
            .put("title", title)
            .put("text", text)
            .put("expiresAtMillis", postedAt + RETENTION_MILLIS)
            .toString()
        val encrypted = NotificationContentCipher.encrypt(payload)
        context.getSharedPreferences(CONTENT_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString("$postedAt|$packageName", encrypted)
            .apply()
        pruneContent(context, System.currentTimeMillis())
    }

    fun dailyCounts(
        context: Context,
        startTimeMillis: Long,
        endTimeMillis: Long
    ): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(COUNTS_PREFS, Context.MODE_PRIVATE)
        return prefs.all.mapNotNull { (key, value) ->
            val parts = key.split("|", limit = 2)
            if (parts.size != 2) return@mapNotNull null
            val dayStart = parts[0].toLongOrNull() ?: return@mapNotNull null
            if (dayStart < startTimeMillis || dayStart >= endTimeMillis) {
                return@mapNotNull null
            }
            mapOf(
                "dayStartMillis" to dayStart,
                "packageName" to parts[1],
                "count" to (value as? Int ?: 0)
            )
        }.sortedWith(compareBy({ it["dayStartMillis"] as Long }, { it["packageName"] as String }))
    }

    fun lastObservation(context: Context): Map<String, Any>? {
        val prefs = context.getSharedPreferences(COUNTS_PREFS, Context.MODE_PRIVATE)
        val observedAt = prefs.getLong(LAST_OBSERVED_AT, -1L)
        if (observedAt < 0L) return null
        val packageName = prefs.getString(LAST_OBSERVED_PACKAGE, null) ?: return null
        val count = prefs.getInt(LAST_OBSERVED_DAILY_COUNT, 0)
        if (count <= 0) return null
        return mapOf(
            "observedAtMillis" to observedAt,
            "packageName" to packageName,
            "count" to count
        )
    }

    fun contentSettings(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(SETTINGS_PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "enabled" to prefs.getBoolean(CONTENT_ENABLED, false),
            "authorizedPackages" to authorizedPackages(context).toList().sorted()
        )
    }

    fun setContentModeEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(SETTINGS_PREFS, Context.MODE_PRIVATE)
        if (!enabled) {
            prefs.edit()
                .putBoolean(CONTENT_ENABLED, false)
                .putStringSet(AUTHORIZED_PACKAGES, emptySet())
                .apply()
            clearStoredContent(context)
            NotificationContentCipher.deleteKey()
            return
        }
        prefs.edit().putBoolean(CONTENT_ENABLED, true).apply()
    }

    fun authorizeContentPackage(context: Context, packageName: String) {
        val packages = authorizedPackages(context).toMutableSet()
        packages += packageName
        context.getSharedPreferences(SETTINGS_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(AUTHORIZED_PACKAGES, packages)
            .apply()
    }

    fun authorizeContentPackages(context: Context, packageNames: List<String>) {
        val normalized = packageNames
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toSet()
        if (normalized.isEmpty()) return
        val packages = authorizedPackages(context).toMutableSet()
        packages += normalized
        context.getSharedPreferences(SETTINGS_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(AUTHORIZED_PACKAGES, packages)
            .apply()
    }

    fun revokeContentPackage(context: Context, packageName: String) {
        val packages = authorizedPackages(context).toMutableSet()
        packages -= packageName
        val content = context.getSharedPreferences(CONTENT_PREFS, Context.MODE_PRIVATE)
        val editor = content.edit()
        for (key in content.all.keys) {
            if (key.endsWith("|$packageName")) editor.remove(key)
        }
        editor.apply()
        context.getSharedPreferences(SETTINGS_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(AUTHORIZED_PACKAGES, packages)
            .apply()
    }

    fun storedContent(
        context: Context,
        startTimeMillis: Long,
        endTimeMillis: Long,
        packageName: String?
    ): List<Map<String, Any>> {
        pruneContent(context, System.currentTimeMillis())
        if (!contentEnabled(context)) return emptyList()
        val prefs = context.getSharedPreferences(CONTENT_PREFS, Context.MODE_PRIVATE)
        return prefs.all.values.mapNotNull { value ->
            val encrypted = value as? String ?: return@mapNotNull null
            val decoded = JSONObject(NotificationContentCipher.decrypt(encrypted))
            val postedAt = decoded.getLong("postedAtMillis")
            val decodedPackage = decoded.getString("packageName")
            if (postedAt < startTimeMillis || postedAt >= endTimeMillis) {
                return@mapNotNull null
            }
            if (packageName != null && decodedPackage != packageName) {
                return@mapNotNull null
            }
            mapOf(
                "packageName" to decodedPackage,
                "postedAtMillis" to postedAt,
                "title" to decoded.getString("title"),
                "text" to decoded.getString("text"),
                "expiresAtMillis" to decoded.getLong("expiresAtMillis")
            )
        }.sortedBy { it["postedAtMillis"] as Long }
    }

    fun clearStoredContent(context: Context) {
        context.getSharedPreferences(CONTENT_PREFS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }

    private fun canPersistContent(context: Context, packageName: String): Boolean =
        contentEnabled(context) && authorizedPackages(context).contains(packageName)

    private fun contentEnabled(context: Context): Boolean =
        context.getSharedPreferences(SETTINGS_PREFS, Context.MODE_PRIVATE)
            .getBoolean(CONTENT_ENABLED, false)

    private fun authorizedPackages(context: Context): Set<String> =
        context.getSharedPreferences(SETTINGS_PREFS, Context.MODE_PRIVATE)
            .getStringSet(AUTHORIZED_PACKAGES, emptySet()) ?: emptySet()

    private fun pruneContent(context: Context, nowMillis: Long) {
        val prefs = context.getSharedPreferences(CONTENT_PREFS, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        var changed = false
        for ((key, value) in prefs.all) {
            val encrypted = value as? String ?: continue
            val expiresAt = runCatching {
                JSONObject(NotificationContentCipher.decrypt(encrypted))
                    .getLong("expiresAtMillis")
            }.getOrNull() ?: 0L
            if (expiresAt <= nowMillis) {
                editor.remove(key)
                changed = true
            }
        }
        if (changed) editor.apply()
    }

    private fun pruneDedupeKeys(context: Context, nowMillis: Long) {
        val oldestAllowed = nowMillis - RETENTION_MILLIS
        val prefs = context.getSharedPreferences(DEDUPE_PREFS, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        var changed = false
        for ((key, value) in prefs.all) {
            val observedAt = value as? Long ?: 0L
            if (observedAt < oldestAllowed) {
                editor.remove(key)
                changed = true
            }
        }
        if (changed) editor.apply()
    }

    private fun shouldIgnoreForCount(sbn: StatusBarNotification): Boolean {
        val flags = sbn.notification.flags
        return flags and Notification.FLAG_ONGOING_EVENT != 0 ||
            flags and Notification.FLAG_FOREGROUND_SERVICE != 0 ||
            flags and Notification.FLAG_GROUP_SUMMARY != 0 ||
            flags and Notification.FLAG_NO_CLEAR != 0
    }

    private fun notificationKeyFor(sbn: StatusBarNotification): String =
        sbn.key ?: "${sbn.packageName}|${sbn.id}|${sbn.tag.orEmpty()}|${sbn.postTime}"

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(StandardCharsets.UTF_8))
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }

    private fun dayStartMillis(timestampMillis: Long): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = timestampMillis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    private object NotificationContentCipher {
        fun encrypt(plainText: String): String {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, key())
            val cipherText = cipher.doFinal(plainText.toByteArray(StandardCharsets.UTF_8))
            val payload = cipher.iv + cipherText
            return Base64.encodeToString(payload, Base64.NO_WRAP)
        }

        fun decrypt(encodedPayload: String): String {
            val payload = Base64.decode(encodedPayload, Base64.NO_WRAP)
            val iv = payload.copyOfRange(0, 12)
            val cipherText = payload.copyOfRange(12, payload.size)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
            return String(cipher.doFinal(cipherText), StandardCharsets.UTF_8)
        }

        fun deleteKey() {
            val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            if (keyStore.containsAlias(KEY_ALIAS)) keyStore.deleteEntry(KEY_ALIAS)
        }

        private fun key(): SecretKey {
            val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
            val existing = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
            if (existing != null) return existing.secretKey
            val generator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                "AndroidKeyStore"
            )
            generator.init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setRandomizedEncryptionRequired(true)
                    .build()
            )
            return generator.generateKey()
        }
    }
}
