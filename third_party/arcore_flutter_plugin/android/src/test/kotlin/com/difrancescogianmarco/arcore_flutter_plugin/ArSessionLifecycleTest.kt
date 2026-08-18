package com.difrancescogianmarco.arcore_flutter_plugin

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM coverage for the native AR session lifecycle.
 *
 * The state machine is deliberately free of Android and ARCore types, so the
 * transition rules that used to live implicitly across [ArCoreView], the
 * activity callbacks and the capture executor are verifiable without
 * hardware. Only the effects it authorises - creating a session, resuming the
 * view, destroying it - remain hardware-only.
 */
class ArSessionLifecycleTest {

    @Test
    fun `starts in created and accepts initialization`() {
        val lifecycle = ArSessionLifecycle()
        assertEquals(ArSessionState.CREATED, lifecycle.state)
        assertEquals(ArLifecycleOutcome.Proceed, lifecycle.beginInitialize())
        assertEquals(ArSessionState.INITIALIZING, lifecycle.state)
    }

    @Test
    fun `initialization reaches running only when the session is ready`() {
        val lifecycle = ArSessionLifecycle()
        lifecycle.beginInitialize()
        // Still initializing: Flutter must not be told the session is usable.
        assertFalse(lifecycle.isRunning)
        lifecycle.initializeSucceeded()
        assertEquals(ArSessionState.RUNNING, lifecycle.state)
        assertTrue(lifecycle.isRunning)
    }

    @Test
    fun `cannot double initialize while initialization is in flight`() {
        val lifecycle = ArSessionLifecycle()
        lifecycle.beginInitialize()
        val second = lifecycle.beginInitialize()
        assertTrue(second is ArLifecycleOutcome.Rejected)
        assertEquals(
            ArSessionLifecycle.CODE_ALREADY_INITIALIZING,
            (second as ArLifecycleOutcome.Rejected).code
        )
        assertEquals(ArSessionState.INITIALIZING, lifecycle.state)
    }

    @Test
    fun `initializing again once running is a success no-op`() {
        val lifecycle = running()
        assertEquals(ArLifecycleOutcome.NoOp, lifecycle.beginInitialize())
        assertEquals(ArSessionState.RUNNING, lifecycle.state)
    }

    @Test
    fun `failed initialization lands in error and never reports running`() {
        val lifecycle = ArSessionLifecycle()
        lifecycle.beginInitialize()
        lifecycle.initializeFailed()
        assertEquals(ArSessionState.ERROR, lifecycle.state)
        assertFalse(lifecycle.isRunning)
        assertFalse(lifecycle.acceptsSceneWork)
    }

    @Test
    fun `error state allows a fresh initialization attempt`() {
        val lifecycle = ArSessionLifecycle()
        lifecycle.beginInitialize()
        lifecycle.initializeFailed()
        assertEquals(ArLifecycleOutcome.Proceed, lifecycle.beginInitialize())
        assertEquals(ArSessionState.INITIALIZING, lifecycle.state)
    }

    @Test
    fun `pause then resume returns to running`() {
        val lifecycle = running()
        assertEquals(ArLifecycleOutcome.Proceed, lifecycle.requestPause())
        assertEquals(ArSessionState.PAUSED, lifecycle.state)
        assertEquals(ArLifecycleOutcome.Proceed, lifecycle.requestResume())
        lifecycle.resumeSucceeded()
        assertEquals(ArSessionState.RUNNING, lifecycle.state)
    }

    @Test
    fun `double resume does not re-enter the native resume`() {
        val lifecycle = running()
        // An activity resume and an explicit Flutter resume can land together.
        assertEquals(ArLifecycleOutcome.NoOp, lifecycle.requestResume())
        assertEquals(ArSessionState.RUNNING, lifecycle.state)
    }

    @Test
    fun `double pause does not re-enter the native pause`() {
        val lifecycle = running()
        lifecycle.requestPause()
        assertEquals(ArLifecycleOutcome.NoOp, lifecycle.requestPause())
        assertEquals(ArSessionState.PAUSED, lifecycle.state)
    }

