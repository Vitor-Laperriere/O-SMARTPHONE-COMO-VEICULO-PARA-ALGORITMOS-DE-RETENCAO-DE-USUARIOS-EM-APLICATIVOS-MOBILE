package com.example.foco_tela

import android.app.usage.UsageEvents
import org.junit.Assert.assertEquals
import org.junit.Test

@Suppress("DEPRECATION")
class AndroidUsageEventTypeNormalizerTest {
    @Test
    fun `API 28 and API 29 foreground events share the normalized contract`() {
        assertEquals(
            "foreground",
            AndroidUsageEventTypeNormalizer.kindFor(
                UsageEvents.Event.MOVE_TO_FOREGROUND
            )
        )
        assertEquals(
            "foreground",
            AndroidUsageEventTypeNormalizer.kindFor(
                UsageEvents.Event.ACTIVITY_RESUMED
            )
        )
    }

    @Test
    fun `API 28 and API 29 background events share the normalized contract`() {
        assertEquals(
            "background",
            AndroidUsageEventTypeNormalizer.kindFor(
                UsageEvents.Event.MOVE_TO_BACKGROUND
            )
        )
        assertEquals(
            "background",
            AndroidUsageEventTypeNormalizer.kindFor(
                UsageEvents.Event.ACTIVITY_PAUSED
            )
        )
    }

    @Test
    fun `device boundary events preserve all observable kinds`() {
        assertEquals(
            "unlock",
            AndroidUsageEventTypeNormalizer.kindFor(
                UsageEvents.Event.KEYGUARD_HIDDEN
            )
        )
        assertEquals(
            "screenInteractive",
            AndroidUsageEventTypeNormalizer.kindFor(
                UsageEvents.Event.SCREEN_INTERACTIVE
            )
        )
        assertEquals(
            "screenNonInteractive",
            AndroidUsageEventTypeNormalizer.kindFor(
                UsageEvents.Event.SCREEN_NON_INTERACTIVE
            )
        )
    }
}
