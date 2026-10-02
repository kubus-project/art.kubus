package com.difrancescogianmarco.arcore_flutter_plugin

/**
 * Lifecycle states of the native ARCore session.
 *
 * [RUNNING] is the only state in which a real [com.google.ar.core.Session] is
 * attached to a resumed `ArSceneView`. Flutter is told the controller is ready
 * only once that is true, so "initialized" can no longer mean "the method
 * handler returned".
 */
enum class ArSessionState {
    CREATED,
    INITIALIZING,
    RUNNING,
    PAUSED,
    DISPOSING,
    DISPOSED,
    ERROR
}

/**
 * What the caller should do with a lifecycle request.
 *
 * Every AR method call resolves to exactly one of these, which is what
 * guarantees each [io.flutter.plugin.common.MethodChannel.Result] completes
 * once: [Proceed] performs the native work and reports its own outcome,
 * [NoOp] completes successfully without touching the session, and [Rejected]
 * completes with a typed code Flutter can localize.
 */
sealed class ArLifecycleOutcome {

    /** The request is legal and the native work should run. */
    object Proceed : ArLifecycleOutcome()

    /** The request is legal but already satisfied; complete successfully. */
    object NoOp : ArLifecycleOutcome()

    /** The request is not legal in this state; complete with [code]. */
    data class Rejected(val code: String, val message: String) : ArLifecycleOutcome()
}

/**
 * Serialised lifecycle for one native AR session.
 *
 * Method-channel calls, activity lifecycle callbacks, the capture executor and
 * scene-update callbacks all drive this concurrently, so every transition is
 * guarded by the instance monitor. Keeping the rules here - rather than spread
 * across null checks on `arSceneView` - is what makes double resume, double
 * dispose and post-teardown work decidable instead of racy.
 */
class ArSessionLifecycle {

    companion object {
        /** An initialization is already in flight for this view. */
        const val CODE_ALREADY_INITIALIZING = "ar_session_initializing"

        /** The view is tearing down or gone; the caller should stop. */
        const val CODE_SESSION_DISPOSED = "ar_session_disposed"

        /** The session failed and cannot serve this request. */
        const val CODE_SESSION_ERROR = "ar_session_error"
    }

    @Volatile
    var state: ArSessionState = ArSessionState.CREATED
        private set

    /** Whether a configured, resumed session is attached right now. */
    val isRunning: Boolean
        get() = state == ArSessionState.RUNNING

    /** Whether node, hit-test and capture work may touch the scene. */
    val acceptsSceneWork: Boolean
        get() = state == ArSessionState.RUNNING

    /** Whether teardown has begun, so callbacks must stop emitting. */
    val isTearingDown: Boolean
        get() = state == ArSessionState.DISPOSING || state == ArSessionState.DISPOSED

    /**
     * Requests the first real session creation.
     *
     * A repeat call once [RUNNING] is a success no-op rather than a second
     * session: Flutter retries `init` when a platform view is remounted, and
     * creating a second session would fight the first one for the camera.
     */
    @Synchronized
    fun beginInitialize(): ArLifecycleOutcome = when (state) {
        ArSessionState.CREATED, ArSessionState.ERROR -> {
            state = ArSessionState.INITIALIZING
            ArLifecycleOutcome.Proceed
        }
        ArSessionState.INITIALIZING -> ArLifecycleOutcome.Rejected(
            CODE_ALREADY_INITIALIZING,
            "An AR session is already being initialized."
        )
        ArSessionState.RUNNING, ArSessionState.PAUSED -> ArLifecycleOutcome.NoOp
        ArSessionState.DISPOSING, ArSessionState.DISPOSED -> disposedRejection()
    }

    /** The session exists, is configured and the view is resumed. */
    @Synchronized
    fun initializeSucceeded() {
        // A dispose can land while init is in flight; teardown wins.
        if (state == ArSessionState.INITIALIZING) {
            state = ArSessionState.RUNNING
        }
    }

    /** Initialization failed; never report a usable session. */
    @Synchronized
    fun initializeFailed() {
        if (state == ArSessionState.INITIALIZING) {
            state = ArSessionState.ERROR
        }
    }

    /**
     * Requests a resume.
     *
     * Before a session exists this is a no-op rather than an error: the
     * activity can resume at any point during startup, and that is not a
     * failure Flutter should see.
     */
    @Synchronized
    fun requestResume(): ArLifecycleOutcome = when (state) {
        ArSessionState.PAUSED -> ArLifecycleOutcome.Proceed
        ArSessionState.RUNNING -> ArLifecycleOutcome.NoOp
        ArSessionState.CREATED, ArSessionState.INITIALIZING -> ArLifecycleOutcome.NoOp
        ArSessionState.ERROR -> ArLifecycleOutcome.Rejected(
            CODE_SESSION_ERROR,
            "The AR session is not available."
        )
        ArSessionState.DISPOSING, ArSessionState.DISPOSED -> disposedRejection()
    }

    /** The view resumed successfully. */
    @Synchronized
    fun resumeSucceeded() {
        if (state == ArSessionState.PAUSED) {
            state = ArSessionState.RUNNING
        }
    }

    /** The view could not resume, typically because the camera is held. */
    @Synchronized
    fun resumeFailed() {
        if (state == ArSessionState.PAUSED || state == ArSessionState.RUNNING) {
            state = ArSessionState.ERROR
        }
    }

    /**
     * Requests a pause.
     *
     * Pausing is never an error: the activity may pause during startup, during
     * teardown or twice in a row, and none of those should throw at Flutter.
     */
    @Synchronized
    fun requestPause(): ArLifecycleOutcome = when (state) {
        ArSessionState.RUNNING -> {
            state = ArSessionState.PAUSED
            ArLifecycleOutcome.Proceed
        }
        else -> ArLifecycleOutcome.NoOp
    }

    /**
     * Claims teardown.
     *
     * Returns true for exactly one caller, so the destroy path runs once even
     * when Flutter's `dispose` call and the platform view's own disposal race.
     */
    @Synchronized
    fun beginDispose(): Boolean {
        if (isTearingDown) {
            return false
        }
        state = ArSessionState.DISPOSING
        return true
    }

    /** Teardown finished; every later call is rejected. */
    @Synchronized
    fun disposeFinished() {
        state = ArSessionState.DISPOSED
    }

    private fun disposedRejection() = ArLifecycleOutcome.Rejected(
        CODE_SESSION_DISPOSED,
        "The AR session has been disposed."
    )
}
