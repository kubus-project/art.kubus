package com.difrancescogianmarco.arcore_flutter_plugin

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.difrancescogianmarco.arcore_flutter_plugin.flutter_models.FlutterArCoreNode
import com.difrancescogianmarco.arcore_flutter_plugin.utils.ArCoreUtils
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Pose
import com.google.ar.sceneform.AnchorNode
import com.google.ar.sceneform.ArSceneView
import com.google.ar.sceneform.Node
import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

open class BaseArCoreView(val activity: Activity, context: Context, messenger: BinaryMessenger, id: Int, protected val debug: Boolean) : PlatformView, MethodChannel.MethodCallHandler {

    lateinit var activityLifecycleCallbacks: Application.ActivityLifecycleCallbacks
    protected val methodChannel: MethodChannel = MethodChannel(messenger, "arcore_flutter_plugin_$id")
    protected var arSceneView: ArSceneView? = null
    private val unsupportedView = FrameLayout(context)
    private var lifecycleRegistered = false
    //    protected val activity: Activity = (context.applicationContext as FlutterApplication).currentActivity
    protected val RC_PERMISSIONS = 0x123
    protected var installRequested: Boolean = false
    private val TAG: String = BaseArCoreView::class.java.name
    protected var isSupportedDevice = false

    init {
        methodChannel.setMethodCallHandler(this)
        // An unsupported device is reported to Flutter rather than closing the
        // activity, and camera permission stays owned by Flutter, which only
        // mounts this view once CAMERA is granted.
        if (ArCoreUtils.isSupportedDevice(activity)) {
            isSupportedDevice = true
            arSceneView = ArSceneView(context)
            setupLifeCycle(context)
        }
    }

    /**
     * Logs when debugging is enabled.
     *
     * This called itself rather than the platform logger, so any debug build
     * that logged recursed until the main thread died of StackOverflowError.
     */
    protected fun debugLog(message: String) {
        if (debug) {
            Log.i(TAG, message)
        }
    }

    private fun setupLifeCycle(context: Context) {
        activityLifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                debugLog("onActivityCreated")
            }

            override fun onActivityStarted(activity: Activity) {
                debugLog("onActivityStarted")
            }

            override fun onActivityResumed(activity: Activity) {
                debugLog("onActivityResumed")
                onResume()
            }

            override fun onActivityPaused(activity: Activity) {
                debugLog("onActivityPaused")
                onPause()
            }

            override fun onActivityStopped(activity: Activity) {
                debugLog("onActivityStopped")
                onPause()
            }

            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

            override fun onActivityDestroyed(activity: Activity) {
                debugLog("onActivityDestroyed")
//                onDestroy()
            }
        }

        activity.application
                .registerActivityLifecycleCallbacks(this.activityLifecycleCallbacks)
        lifecycleRegistered = true
    }

    override fun getView(): View {
        // Flutter must always receive a valid PlatformView. The typed init
        // error is delivered over the channel; returning null here crashes the
        // host activity before Dart can render its recovery UI.
        return arSceneView ?: unsupportedView
    }

    override fun dispose() {
        if (arSceneView != null) {
            onPause()
            onDestroy()
        }
    }

    /**
     * Default handler for views that do not override it.
     *
     * Returning without completing left every Dart future pending forever, so
     * an unhandled call now reports itself as unimplemented.
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        result.notImplemented()
    }

    open fun onResume() {

//        if (arSceneView?.session == null) {
//
//            // request camera permission if not already requested
//            if (!ArCoreUtils.hasCameraPermission(activity)) {
//                ArCoreUtils.requestCameraPermission(activity, RC_PERMISSIONS)
//            }
//
//            // If the session wasn't created yet, don't resume rendering.
//            // This can happen if ARCore needs to be updated or permissions are not granted yet.
//            try {
//                val session = ArCoreUtils.createArSession(activity, installRequested, isAugmentedFaces)
//                if (session == null) {
//                    installRequested = ArCoreUtils.hasCameraPermission(activity)
//                    return
//                } else {
//                    val config = Config(session)
//                    if (isAugmentedFaces) {
//                        config.augmentedFaceMode = Config.AugmentedFaceMode.MESH3D
//                    }
//                    config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
//                    session.configure(config)
//                    arSceneView?.setupSession(session)
//                }
//            } catch (e: UnavailableException) {
//                ArCoreUtils.handleSessionException(activity, e)
//            }
//        }
//
//        try {
//            arSceneView?.resume()
//        } catch (ex: CameraNotAvailableException) {
//            ArCoreUtils.displayError(activity, "Unable to get camera", ex)
//            // Session failures are reported to Flutter; never close the host Activity.
//            return
//        }
    }
    
    
    fun attachNodeToParent(node: Node?, parentNodeName: String?) {
        if (parentNodeName != null) {
            debugLog(parentNodeName)
            val parentNode: Node? = arSceneView?.scene?.findByName(parentNodeName)
            parentNode?.addChild(node)
        } else {
            debugLog("addNodeToSceneWithGeometry: NOT PARENT_NODE_NAME")
            arSceneView?.scene?.addChild(node)
        }
    }

    fun onAddNode(flutterArCoreNode: FlutterArCoreNode, result: MethodChannel.Result?) {
        debugLog(flutterArCoreNode.toString())
        NodeFactory.makeNode(activity.applicationContext, flutterArCoreNode, debug) { node, throwable ->
            debugLog("inserted ${node?.name}")

/*            if (flutterArCoreNode.parentNodeName != null) {
                debugLog(flutterArCoreNode.parentNodeName);
                val parentNode: Node? = arSceneView?.scene?.findByName(flutterArCoreNode.parentNodeName)
                parentNode?.addChild(node)
            } else {
                debugLog("addNodeToSceneWithGeometry: NOT PARENT_NODE_NAME")
                arSceneView?.scene?.addChild(node)
            }*/
            if (node != null) {
                attachNodeToParent(node, flutterArCoreNode.parentNodeName)
                for (n in flutterArCoreNode.children) {
                    n.parentNodeName = flutterArCoreNode.name
                    onAddNode(n, null)
                }
                result?.success(null)
            } else if (throwable != null) {
                result?.error("onAddNode", throwable.localizedMessage, null)
            }
        }
    }

    fun removeNode(name: String, result: MethodChannel.Result?) {
        val node = arSceneView?.scene?.findByName(name)
        if (node != null) {
            arSceneView?.scene?.removeChild(node)
            debugLog("removed ${node.name}")
        }
        result?.success(null)
    }

    fun removeNode(node: Node) {
            arSceneView?.scene?.removeChild(node)
            debugLog("removed ${node.name}")
    }

    fun onPause() {
        debugLog("onPause()")
        if (arSceneView != null) {
            arSceneView?.pause()
        }
    }

    open fun onDestroy() {
        if (lifecycleRegistered) {
            activity.application.unregisterActivityLifecycleCallbacks(activityLifecycleCallbacks)
            lifecycleRegistered = false
        }
        if (arSceneView != null) {
            arSceneView?.destroy()
            arSceneView = null
        }
    }
}
