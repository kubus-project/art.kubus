package com.art.kubus

import io.flutter.embedding.android.FlutterFragmentActivity
import com.google.ar.core.ArCoreApk
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity: FlutterFragmentActivity() {
    private fun handleMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
        "checkARCoreSupport" -> {
            val availability = ArCoreApk.getInstance().checkAvailability(this)
            val isSupported = availability.isSupported || availability.isTransient
            result.success(isSupported)
        }
        else -> result.notImplemented()
    }
}
}