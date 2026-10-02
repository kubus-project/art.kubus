package com.difrancescogianmarco.arcore_flutter_plugin

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM coverage for the pure session-mapping logic.
 *
 * These verify the mapping only. Session creation, camera acquisition,
 * tracking, frame lifetime and disposal ordering need a real ARCore runtime
 * and remain hardware-only.
 */
class ArCoreSessionMappingTest {

    @Test
    fun `each availability failure maps to its own code`() {
        assertEquals(
            ArCoreSessionMapping.CODE_INSTALL_REQUIRED,
            ArCoreSessionMapping.availabilityCode("UnavailableArcoreNotInstalledException")
        )
        assertEquals(
            ArCoreSessionMapping.CODE_UPDATE_REQUIRED,
            ArCoreSessionMapping.availabilityCode("UnavailableApkTooOldException")
        )
        assertEquals(
            ArCoreSessionMapping.CODE_APP_UPDATE_REQUIRED,
            ArCoreSessionMapping.availabilityCode("UnavailableSdkTooOldException")
        )
        assertEquals(
            ArCoreSessionMapping.CODE_UNSUPPORTED_DEVICE,
            ArCoreSessionMapping.availabilityCode("UnavailableDeviceNotCompatibleException")
        )
        assertEquals(
            ArCoreSessionMapping.CODE_INSTALL_DECLINED,
            ArCoreSessionMapping.availabilityCode("UnavailableUserDeclinedInstallationException")
        )
    }

    @Test
    fun `install and update failures never collapse into one code`() {
        val install = ArCoreSessionMapping.availabilityCode("UnavailableArcoreNotInstalledException")
        val update = ArCoreSessionMapping.availabilityCode("UnavailableApkTooOldException")
        assertNotEquals(install, update)
    }

    @Test
    fun `an unknown failure falls back rather than leaking the class name`() {
        val code = ArCoreSessionMapping.availabilityCode("SomeFutureArCoreException")
        assertEquals(ArCoreSessionMapping.CODE_SESSION_UNAVAILABLE, code)
        assertFalse(code.contains("Exception"))
    }

    @Test
    fun `only an unsupported device is not retryable`() {
        assertTrue(ArCoreSessionMapping.isRetryable(ArCoreSessionMapping.CODE_CAMERA_UNAVAILABLE))
        assertTrue(ArCoreSessionMapping.isRetryable(ArCoreSessionMapping.CODE_INSTALL_REQUIRED))
        assertFalse(ArCoreSessionMapping.isRetryable(ArCoreSessionMapping.CODE_UNSUPPORTED_DEVICE))
    }

    @Test
    fun `an unchanged tracking state is not re-emitted`() {
        assertFalse(
            ArCoreSessionMapping.shouldEmitTrackingChange("TRACKING", "NONE", "TRACKING", "NONE")
        )
    }

    @Test
    fun `a changed tracking state is emitted`() {
        assertTrue(
            ArCoreSessionMapping.shouldEmitTrackingChange("TRACKING", "NONE", "PAUSED", "NONE")
        )
    }

    @Test
    fun `a changed failure reason is emitted even when the state holds`() {
        assertTrue(
            ArCoreSessionMapping.shouldEmitTrackingChange(
                "PAUSED",
                "INSUFFICIENT_LIGHT",
                "PAUSED",
                "EXCESSIVE_MOTION"
            )
        )
    }

    @Test
    fun `the first tracking report is always emitted`() {
        assertTrue(
            ArCoreSessionMapping.shouldEmitTrackingChange(null, null, "TRACKING", "NONE")
        )
    }

    @Test
    fun `routine capture failures are transient`() {
        assertTrue(ArCoreSessionMapping.isTransientCaptureFailure("frame_not_yet_available"))
        assertTrue(ArCoreSessionMapping.isTransientCaptureFailure("tracking_unavailable"))
        assertTrue(ArCoreSessionMapping.isTransientCaptureFailure("capture_cancelled"))
    }

    @Test
    fun `an unexpected capture failure is not transient`() {
        assertFalse(ArCoreSessionMapping.isTransientCaptureFailure("capture_failed"))
        assertFalse(ArCoreSessionMapping.isTransientCaptureFailure("out_of_memory"))
    }
}
