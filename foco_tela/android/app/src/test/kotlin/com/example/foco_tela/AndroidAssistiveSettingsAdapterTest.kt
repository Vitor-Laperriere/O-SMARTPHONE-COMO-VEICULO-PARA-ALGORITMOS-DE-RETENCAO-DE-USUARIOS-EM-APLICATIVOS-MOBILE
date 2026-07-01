package com.example.foco_tela

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidAssistiveSettingsAdapterTest {
    @Test
    fun `opens package usage settings without invoking fallback`() {
        val starter = FakeAssistiveSettingsIntentStarter(
            usageSettingsAvailable = true,
            applicationDetailsAvailable = true
        )

        val destination = AndroidAssistiveSettingsAdapter(starter)
            .openSettings("com.example.social")

        assertEquals(AssistiveSettingsDestination.APP_USAGE_SETTINGS, destination)
        assertEquals(listOf("com.example.social"), starter.usageSettingsPackages)
        assertTrue(starter.applicationDetailsPackages.isEmpty())
    }

    @Test
    fun `falls back to application details for the same package`() {
        val starter = FakeAssistiveSettingsIntentStarter(
            usageSettingsAvailable = false,
            applicationDetailsAvailable = true
        )

        val destination = AndroidAssistiveSettingsAdapter(starter)
            .openSettings("com.example.social")

        assertEquals(AssistiveSettingsDestination.APPLICATION_DETAILS, destination)
        assertEquals(listOf("com.example.social"), starter.usageSettingsPackages)
        assertEquals(listOf("com.example.social"), starter.applicationDetailsPackages)
    }

    @Test(expected = IllegalStateException::class)
    fun `fails when primary and fallback intents are unavailable`() {
        val starter = FakeAssistiveSettingsIntentStarter(
            usageSettingsAvailable = false,
            applicationDetailsAvailable = false
        )

        AndroidAssistiveSettingsAdapter(starter)
            .openSettings("com.example.social")
    }
}

private class FakeAssistiveSettingsIntentStarter(
    private val usageSettingsAvailable: Boolean,
    private val applicationDetailsAvailable: Boolean
) : AssistiveSettingsIntentStarter {
    val usageSettingsPackages = mutableListOf<String>()
    val applicationDetailsPackages = mutableListOf<String>()

    override fun openAppUsageSettings(packageName: String): Boolean {
        usageSettingsPackages += packageName
        return usageSettingsAvailable
    }

    override fun openApplicationDetails(packageName: String): Boolean {
        applicationDetailsPackages += packageName
        return applicationDetailsAvailable
    }
}
