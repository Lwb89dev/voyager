package com.voyager.voyager.feature.phone

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PhoneCapabilityTest {
    @Test
    fun phoneRequiresTelephonyAndDeclaredInCallService() {
        assertTrue(PhoneCapability.available(hasTelephony = true, inCallServiceDeclared = true))
        assertFalse(PhoneCapability.available(hasTelephony = false, inCallServiceDeclared = true))
        assertFalse(PhoneCapability.available(hasTelephony = true, inCallServiceDeclared = false))
    }

    @Test
    fun nonTelephonyDeviceNeverOffersCallActions() {
        assertFalse(PhoneCapability.available(hasTelephony = false, inCallServiceDeclared = false))
    }
}
