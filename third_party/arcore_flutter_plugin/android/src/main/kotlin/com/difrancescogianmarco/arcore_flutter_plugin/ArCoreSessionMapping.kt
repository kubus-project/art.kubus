package com.difrancescogianmarco.arcore_flutter_plugin

/**
 * Pure mapping logic for the ARCore session bridge.
 *
 * Deliberately free of Android and ARCore types so it can be unit-tested on
 * the JVM. Anything that needs a real session, camera, or frame lives in
 * [ArCoreView] and is only verifiable on hardware.
 */
object ArCoreSessionMapping {

    /** Stable code Flutter maps to localized, actionable guidance. */
    const val CODE_INSTALL_REQUIRED = "arcore_install_required"
    const val CODE_UPDATE_REQUIRED = "arcore_update_required"
    const val CODE_APP_UPDATE_REQUIRED = "app_update_required"
    const val CODE_UNSUPPORTED_DEVICE = "arcore_unsupported_device"
    const val CODE_SESSION_UNAVAILABLE = "arcore_session_unavailable"
    const val CODE_INSTALL_DECLINED = "arcore_install_declined"
    const val CODE_CAMERA_UNAVAILABLE = "camera_unavailable"

    /**
     * Maps an ARCore availability exception to a stable code.
     *
     * Keyed on the exception's simple name rather than the type so this stays
     * unit-testable without the ARCore runtime on the test classpath.
     */
    fun availabilityCode(exceptionSimpleName: String): String = when (exceptionSimpleName) {
        "UnavailableArcoreNotInstalledException" -> CODE_INSTALL_REQUIRED
        "UnavailableApkTooOldException" -> CODE_UPDATE_REQUIRED
        "UnavailableSdkTooOldException" -> CODE_APP_UPDATE_REQUIRED
        "UnavailableDeviceNotCompatibleException" -> CODE_UNSUPPORTED_DEVICE
        "UnavailableUserDeclinedInstallationException" -> CODE_INSTALL_DECLINED
        else -> CODE_SESSION_UNAVAILABLE
    }

    /**
     * Whether a tracking update is worth sending to Flutter.
     *
     * ARCore reports camera state on every frame. Forwarding all of them would
     * spam the channel at display rate, so only genuine changes are emitted.
     */
    fun shouldEmitTrackingChange(
        previousState: String?,
        previousReason: String?,
        state: String,
        reason: String?
    ): Boolean = previousState != state || previousReason != reason

    /**
     * Capture failures that are part of normal operation.
     *
     * ARCore has brief image gaps even while tracking, and teardown cancels
     * work in flight. A later sampling tick retries, so these must never reach
     * the user or fail the session.
     */
    fun isTransientCaptureFailure(code: String): Boolean = code in transientCaptureCodes

    val transientCaptureCodes: Set<String> = setOf(
        "frame_not_yet_available",
        "tracking_unavailable",
        "capture_cancelled"
    )

    /** Whether a session error can be retried in place. */
    fun isRetryable(code: String): Boolean = code != CODE_UNSUPPORTED_DEVICE
}