    @Test
    fun `resume before a session exists is a no-op rather than a crash`() {
        val lifecycle = ArSessionLifecycle()
        assertEquals(ArLifecycleOutcome.NoOp, lifecycle.requestResume())
        lifecycle.beginInitialize()
        assertEquals(ArLifecycleOutcome.NoOp, lifecycle.requestResume())
    }

    @Test
    fun `failed resume degrades to error without claiming running`() {
        val lifecycle = running()
        lifecycle.requestPause()
        lifecycle.requestResume()
        lifecycle.resumeFailed()
        assertEquals(ArSessionState.ERROR, lifecycle.state)
        assertFalse(lifecycle.isRunning)
    }

    @Test
    fun `dispose runs teardown exactly once`() {
        val lifecycle = running()
        assertTrue(lifecycle.beginDispose())
        assertEquals(ArSessionState.DISPOSING, lifecycle.state)
        // A second dispose must not tear down a second time.
        assertFalse(lifecycle.beginDispose())
        lifecycle.disposeFinished()
        assertEquals(ArSessionState.DISPOSED, lifecycle.state)
        assertFalse(lifecycle.beginDispose())
    }

    @Test
    fun `dispose from any live state is permitted`() {
        val builders = listOf<() -> ArSessionLifecycle>(
            { ArSessionLifecycle() },
            { ArSessionLifecycle().apply { beginInitialize() } },
            { running() },
            { running().apply { requestPause() } },
            { ArSessionLifecycle().apply { beginInitialize(); initializeFailed() } }
        )
        for (build in builders) {
            assertTrue(build().beginDispose())
        }
    }

    @Test
    fun `disposing rejects new work with a typed code`() {
        val lifecycle = running()
        lifecycle.beginDispose()
        val outcomes = listOf(lifecycle.beginInitialize(), lifecycle.requestResume())
        for (outcome in outcomes) {
            assertTrue(outcome is ArLifecycleOutcome.Rejected)
            assertEquals(
                ArSessionLifecycle.CODE_SESSION_DISPOSED,
                (outcome as ArLifecycleOutcome.Rejected).code
            )
        }
        assertFalse(lifecycle.acceptsSceneWork)
    }

    @Test
    fun `pause while disposing is a no-op rather than a rejection`() {
        val lifecycle = running()
        lifecycle.beginDispose()
        // The activity can pause underneath a teardown; that is not an error.
        assertEquals(ArLifecycleOutcome.NoOp, lifecycle.requestPause())
    }

    @Test
    fun `disposed rejects every subsequent call`() {
        val lifecycle = running()
        lifecycle.beginDispose()
        lifecycle.disposeFinished()
        assertTrue(lifecycle.beginInitialize() is ArLifecycleOutcome.Rejected)
        assertTrue(lifecycle.requestResume() is ArLifecycleOutcome.Rejected)
        assertEquals(ArLifecycleOutcome.NoOp, lifecycle.requestPause())
        assertFalse(lifecycle.acceptsSceneWork)
    }

    @Test
    fun `scene work is only accepted while running`() {
        assertFalse(ArSessionLifecycle().acceptsSceneWork)
        assertFalse(ArSessionLifecycle().apply { beginInitialize() }.acceptsSceneWork)
        assertTrue(running().acceptsSceneWork)
        assertFalse(running().apply { requestPause() }.acceptsSceneWork)
    }

    @Test
    fun `rapid pause resume cycles stay legal`() {
        val lifecycle = running()
        repeat(50) {
            assertEquals(ArLifecycleOutcome.Proceed, lifecycle.requestPause())
            assertEquals(ArLifecycleOutcome.Proceed, lifecycle.requestResume())
            lifecycle.resumeSucceeded()
        }
        assertEquals(ArSessionState.RUNNING, lifecycle.state)
    }

    private fun running(): ArSessionLifecycle = ArSessionLifecycle().apply {
        beginInitialize()
        initializeSucceeded()
    }
}
