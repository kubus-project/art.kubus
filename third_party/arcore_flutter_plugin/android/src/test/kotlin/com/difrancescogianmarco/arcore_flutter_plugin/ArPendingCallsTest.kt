package com.difrancescogianmarco.arcore_flutter_plugin

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM coverage for the exactly-once method-call contract.
 *
 * Every Flutter to Android AR call must complete exactly once. Branches that
 * returned without completing left the Dart future pending forever, which is
 * what deadlocked camera handoff when a mode switch awaited `dispose`.
 */
class ArPendingCallsTest {

    /** Records what a single call was completed with. */
    private class RecordingCall : ArCallResult {
        var successValue: Any? = null
        var errorCode: String? = null
        var notImplementedCount = 0
        var completions = 0

        override fun success(value: Any?) {
            completions++
            successValue = value
        }

        override fun error(code: String, message: String?, details: Any?) {
            completions++
            errorCode = code
        }

        override fun notImplemented() {
            completions++
            notImplementedCount++
        }
    }

    @Test
    fun `a tracked call completes exactly once on success`() {
        val calls = ArPendingCalls()
        val recorder = RecordingCall()
        val tracked = calls.track(recorder)

        tracked.success("ok")

        assertEquals(1, recorder.completions)
        assertEquals("ok", recorder.successValue)
        assertEquals(0, calls.outstanding)
    }

    @Test
    fun `repeat completions after success are dropped`() {
        val calls = ArPendingCalls()
        val recorder = RecordingCall()
        val tracked = calls.track(recorder)

        tracked.success(null)
        tracked.success("second")
        tracked.error("late", "late", null)
        tracked.notImplemented()

        assertEquals(1, recorder.completions)
        assertNull(recorder.errorCode)
    }

    @Test
    fun `repeat completions after error are dropped`() {
        val calls = ArPendingCalls()
        val recorder = RecordingCall()
        val tracked = calls.track(recorder)

        tracked.error("first", "first", null)
        tracked.success("late")

        assertEquals(1, recorder.completions)
        assertEquals("first", recorder.errorCode)
    }

    @Test
    fun `an untouched call stays outstanding`() {
        val calls = ArPendingCalls()
        calls.track(RecordingCall())
        assertEquals(1, calls.outstanding)
    }

    @Test
    fun `cancelling completes every outstanding call with a typed code`() {
        val calls = ArPendingCalls()
        val first = RecordingCall()
        val second = RecordingCall()
        calls.track(first)
        calls.track(second)

        calls.cancelAll("capture_cancelled", "The AR session is shutting down.")

        assertEquals(1, first.completions)
        assertEquals(1, second.completions)
        assertEquals("capture_cancelled", first.errorCode)
        assertEquals("capture_cancelled", second.errorCode)
        assertEquals(0, calls.outstanding)
    }

    @Test
    fun `cancelling does not re-complete calls that already finished`() {
        val calls = ArPendingCalls()
        val finished = RecordingCall()
        val inFlight = RecordingCall()
        calls.track(finished).success("done")
        calls.track(inFlight)

        calls.cancelAll("capture_cancelled", "shutting down")

        assertEquals(1, finished.completions)
        assertEquals("done", finished.successValue)
        assertEquals(1, inFlight.completions)
        assertEquals("capture_cancelled", inFlight.errorCode)
    }

    @Test
    fun `a call completed after cancellation is dropped`() {
        val calls = ArPendingCalls()
        val recorder = RecordingCall()
        val tracked = calls.track(recorder)

        calls.cancelAll("capture_cancelled", "shutting down")
        // The capture worker finishes after teardown and tries to reply.
        tracked.success("late payload")

        assertEquals(1, recorder.completions)
        assertEquals("capture_cancelled", recorder.errorCode)
    }

    @Test
    fun `calls tracked after cancellation are rejected immediately`() {
        val calls = ArPendingCalls()
        calls.cancelAll("ar_session_disposed", "disposed")

        val recorder = RecordingCall()
        calls.track(recorder).success("ignored")

        assertEquals(1, recorder.completions)
        assertEquals("ar_session_disposed", recorder.errorCode)
        assertEquals(0, calls.outstanding)
    }

    @Test
    fun `a delegate that throws does not leave the call outstanding`() {
        val calls = ArPendingCalls()
        val throwing = object : ArCallResult {
            override fun success(value: Any?) = throw IllegalStateException("channel detached")
            override fun error(code: String, message: String?, details: Any?) = Unit
            override fun notImplemented() = Unit
        }

        // Replying through a torn-down channel throws; that must not escape
        // into the Android main thread, and must still clear the entry.
        calls.track(throwing).success(null)

        assertEquals(0, calls.outstanding)
    }

    @Test
    fun `concurrent completion still yields a single delegate call`() {
        val calls = ArPendingCalls()
        val recorder = RecordingCall()
        val tracked = calls.track(recorder)

        val threads = (0 until 8).map {
            Thread { tracked.success(it) }
        }
        threads.forEach { it.start() }
        threads.forEach { it.join() }

        assertEquals(1, recorder.completions)
    }

    @Test
    fun `notImplemented completes the call once`() {
        val calls = ArPendingCalls()
        val recorder = RecordingCall()
        calls.track(recorder).notImplemented()

        assertEquals(1, recorder.completions)
        assertEquals(1, recorder.notImplementedCount)
        assertEquals(0, calls.outstanding)
    }

    @Test
    fun `the exempted call survives cancellation and can still succeed`() {
        val calls = ArPendingCalls()
        val disposeCall = RecordingCall()
        val capture = RecordingCall()
        val tracked = calls.track(disposeCall)
        calls.track(capture)

        // The dispose call drives teardown, so cancelling everything must not
        // cancel the very call that is waiting to report teardown finished.
        calls.cancelAll("ar_session_disposed", "shutting down", except = tracked)
        tracked.success(null)

        assertEquals(1, capture.completions)
        assertEquals("ar_session_disposed", capture.errorCode)
        assertEquals(1, disposeCall.completions)
        assertNull(disposeCall.errorCode)
    }

    @Test
    fun `the exempted call is still protected against double completion`() {
        val calls = ArPendingCalls()
        val recorder = RecordingCall()
        val tracked = calls.track(recorder)

        calls.cancelAll("ar_session_disposed", "shutting down", except = tracked)
        tracked.success(null)
        tracked.success("again")

        assertEquals(1, recorder.completions)
    }

    @Test
    fun `cancelling twice is harmless`() {
        val calls = ArPendingCalls()
        val recorder = RecordingCall()
        calls.track(recorder)

        calls.cancelAll("ar_session_disposed", "disposed")
        calls.cancelAll("ar_session_disposed", "disposed")

        assertEquals(1, recorder.completions)
        assertTrue(calls.outstanding == 0)
    }
}
