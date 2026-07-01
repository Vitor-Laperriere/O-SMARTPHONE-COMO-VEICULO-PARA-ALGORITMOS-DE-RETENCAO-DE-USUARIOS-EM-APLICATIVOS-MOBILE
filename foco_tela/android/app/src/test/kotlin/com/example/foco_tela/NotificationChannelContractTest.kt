package com.example.foco_tela

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NotificationChannelContractTest {
    @Test
    fun `last observation preserves version and payload`() {
        val observation = mapOf(
            "observedAtMillis" to 1782052020000L,
            "packageName" to "com.example.social",
            "count" to 4
        )

        val payload = NotificationChannelContract.lastObservation(observation)

        assertEquals(NOTIFICATION_CONTRACT_VERSION, payload["contractVersion"])
        assertEquals(observation, payload["observation"])
    }

    @Test
    fun `last observation can be absent without fabricating zero`() {
        val payload = NotificationChannelContract.lastObservation(null)

        assertEquals(NOTIFICATION_CONTRACT_VERSION, payload["contractVersion"])
        assertNull(payload["observation"])
    }
}
