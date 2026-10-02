package com.difrancescogianmarco.arcore_flutter_plugin

import java.util.concurrent.atomic.AtomicBoolean

/**
 * The completion half of a Flutter method call.
 *
 * Mirrors `MethodChannel.Result` without depending on it, so the
 * exactly-once contract is unit-testable on the JVM. [ArCoreView] adapts the
 * real channel result onto this interface.
 */
interface ArCallResult {
    fun success(value: Any?)
    fun error(code: String, message: String?, details: Any?)
    fun notImplemented()
}

/**
 * Registry that enforces "every method call completes exactly once".
 *
 * Two failure modes made AR unusable and both are structural rather than
 * incidental, so they are fixed here once instead of at each call site:
 *
 * - A branch that returned without completing left the Dart future pending
 *   forever. Awaiting `dispose` during a camera handoff therefore never
 *   returned and the transition deadlocked.
 * - A capture completing after teardown replied through a detached channel,
 *   which throws on the main thread.
 *
 * Wrapping every result means late, duplicate and post-teardown completions
 * are all absorbed, and [cancelAll] can settle whatever is still in flight.
 */
class ArPendingCalls {

    private val pending = LinkedHashSet<TrackedCall>()
    private var cancellation: Pair<String, String>? = null

    /** Number of calls still awaiting completion. */
    val outstanding: Int
        @Synchronized get() = pending.size

    /**
     * Wraps [delegate] so it completes at most once.
     *
     * If teardown already ran, the call is settled immediately with the
     * recorded cancellation rather than being registered: Dart is still
     * awaiting it, so silently dropping it would strand the future.
     */
    fun track(delegate: ArCallResult): ArCallResult {
        val tracked = TrackedCall(delegate)
        val alreadyCancelled = synchronized(this) {
            cancellation.also { if (it == null) pending.add(tracked) }
        }
        if (alreadyCancelled != null) {
            tracked.deliver { delegate.error(alreadyCancelled.first, alreadyCancelled.second, null) }
        }
        return tracked
    }

    /**
     * Completes every outstanding call with [code].
     *
     * Called at the start of teardown so a capture, node operation or resume
     * that is still in flight resolves instead of hanging. Later calls are
     * rejected with the same code.
     *
     * [except] stays pending: teardown is itself driven by a method call, and
     * that call has to survive long enough to report that teardown finished.
     * It keeps its exactly-once protection either way.
     */
    fun cancelAll(code: String, message: String, except: ArCallResult? = null) {
        val toCancel = synchronized(this) {
            cancellation = code to message
            val survivor = except as? TrackedCall
            val cancelling = pending.filterNot { it === survivor }
            pending.clear()
            if (survivor != null) {
                pending.add(survivor)
            }
            cancelling
        }
        for (call in toCancel) {
            call.deliver { call.delegate.error(code, message, null) }
        }
    }

    private fun forget(call: TrackedCall) {
        synchronized(this) { pending.remove(call) }
    }

    private inner class TrackedCall(val delegate: ArCallResult) : ArCallResult {

        private val completed = AtomicBoolean(false)

        override fun success(value: Any?) = deliver { delegate.success(value) }

        override fun error(code: String, message: String?, details: Any?) =
            deliver { delegate.error(code, message, details) }

        override fun notImplemented() = deliver { delegate.notImplemented() }

        /**
         * Runs [block] for the first caller only.
         *
         * The delegate itself can throw when the channel is already detached;
         * that is expected during teardown and must not reach the main thread,
         * but the entry is still cleared so nothing is reported as pending.
         */
        fun deliver(block: () -> Unit) {
            if (!completed.compareAndSet(false, true)) {
                return
            }
            forget(this)
            try {
                block()
            } catch (_: Exception) {
                // The channel is gone; the call is settled either way.
            }
        }
    }
}
