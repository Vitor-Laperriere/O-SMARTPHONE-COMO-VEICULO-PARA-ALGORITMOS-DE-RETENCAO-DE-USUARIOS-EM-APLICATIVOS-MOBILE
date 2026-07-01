package com.example.foco_tela

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

internal const val APP_IDENTITY_CONTRACT_VERSION = 1

internal class AndroidAppIdentityAdapter(
    context: Context,
) {
    private val packageManager = context.packageManager

    fun resolveMany(packageNames: List<String>): Map<String, Any?> {
        val normalizedPackageNames = packageNames.mapNotNull { it.trim().takeIf { trimmed -> trimmed.isNotEmpty() } }
        val resolvedApps = normalizedPackageNames.map { resolveOne(it) }
        return mapOf(
            "contractVersion" to APP_IDENTITY_CONTRACT_VERSION,
            "apps" to resolvedApps,
        )
    }

    private fun resolveOne(packageName: String): Map<String, Any?> {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            val label = packageManager.getApplicationLabel(appInfo).toString().takeIf {
                it.isNotBlank() && it != packageName
            }
            val iconBytes = drawableToPngBytes(packageManager.getApplicationIcon(appInfo))
            buildMap {
                put("packageName", packageName)
                label?.let { put("friendlyName", it) }
                nativeCategoryCode(appInfo.category)?.let { code ->
                    put("nativeCategoryCode", code)
                    put("nativeCategoryLabel", categoryLabelFor(code))
                }
                iconBytes?.let { put("iconPngBytes", it) }
            }
        } catch (_: PackageManager.NameNotFoundException) {
            mapOf("packageName" to packageName)
        }
    }

    private fun nativeCategoryCode(code: Int): Int? {
        return if (code == ApplicationInfo.CATEGORY_UNDEFINED) {
            null
        } else {
            code
        }
    }

    private fun categoryLabelFor(category: Int): String = when (category) {
        ApplicationInfo.CATEGORY_AUDIO -> "Áudio"
        ApplicationInfo.CATEGORY_GAME -> "Jogo"
        ApplicationInfo.CATEGORY_IMAGE -> "Imagem"
        ApplicationInfo.CATEGORY_MAPS -> "Mapas"
        ApplicationInfo.CATEGORY_NEWS -> "Notícias"
        ApplicationInfo.CATEGORY_PRODUCTIVITY -> "Produtividade"
        ApplicationInfo.CATEGORY_SOCIAL -> "Social"
        ApplicationInfo.CATEGORY_VIDEO -> "Vídeo"
        ApplicationInfo.CATEGORY_ACCESSIBILITY -> "Acessibilidade"
        ApplicationInfo.CATEGORY_UNDEFINED -> "Indefinida"
        else -> "Outra"
    }

    private fun drawableToPngBytes(drawable: Drawable?): ByteArray? {
        if (drawable == null) return null
        val bitmap = when (drawable) {
            is BitmapDrawable -> drawable.bitmap
            else -> {
                val width = maxOf(drawable.intrinsicWidth, 1)
                val height = maxOf(drawable.intrinsicHeight, 1)
                val generated = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(generated)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                generated
            }
        }
        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        return output.toByteArray()
    }
}
