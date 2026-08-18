package com.difrancescogianmarco.arcore_flutter_plugin

import android.app.Activity
import android.app.Application
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.PixelCopy
import android.view.View
import com.difrancescogianmarco.arcore_flutter_plugin.flutter_models.FlutterArCoreHitTestResult
import com.difrancescogianmarco.arcore_flutter_plugin.flutter_models.FlutterArCoreNode
import com.difrancescogianmarco.arcore_flutter_plugin.flutter_models.FlutterArCorePose
import com.difrancescogianmarco.arcore_flutter_plugin.models.RotatingNode
import com.difrancescogianmarco.arcore_flutter_plugin.utils.ArCoreUtils
import com.difrancescogianmarco.arcore_flutter_plugin.utils.DecodableUtils
import com.google.ar.core.*
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.NotYetAvailableException
import com.google.ar.core.exceptions.UnavailableException
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException
import com.google.ar.sceneform.*
import com.google.ar.sceneform.rendering.ModelRenderable
import com.google.ar.sceneform.rendering.Texture
import com.google.ar.sceneform.ux.AugmentedFaceNode
import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

import android.graphics.Bitmap
import android.os.Environment
import android.os.HandlerThread
import android.content.ContextWrapper
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

class ArCoreView(val activity: Activity, context: Context, messenger: BinaryMessenger, id: Int, private val isAugmentedFaces: Boolean, private val debug: Boolean) : PlatformView, MethodChannel.MethodCallHandler {
    private val methodChannel: MethodChannel = MethodChannel(messenger, "arcore_flutter_plugin_$id")
    //       private val activity: Activity = (context.applicationContext as FlutterApplication).currentActivity
    lateinit var activityLifecycleCallbacks: Application.ActivityLifecycleCallbacks
    private var installRequested: Boolean = false
    private var mUserRequestedInstall = true
    private val TAG: String = ArCoreView::class.java.name
    private var arSceneView: ArSceneView? = null
    private val gestureDetector: GestureDetector
    private val spatialCaptureExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val RC_PERMISSIONS = 0x123
    private var sceneUpdateListener: Scene.OnUpdateListener
    private var faceSceneUpdateListener: Scene.OnUpdateListener
    private var lastCameraTrackingState: TrackingState? = null
    private var lastTrackingFailureReason: TrackingFailureReason? = null

    /**
     * Lifecycle of this view's native session.
     *
     * Method-channel calls, activity callbacks, the capture executor and scene
     * updates all drive it concurrently, so it owns the "is this legal now"
     * decision that used to be inferred from `arSceneView == null`.
     */
    private val lifecycle = ArSessionLifecycle()

    /**
     * Every in-flight Flutter call, so teardown can settle them.
     *
     * A capture still encoding when dispose() runs must complete its Dart
     * future; dropping it left the sampler awaiting a reply forever.
     */
    private val pendingCalls = ArPendingCalls()

    /** Whether teardown has begun, so callbacks must stop emitting. */
    private val isDisposed: Boolean
        get() = lifecycle.isTearingDown

    /**
     * Adapts a channel result onto [ArCallResult] and tracks it.
     *
     * Every branch of the method handler completes through here, which is what
     * makes the exactly-once contract hold across all of them at once.
     */
    private fun track(result: MethodChannel.Result): ArCallResult =
            pendingCalls.track(object : ArCallResult {
                override fun success(value: Any?) = result.success(value)
                override fun error(code: String, message: String?, details: Any?) =
                        result.error(code, message, details)
                override fun notImplemented() = result.notImplemented()
            })

    /**
     * Completes a tracked call on the main thread.
     *
     * Unlike a plain post this still runs during teardown: the tracked result
     * absorbs a detached channel, and Dart is awaiting a reply either way.
     */
    private fun completeOnMain(block: () -> Unit) {
        mainHandler.post {
            try {
                block()
            } catch (e: Exception) {
                debugLog("result delivery failed: ${e.localizedMessage}")
            }
        }
    }

    /**
     * Sends a native-originated event to Flutter.
     *
     * Single funnel for every `invokeMethod` raised by a callback: teardown
     * detaches the channel handler, and invoking through it afterwards throws
     * on the main thread. Callbacks can still fire at that point - a queued
     * scene update, a late tap - so the guard lives here, not at each site.
     */
    private fun emitToFlutterSafely(method: String, arguments: Any?) {
        if (isDisposed) {
            return
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            deliverToFlutter(method, arguments)
        } else {
            mainHandler.post { deliverToFlutter(method, arguments) }
        }
    }

    private fun deliverToFlutter(method: String, arguments: Any?) {
        if (isDisposed) {
            return
        }
        try {
            methodChannel.invokeMethod(method, arguments)
        } catch (e: Exception) {
            debugLog("emit $method failed: ${e.localizedMessage}")
        }
    }

    /**
     * Reports a typed, recoverable AR session error to Flutter.
     *
     * Recoverable session problems are product states, not crashes: Flutter
     * maps the code to localized guidance and offers a retry.
     */
    private fun reportSessionError(code: String, message: String) {
        emitToFlutterSafely("onSessionError", hashMapOf("code" to code, "message" to message))
    }

    //AUGMENTEDFACE
    private var faceRegionsRenderable: ModelRenderable? = null
    private var faceMeshTexture: Texture? = null
    private val faceNodeMap = HashMap<AugmentedFace, AugmentedFaceNode>()

    /** Stable view handed to Flutter, kept past session teardown. */
    private val hostView: View

    init {
        methodChannel.setMethodCallHandler(this)
        val createdView = ArSceneView(context)
        arSceneView = createdView
        hostView = createdView
        // Set up a tap gesture detector.
        gestureDetector = GestureDetector(
                context,
                object : GestureDetector.SimpleOnGestureListener() {
                    override fun onSingleTapUp(e: MotionEvent): Boolean {
                        onSingleTap(e)
                        return true
                    }

                    override fun onDown(e: MotionEvent): Boolean {
                        return true
                    }
                })

        sceneUpdateListener = Scene.OnUpdateListener { frameTime ->

            // Sceneform can deliver a queued update after teardown starts.
            // Touching the session or the channel at that point throws on the
            // main thread, which surfaced as an unexplained process death.
            if (isDisposed) {
                return@OnUpdateListener
            }

            val frame = arSceneView?.arFrame ?: return@OnUpdateListener

            val camera = frame.camera
            if (ArCoreSessionMapping.shouldEmitTrackingChange(
                            lastCameraTrackingState?.toString(),
                            lastTrackingFailureReason?.toString(),
                            camera.trackingState.toString(),
                            camera.trackingFailureReason.toString()
                    )) {
                lastCameraTrackingState = camera.trackingState
                lastTrackingFailureReason = camera.trackingFailureReason
                emitToFlutterSafely("onTrackingStateChanged", hashMapOf(
                    "state" to camera.trackingState.toString(),
                    "failureReason" to camera.trackingFailureReason.toString()
                ))
            }

            if (camera.trackingState != TrackingState.TRACKING) {
                return@OnUpdateListener
            }

            for (plane in frame.getUpdatedTrackables(Plane::class.java)) {
                if (plane.trackingState == TrackingState.TRACKING) {

                    val pose = plane.centerPose
                    val map: HashMap<String, Any> = HashMap<String, Any>()
                    map["type"] = plane.type.ordinal
                    map["centerPose"] = FlutterArCorePose(pose.translation, pose.rotationQuaternion).toHashMap()
                    map["extentX"] = plane.extentX
                    map["extentZ"] = plane.extentZ

                    emitToFlutterSafely("onPlaneDetected", map)
                }
            }
        }

        faceSceneUpdateListener = Scene.OnUpdateListener { frameTime ->
            run {
                if (isDisposed) {
                    return@OnUpdateListener
                }
                //                if (faceRegionsRenderable == null || faceMeshTexture == null) {
                if (faceMeshTexture == null) {
                    return@OnUpdateListener
                }

                val faceList = arSceneView?.session?.getAllTrackables(AugmentedFace::class.java)

                faceList?.let {
                    // Make new AugmentedFaceNodes for any new faces.
                    for (face in faceList) {
                        if (!faceNodeMap.containsKey(face)) {
                            val faceNode = AugmentedFaceNode(face)
                            faceNode.setParent(arSceneView?.scene)
                            faceNode.faceRegionsRenderable = faceRegionsRenderable
                            faceNode.faceMeshTexture = faceMeshTexture
                            faceNodeMap[face] = faceNode
                        }
                    }

                    // Remove any AugmentedFaceNodes associated with an AugmentedFace that stopped tracking.
                    val iter = faceNodeMap.iterator()
                    while (iter.hasNext()) {
                        val entry = iter.next()
                        val face = entry.key
                        if (face.trackingState == TrackingState.STOPPED) {
                            val faceNode = entry.value
                            faceNode.setParent(null)
                            iter.remove()
                        }
                    }
                }
            }
        }

        // Camera permission is owned by Flutter, which only mounts this view
        // once CAMERA is granted. Requesting it here as well raced that flow:
        // the dialog paused the activity mid platform-view creation, which
        // pushed a pause/resume through a half-built session.
        setupLifeCycle(context)
    }

    fun debugLog(message: String) {
        if (debug) {
            Log.i(TAG, message)
        }
    }


    fun loadMesh(textureBytes: ByteArray) {
        // Load the face regions renderable.
        // This is a skinned model that renders 3D objects mapped to the regions of the augmented face.
        /*ModelRenderable.builder()
                .setSource(activity, Uri.parse("fox_face.sfb"))
                .build()
                .thenAccept { modelRenderable ->
                    faceRegionsRenderable = modelRenderable;
                    modelRenderable.isShadowCaster = false;
                    modelRenderable.isShadowReceiver = false;
                }*/

        // Load the face mesh texture.
        //                .setSource(activity, Uri.parse("fox_face_mesh_texture.png"))
        Texture.builder()
                .setSource(BitmapFactory.decodeByteArray(textureBytes, 0, textureBytes.size))
                .build()
                .thenAccept { texture -> faceMeshTexture = texture }
    }


    /**
     * Entry point for every Flutter AR call.
     *
     * Each branch completes [tracked] exactly once. Branches that previously
     * fell through without completing - dispose, resume, getTrackingState,
     * togglePlaneRenderer, positionChanged, loadMesh and the else case - left
     * the Dart future pending forever, so awaiting `dispose()` during a camera
     * handoff never returned and the mode switch deadlocked.
     *
     * An unexpected throw here would otherwise reach the Android main thread
     * and kill the process, so it is mapped to a typed failure instead.
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val tracked = track(result)
        try {
            dispatch(call, tracked)
        } catch (error: Throwable) {
            debugLog("method ${call.method} failed: ${error.localizedMessage}")
            tracked.error(
                    ArCoreSessionMapping.CODE_SESSION_UNAVAILABLE,
                    error.localizedMessage ?: "The AR session failed to handle ${call.method}.",
                    null
            )
        }
    }

    private fun dispatch(call: MethodCall, result: ArCallResult) {
        when (call.method) {
            "init" -> {
                arScenViewInit(call, result)
            }
            "addArCoreNode" -> {
                debugLog(" addArCoreNode")
                if (requireScene(result) == null) return
                val map = call.arguments as HashMap<String, Any>
                val flutterNode = FlutterArCoreNode(map)
                onAddNode(flutterNode, result)
            }
            "addArCoreNodeWithAnchor" -> {
                debugLog(" addArCoreNodeWithAnchor")
                if (requireScene(result) == null) return
                val map = call.arguments as HashMap<String, Any>
                val flutterNode = FlutterArCoreNode(map)
                addNodeWithAnchor(flutterNode, map, result)
            }
            "removeARCoreNode" -> {
                debugLog(" removeARCoreNode")
                val map = call.arguments as HashMap<String, Any>
                removeNode(map["nodeName"] as String, result)
            }
            "updateAnchoredNode" -> {
                debugLog(" updateAnchoredNode")
                updateAnchoredNode(call, result)
            }
            "positionChanged" -> {
                // Position is applied through updateAnchoredNode so the anchor
                // and its content keep separate coordinate spaces.
                debugLog(" positionChanged")
                result.success(null)
            }
            "rotationChanged" -> {
                debugLog(" rotationChanged")
                updateRotation(call, result)
            }
            "updateMaterials" -> {
                debugLog(" updateMaterials")
                updateMaterials(call, result)
            }
            "takeScreenshot" -> {
                debugLog(" takeScreenshot")
                takeScreenshot(call, result)
            }
            "captureSpatialFrame" -> captureSpatialFrame(result)
            "loadMesh" -> {
                val map = call.arguments as HashMap<String, Any>
                val textureBytes = map["textureBytes"] as? ByteArray
                if (textureBytes == null) {
                    result.error("invalid_mesh_texture", "textureBytes must be a byte array", null)
                    return
                }
                loadMesh(textureBytes)
                result.success(null)
            }
            "dispose" -> {
                debugLog("Disposing ARCore now")
                // Exempted from its own cancellation sweep so it survives to
                // report that teardown actually finished; disposeSession
                // completes it. A second dispose finds teardown already
                // claimed and is settled by the cancellation record instead.
                disposeSession(exempt = result)
            }
            "resume" -> {
                debugLog("Resuming ARCore now")
                resumeSessionSafely(result)
            }
            "pause" -> {
                debugLog("Pausing ARCore now")
                pauseSessionSafely()
                result.success(null)
            }
            "getTrackingState" -> {
                // Answers on the result rather than through a second
                // invokeMethod, so the caller's future actually resolves.
                val trackingState = arSceneView?.arFrame?.camera?.trackingState
                debugLog("Tracking state is $trackingState")
                result.success(trackingState?.toString())
            }
            "togglePlaneRenderer" -> {
                debugLog(" Toggle planeRenderer visibility")
                val scene = requireScene(result) ?: return
                scene.planeRenderer.isVisible = !scene.planeRenderer.isVisible
                result.success(scene.planeRenderer.isVisible)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Returns the scene view, or completes [result] with a typed error.
     *
     * Operations used to `return` when the view was gone, abandoning the call.
     * Flutter needs to know the session went away so it can show a recoverable
     * state rather than waiting on a reply that never comes.
     */
    private fun requireScene(result: ArCallResult): ArSceneView? {
        val scene = arSceneView
        if (scene == null || isDisposed) {
            result.error(
                    ArSessionLifecycle.CODE_SESSION_DISPOSED,
                    "The AR session is no longer available.",
                    null
            )
            return null
        }
        return scene
    }

/*    fun maybeEnableArButton() {
        Log.i(TAG,"maybeEnableArButton" )
        try{
            val availability = ArCoreApk.getInstance().checkAvailability(activity.applicationContext)
            if (availability.isTransient) {
                // Re-query at 5Hz while compatibility is checked in the background.
                Handler().postDelayed({ maybeEnableArButton() }, 200)
            }
            if (availability.isSupported) {
                debugLog("AR SUPPORTED")
            } else { // Unsupported or unknown.
                debugLog("AR NOT SUPPORTED")
            }
        }catch (ex:Exception){
            Log.i(TAG,"maybeEnableArButton ${ex.localizedMessage}" )
        }

    }*/

    private fun setupLifeCycle(context: Context) {
        activityLifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                debugLog("onActivityCreated")
//                maybeEnableArButton()
            }

            override fun onActivityStarted(activity: Activity) {
                debugLog("onActivityStarted")
            }

            override fun onActivityResumed(activity: Activity) {
                debugLog("onActivityResumed")
                // Subsequent resumes only. The first session start happens in
                // init, because the activity is already resumed by the time
                // this callback is registered.
                resumeFromActivity()
            }

            override fun onActivityPaused(activity: Activity) {
                debugLog("onActivityPaused")
                pauseSessionSafely()
            }

            override fun onActivityStopped(activity: Activity) {
                debugLog("onActivityStopped (Just so you know)")
//                onPause()
            }

            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

            override fun onActivityDestroyed(activity: Activity) {
                debugLog("onActivityDestroyed (Just so you know)")
//                onDestroy()
//                dispose()
            }
        }

        activity.application.registerActivityLifecycleCallbacks(this.activityLifecycleCallbacks)
    }

    private fun onSingleTap(tap: MotionEvent?) {
        debugLog(" onSingleTap")
        if (!lifecycle.acceptsSceneWork) {
            return
        }
        val frame = arSceneView?.arFrame
        if (frame != null) {
            if (tap != null && frame.camera.trackingState == TrackingState.TRACKING) {
                val hitList = frame.hitTest(tap)
                val list = ArrayList<HashMap<String, Any>>()
                for (hit in hitList) {
                    val trackable = hit.trackable
                    if (trackable is Plane && trackable.isPoseInPolygon(hit.hitPose)) {
                        hit.hitPose
                        val distance: Float = hit.distance
                        val translation = hit.hitPose.translation
                        val rotation = hit.hitPose.rotationQuaternion
                        val flutterArCoreHitTestResult = FlutterArCoreHitTestResult(distance, translation, rotation)
                        val arguments = flutterArCoreHitTestResult.toHashMap()
                        list.add(arguments)
                    }
                }
                emitToFlutterSafely("onPlaneTap", list)
            }
        }
    }

    private fun takeScreenshot(call: MethodCall, result: ArCallResult) {
        val scene = requireScene(result) ?: return
        try {
            // Create a bitmap the size of the scene view.
            val bitmap: Bitmap = Bitmap.createBitmap(scene.width, scene.height,
                    Bitmap.Config.ARGB_8888)

            // Create a handler thread to offload the processing of the image.
            val handlerThread = HandlerThread("PixelCopier")
            handlerThread.start()
            PixelCopy.request(scene, bitmap, { copyResult ->
                if (copyResult === PixelCopy.SUCCESS) {
                    try {
                        saveBitmapToDisk(bitmap)
                    } catch (e: IOException) {
                        debugLog("screenshot save failed: ${e.localizedMessage}")
                    }
                }
                handlerThread.quitSafely()
            }, Handler(handlerThread.getLooper()))
            result.success(null)
        } catch (e: Throwable) {
            result.error(
                    "screenshot_failed",
                    e.localizedMessage ?: "Failed to capture a screenshot.",
                    null
            )
        }
    }

    private class CopiedPlane(val bytes: ByteArray, val rowStride: Int, val pixelStride: Int)

    private fun copyPlane(plane: Image.Plane): CopiedPlane {
        val buffer = plane.buffer.duplicate()
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        return CopiedPlane(bytes, plane.rowStride, plane.pixelStride)
    }

    private fun captureSpatialFrame(result: ArCallResult) {
        val view = arSceneView
        val frame = view?.arFrame
        if (view == null || frame == null || frame.camera.trackingState != TrackingState.TRACKING) {
            result.error("tracking_unavailable", "ARCore tracking is not ready", null)
            return
        }
        // ARCore Frame/Image objects expire with the render callback, so every plane is
        // copied to a plain byte array synchronously here. The expensive YUV->NV21
        // rearrangement and JPEG compression run afterwards on a worker thread; only the
        // already-copied bytes are touched there, never the expired Frame/Image.
        try {
                val camera = frame.camera
                val pose = camera.pose
                val intrinsics = camera.imageIntrinsics
                val dimensions = intrinsics.imageDimensions
                val focalLength = intrinsics.focalLength
                val principalPoint = intrinsics.principalPoint
                var cameraTimestamp = frame.timestamp

                var imageWidth = 0
                var imageHeight = 0
                lateinit var yPlane: CopiedPlane
                lateinit var uPlane: CopiedPlane
                lateinit var vPlane: CopiedPlane
                frame.acquireCameraImage().use { image ->
                    cameraTimestamp = image.timestamp
                    imageWidth = image.width
                    imageHeight = image.height
                    yPlane = copyPlane(image.planes[0])
                    uPlane = copyPlane(image.planes[1])
                    vPlane = copyPlane(image.planes[2])
                }

                var depthPlane: CopiedPlane? = null
                var depthWidth = 0
                var depthHeight = 0
                var confidenceBytes: ByteArray? = null
                try {
                    // acquireDepthImage() is deprecated in favour of
                    // acquireDepthImage16Bits(), but that API arrived in ARCore
                    // 1.31 and this module pins com.google.ar:core:1.26.0
                    // alongside the archived Sceneform 1.17.1. Moving to the
                    // 16-bit API requires an ARCore upgrade that Sceneform
                    // constrains, so it stays on the deprecated call until that
                    // dependency work happens.
                    frame.acquireDepthImage().use { depth ->
                        depthPlane = copyPlane(depth.planes[0])
                        depthWidth = depth.width
                        depthHeight = depth.height
                    }
                    frame.acquireRawDepthConfidenceImage().use { confidence ->
                        confidenceBytes = copyPlane(confidence.planes[0]).bytes
                    }
                } catch (_: NotYetAvailableException) {
                    // Depth is an optional enhancement and may lag valid RGB.
                } catch (_: Exception) {
                    // Depth is optional and absence is explicitly represented.
                }

                // A dispose() racing an in-flight capture rejects the task. The
                // pending Dart future must still be completed, or the sampler
                // waits on it forever.
                try {
                    spatialCaptureExecutor.execute {
                    try {
                        val nv21 = yuv420888ToNv21(imageWidth, imageHeight, yPlane, uPlane, vPlane)
                        val rgb = ByteArrayOutputStream().use { stream ->
                            YuvImage(nv21, ImageFormat.NV21, imageWidth, imageHeight, null)
                                .compressToJpeg(Rect(0, 0, imageWidth, imageHeight), 92, stream)
                            stream.toByteArray()
                        }
                        val payload = hashMapOf<String, Any>(
                            "rgb" to rgb,
                            "timestampNanos" to cameraTimestamp,
                            "poseTranslation" to pose.translation.toList(),
                            "poseRotation" to pose.rotationQuaternion.toList(),
                            "intrinsics" to hashMapOf(
                                "width" to dimensions[0],
                                "height" to dimensions[1],
                                "fx" to focalLength[0],
                                "fy" to focalLength[1],
                                "cx" to principalPoint[0],
                                "cy" to principalPoint[1]
                            ),
                            "depthAvailable" to false
                        )
                        val depth = depthPlane
                        if (depth != null) {
                            payload["depth"] = depth.bytes
                            payload["depthWidth"] = depthWidth
                            payload["depthHeight"] = depthHeight
                            payload["depthRowStride"] = depth.rowStride
                            payload["depthPixelStride"] = depth.pixelStride
                            payload["depthAvailable"] = true
                        }
                        confidenceBytes?.let { payload["depthConfidence"] = it }

                        completeOnMain { result.success(payload) }
                    } catch (error: Throwable) {
                        completeOnMain {
                            result.error("capture_failed", error.localizedMessage, null)
                        }
                    }
                    }
                } catch (_: RejectedExecutionException) {
                    completeOnMain {
                        result.error(
                                "capture_cancelled",
                                "The AR session is shutting down.",
                                null
                        )
                    }
                }
        } catch (_: NotYetAvailableException) {
            result.error("frame_not_yet_available", "Camera image is temporarily unavailable", null)
        } catch (error: Throwable) {
                result.error("capture_failed", error.localizedMessage, null)
        }
    }

    private fun yuv420888ToNv21(
        width: Int,
        height: Int,
        yPlane: CopiedPlane,
        uPlane: CopiedPlane,
        vPlane: CopiedPlane
    ): ByteArray {
        val output = ByteArray(width * height * 3 / 2)
        var outputIndex = 0
        for (row in 0 until height) {
            for (column in 0 until width) {
                output[outputIndex++] = yPlane.bytes[row * yPlane.rowStride + column * yPlane.pixelStride]
            }
        }

        for (row in 0 until height / 2) {
            for (column in 0 until width / 2) {
                output[outputIndex++] = vPlane.bytes[row * vPlane.rowStride + column * vPlane.pixelStride]
                output[outputIndex++] = uPlane.bytes[row * uPlane.rowStride + column * uPlane.pixelStride]
            }
        }
        return output
    }

    @Throws(IOException::class)
    fun saveBitmapToDisk(bitmap: Bitmap):String {

//        val now = LocalDateTime.now()
//        now.format(DateTimeFormatter.ofPattern("M/d/y H:m:ss"))
        val now = "rawScreenshot"
        // android/data/com.hswo.mvc_2021.hswo_mvc_2021_flutter_ar/files/
        // activity.applicationContext.getFilesDir().toString() //doesnt work!!
        // Environment.getExternalStorageDirectory()
        val mPath: String =  Environment.getExternalStorageDirectory().toString() + "/DCIM/" + now + ".jpg"
        val mediaFile = File(mPath)
        debugLog(mediaFile.toString())
        //Log.i("path","fileoutputstream opened")
        //Log.i("path",mPath)
        val fileOutputStream = FileOutputStream(mediaFile)
        bitmap.compress(Bitmap.CompressFormat.JPEG, 100, fileOutputStream)
        fileOutputStream.flush()
        fileOutputStream.close()
//        Log.i("path","fileoutputstream closed")
        return mPath
    }

    /**
     * Creates the real AR session, then reports readiness.
     *
     * This used to only wire listeners and return success, so Dart marked the
     * controller ready while no [Session] existed. The session was created
     * exclusively from `Activity.onResume`, but a platform view is built while
     * the activity is *already* resumed, and registering lifecycle callbacks
     * at that point never replays the resume that already happened. On first
     * entry the session was therefore never created and every tracking query
     * answered "not ready".
     *
     * Initialization now performs the whole transaction - permission,
     * availability, session, config, setupSession, resume - and reports
     * success only once the view is genuinely running.
     */
    private fun arScenViewInit(call: MethodCall, result: ArCallResult) {
        debugLog("arScenViewInit")

        when (val outcome = lifecycle.beginInitialize()) {
            is ArLifecycleOutcome.Rejected -> {
                result.error(outcome.code, outcome.message, null)
                return
            }
            ArLifecycleOutcome.NoOp -> {
                // Already running; a remounted view must not build a second
                // session that would fight the first one for the camera.
                result.success(null)
                return
            }
            ArLifecycleOutcome.Proceed -> Unit
        }

        val scene = arSceneView
        if (scene == null) {
            lifecycle.initializeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_SESSION_UNAVAILABLE,
                    "The AR view is not available.",
                    null
            )
            return
        }

        // Flutter owns camera permission and only mounts this view once CAMERA
        // is granted. If it is missing the view reports it rather than raising
        // its own dialog, which used to pause the activity mid-initialization.
        if (!ArCoreUtils.hasCameraPermission(activity)) {
            lifecycle.initializeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_CAMERA_PERMISSION_REQUIRED,
                    "Camera permission is required for AR.",
                    null
            )
            return
        }

        configureListeners(call, scene)

        val session = try {
            ArCoreUtils.createArSession(activity, mUserRequestedInstall, isAugmentedFaces)
        } catch (e: UnavailableUserDeclinedInstallationException) {
            lifecycle.initializeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_INSTALL_DECLINED,
                    "ARCore installation was declined.",
                    null
            )
            return
        } catch (e: UnavailableException) {
            lifecycle.initializeFailed()
            result.error(
                    ArCoreUtils.availabilityCodeFor(e),
                    e.localizedMessage ?: "ARCore is unavailable.",
                    null
            )
            return
        } catch (e: SecurityException) {
            lifecycle.initializeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_CAMERA_PERMISSION_REQUIRED,
                    "Camera permission is required for AR.",
                    null
            )
            return
        } catch (e: Throwable) {
            lifecycle.initializeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_SESSION_UNAVAILABLE,
                    e.localizedMessage ?: "Failed to create the AR session.",
                    null
            )
            return
        }

        if (session == null) {
            // ARCore is installing. Clearing the flag makes the next attempt
            // either return INSTALLED or throw, instead of looping forever.
            mUserRequestedInstall = false
            lifecycle.initializeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_INSTALL_REQUIRED,
                    "ARCore is being installed.",
                    null
            )
            return
        }

        try {
            val config = Config(session)
            if (isAugmentedFaces) {
                config.augmentedFaceMode = Config.AugmentedFaceMode.MESH3D
            }
            config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            config.focusMode = Config.FocusMode.AUTO
            if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                config.depthMode = Config.DepthMode.AUTOMATIC
            }
            session.configure(config)
            scene.setupSession(session)
        } catch (e: Throwable) {
            lifecycle.initializeFailed()
            closeSessionQuietly(session)
            result.error(
                    ArCoreSessionMapping.CODE_SESSION_UNAVAILABLE,
                    e.localizedMessage ?: "Failed to configure the AR session.",
                    null
            )
            return
        }

        // The first resume happens here rather than waiting for an activity
        // callback that will not arrive, since the activity is already resumed.
        try {
            scene.resume()
        } catch (e: CameraNotAvailableException) {
            lifecycle.initializeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_CAMERA_UNAVAILABLE,
                    "The camera is currently unavailable.",
                    null
            )
            return
        } catch (e: Throwable) {
            lifecycle.initializeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_SESSION_UNAVAILABLE,
                    e.localizedMessage ?: "Failed to start the AR session.",
                    null
            )
            return
        }

        lifecycle.initializeSucceeded()
        debugLog("AR session running")
        result.success(null)
    }

    /** Wires tap, update and plane-renderer behaviour requested by Flutter. */
    private fun configureListeners(call: MethodCall, scene: ArSceneView) {
        val enableTapRecognizer: Boolean? = call.argument("enableTapRecognizer")
        if (enableTapRecognizer == true) {
            scene.scene?.setOnTouchListener { hitTestResult: HitTestResult, event: MotionEvent? ->
                if (isDisposed) {
                    return@setOnTouchListener false
                }
                if (hitTestResult.node != null) {
                    debugLog(" onNodeTap " + hitTestResult.node?.name)
                    emitToFlutterSafely(
                            "onNodeTap",
                            publicNodeNameForTap(hitTestResult.node),
                    )
                    return@setOnTouchListener true
                }
                val handled = event?.let { gestureDetector.onTouchEvent(it) } ?: false
                return@setOnTouchListener handled
            }
        }

        val enableUpdateListener: Boolean? = call.argument("enableUpdateListener")
        if (enableUpdateListener == true) {
            scene.scene?.addOnUpdateListener(sceneUpdateListener)
        }

        val enablePlaneRenderer: Boolean? = call.argument("enablePlaneRenderer")
        if (enablePlaneRenderer == false) {
            debugLog(" The plane renderer (enablePlaneRenderer) is disabled")
            scene.planeRenderer.isVisible = false
        }
    }

    /** Releases a session that failed after construction. */
    private fun closeSessionQuietly(session: Session) {
        try {
            session.close()
        } catch (e: Throwable) {
            debugLog("session close failed: ${e.localizedMessage}")
        }
    }

    fun addNodeWithAnchor(
        flutterArCoreNode: FlutterArCoreNode,
        parameters: HashMap<String, Any>,
        result: ArCallResult,
    ) {

        // Callers reach this through requireScene, but the bare `return` here
        // abandoned the call outright, so it stays defended at the source.
        if (requireScene(result) == null) {
            return
        }

        RenderableCustomFactory.makeRenderable(activity.applicationContext, flutterArCoreNode) { renderable, t ->
            if (t != null) {
                result.error("Make Renderable Error", t.localizedMessage, null)
                return@makeRenderable
            }
            val transform = AnchoredPlacementTransforms.initial(
                flutterArCoreNode.getPosition(),
                flutterArCoreNode.getRotation(),
                (parameters["localYawRadians"] as? Number)?.toDouble() ?: 0.0,
                (parameters["localScale"] as? Number)?.toDouble() ?: 1.0,
            )
            val myAnchor = arSceneView?.session?.createAnchor(
                Pose(transform.anchorTranslation, transform.anchorRotation),
            )
            if (myAnchor != null) {
                val anchorNode = AnchorNode(myAnchor)
                anchorNode.name = flutterArCoreNode.name
                val content = Node()
                content.name = "${anchorNode.name}$contentNodeSuffix"
                content.renderable = renderable
                content.localPosition = com.google.ar.sceneform.math.Vector3(
                    transform.contentTranslation[0],
                    transform.contentTranslation[1],
                    transform.contentTranslation[2],
                )
                content.localRotation = com.google.ar.sceneform.math.Quaternion(
                    transform.contentRotation[0],
                    transform.contentRotation[1],
                    transform.contentRotation[2],
                    transform.contentRotation[3],
                )
                content.localScale = com.google.ar.sceneform.math.Vector3(
                    transform.contentScale[0],
                    transform.contentScale[1],
                    transform.contentScale[2],
                )
                content.setParent(anchorNode)

                debugLog("addNodeWithAnchor inserted ${anchorNode.name}")
                attachNodeToParent(anchorNode, flutterArCoreNode.parentNodeName)

                for (node in flutterArCoreNode.children) {
                    node.parentNodeName = flutterArCoreNode.name
                    onAddNode(node, null)
                }
            }
            result.success(null)
        }
    }

    fun onAddNode(flutterArCoreNode: FlutterArCoreNode, result: ArCallResult?) {

        debugLog(flutterArCoreNode.toString())
        NodeFactory.makeNode(activity.applicationContext, flutterArCoreNode, debug) { node, throwable ->

            debugLog("onAddNode inserted ${node?.name}")

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
            }

        }
        result?.success(null)
    }

    fun attachNodeToParent(node: Node?, parentNodeName: String?) {
        if (parentNodeName != null) {
            debugLog(parentNodeName);
            val parentNode: Node? = arSceneView?.scene?.findByName(parentNodeName)
            parentNode?.addChild(node)
        } else {
            debugLog("addNodeToSceneWithGeometry: NOT PARENT_NODE_NAME")
            arSceneView?.scene?.addChild(node)
        }
    }

    fun removeNode(name: String, result: ArCallResult) {
        val node = arSceneView?.scene?.findByName(name)
        if (node != null) {
            if (node is AnchorNode) {
                node.anchor?.detach()
            }
            node.setParent(null)
            debugLog("removed ${node.name}")
        }

        result.success(null)
    }

    /**
     * Updates a stable anchored placement without mixing world and local space.
     *
     * A placement preview is adjusted continuously — pinch to scale, drag to
     * rotate, tap to reposition — and removing and re-adding the node for every
     * change reloads its renderable and makes the artwork blink. Mutating the
     * live node keeps the preview stable and matches what the user is doing.
     *
     * A supplied anchor pose replaces the immutable ARCore anchor. Local yaw
     * and scale apply only to the content child. Omitted components are left
     * untouched.
     */
    fun updateAnchoredNode(call: MethodCall, result: ArCallResult) {
        val name = call.argument<String>("name")
        var anchorNode = findAnchorNode(name)
        if (anchorNode == null) {
            debugLog("updateAnchoredNode: no anchor named $name")
            result.success(false)
            return
        }

        val anchorPosition = DecodableUtils.parseVector3(
            call.argument<HashMap<String, Double>>("anchorPosition"),
        )
        val anchorRotation = DecodableUtils.parseQuaternion(
            call.argument<HashMap<String, Double>>("anchorRotation"),
        )
        if ((anchorPosition == null) != (anchorRotation == null)) {
            result.error("invalid_anchor_pose", "Anchor position and rotation must be supplied together", null)
            return
        }
        if (anchorPosition != null && anchorRotation != null) {
            anchorNode = replaceAnchorPose(
                anchorNode,
                floatArrayOf(anchorPosition.x, anchorPosition.y, anchorPosition.z),
                floatArrayOf(anchorRotation.x, anchorRotation.y, anchorRotation.z, anchorRotation.w),
            )
            if (anchorNode == null) {
                result.success(false)
                return
            }
        }

        val localYaw = call.argument<Number>("localYawRadians")?.toDouble()
        val localScale = call.argument<Number>("localScale")?.toDouble()
        if ((localYaw != null && !localYaw.isFinite()) ||
            (localScale != null && (!localScale.isFinite() || localScale <= 0.0))) {
            result.error("invalid_content_transform", "Content yaw and scale must be finite; scale must be positive", null)
            return
        }
        val content = findContentNode(anchorNode)
        if (content == null) {
            result.success(false)
            return
        }
        val current = AnchoredPlacementTransform(
            floatArrayOf(), floatArrayOf(), floatArrayOf(0f, 0f, 0f),
            floatArrayOf(content.localRotation.x, content.localRotation.y, content.localRotation.z, content.localRotation.w),
            floatArrayOf(content.localScale.x, content.localScale.y, content.localScale.z),
        )
        val next = AnchoredPlacementTransforms.withContent(current, localYaw, localScale)
        content.localPosition = com.google.ar.sceneform.math.Vector3(
            next.contentTranslation[0], next.contentTranslation[1], next.contentTranslation[2],
        )
        content.localRotation = com.google.ar.sceneform.math.Quaternion(
            next.contentRotation[0], next.contentRotation[1], next.contentRotation[2], next.contentRotation[3],
        )
        content.localScale = com.google.ar.sceneform.math.Vector3(
            next.contentScale[0], next.contentScale[1], next.contentScale[2],
        )
        result.success(true)
    }

    /** Suffix identifying the content child created beneath an AnchorNode. */
    private val contentNodeSuffix = "#content"

    private fun findAnchorNode(name: String?): AnchorNode? =
        name?.let { arSceneView?.scene?.findByName(it) as? AnchorNode }

    private fun findContentNode(anchor: AnchorNode): Node? =
        anchor.children.firstOrNull { it.name == "${anchor.name}$contentNodeSuffix" }

    /**
     * Keeps Flutter's node-tap contract independent of the internal content
     * child used by anchored placement previews.
     */
    private fun publicNodeNameForTap(node: Node?): String? {
        var current = node
        while (current != null) {
            if (current is AnchorNode) {
                return current.name
            }
            current = current.parent
        }
        return node?.name
    }

    /** Replaces an immutable ARCore anchor while retaining its content node. */
    private fun replaceAnchorPose(
        anchorNode: AnchorNode,
        translation: FloatArray,
        rotation: FloatArray,
    ): AnchorNode? {
        val content = findContentNode(anchorNode) ?: return null
        val replacementAnchor = arSceneView?.session?.createAnchor(Pose(translation, rotation)) ?: return null
        val parent = anchorNode.parent
        content.setParent(null)
        anchorNode.setParent(null)
        anchorNode.anchor?.detach()
        return AnchorNode(replacementAnchor).also { replacement ->
            replacement.name = anchorNode.name
            replacement.setParent(parent)
            content.setParent(replacement)
        }
    }

    /**
     * Returns the node currently carrying the renderable.
     */
    private fun renderableHolderFor(node: Node): Node =
        (node as? AnchorNode)?.let(::findContentNode) ?: node

    fun updateRotation(call: MethodCall, result: ArCallResult) {
        val name = call.argument<String>("name")
        // An unchecked `as RotatingNode` threw whenever the node was missing
        // or of another type, which during teardown meant a crash rather than
        // a reply.
        val node = arSceneView?.scene?.findByName(name) as? RotatingNode
        if (node == null) {
            debugLog("updateRotation: no rotating node named $name")
            result.success(false)
            return
        }
        debugLog("rotating node:  $node")
        val degreesPerSecond = call.argument<Double?>("degreesPerSecond")
        debugLog("rotating value:  $degreesPerSecond")
        if (degreesPerSecond != null) {
            debugLog("rotating value:  ${node.degreesPerSecond}")
            node.degreesPerSecond = degreesPerSecond.toFloat()
        }
        result.success(null)
    }

    fun updateMaterials(call: MethodCall, result: ArCallResult) {
        val name = call.argument<String>("name")
        val materials = call.argument<ArrayList<HashMap<String, *>>>("materials")
        if (name.isNullOrBlank() || materials.isNullOrEmpty()) {
            result.error("invalid_materials", "A node name and at least one material are required", null)
            return
        }
        // Follow the renderable: once a placement has been transformed its
        // content lives on a child beneath the anchor, so looking only at the
        // named node would silently stop updating materials.
        val node = arSceneView?.scene?.findByName(name)?.let { renderableHolderFor(it) }
        val oldMaterial = node?.renderable?.material?.makeCopy()
        if (oldMaterial != null) {
            val material = MaterialCustomFactory.updateMaterial(oldMaterial, materials[0])
            node.renderable?.material = material
        }
        result.success(null)
    }

    /**
     * The view handed to Flutter.
     *
     * Backed by its own reference because [arSceneView] is cleared during
     * teardown, and the host can still query the view while unmounting; the
     * old `arSceneView as View` threw once that field went null.
     */
    override fun getView(): View {
        return hostView
    }

    /**
     * Tears the platform view down. Idempotent: Flutter can call dispose()
     * while a capture is still in flight, and the host may dispose the view
     * again during activity teardown.
     */
    /**
     * Platform-view teardown.
     *
     * Flutter's explicit `dispose` call and the host's own disposal can race,
     * so the ordering matters and lives in [disposeSession].
     */
    override fun dispose() {
        disposeSession()
    }

    /**
     * Tears the session down exactly once, settling everything in flight.
     *
     * Order is deliberate. Outstanding calls are completed *before* the
     * channel handler is detached, because a reply through a detached channel
     * never reaches Dart - which is how awaiting `dispose()` used to hang a
     * camera handoff forever.
     */
    private fun disposeSession(exempt: ArCallResult? = null) {
        if (!lifecycle.beginDispose()) {
            return
        }

        // Unregister exactly once. Registering on every platform-view creation
        // without ever unregistering leaked one callbacks instance per AR mode
        // transition, and each leaked instance kept driving onPause/onResume on
        // a view that no longer existed.
        if (this::activityLifecycleCallbacks.isInitialized) {
            try {
                activity.application
                        .unregisterActivityLifecycleCallbacks(activityLifecycleCallbacks)
            } catch (e: Exception) {
                debugLog("unregisterActivityLifecycleCallbacks failed: ${e.localizedMessage}")
            }
        }

        // Stop accepting new work before tearing the scene down, so a queued
        // capture cannot touch a destroyed session.
        spatialCaptureExecutor.shutdown()

        // Settle every call still awaiting a reply. A capture mid-encode has a
        // Dart future waiting on it; dropping it stalled the sampler.
        pendingCalls.cancelAll(
                ArSessionLifecycle.CODE_SESSION_DISPOSED,
                "The AR session is shutting down.",
                except = exempt
        )

        try {
            releaseScene()
        } finally {
            // Teardown is complete, so answer the call that drove it. Dart
            // treats a completed dispose as "the camera is released", and it
            // has to be answered before the handler goes away.
            exempt?.success(null)
            try {
                methodChannel.setMethodCallHandler(null)
            } catch (e: Exception) {
                debugLog("setMethodCallHandler(null) failed: ${e.localizedMessage}")
            }
            lifecycle.disposeFinished()
        }
    }

    /** Pauses, detaches and destroys the scene view and its session. */
    private fun releaseScene() {
        val scene = arSceneView ?: return
        try {
            scene.scene?.removeOnUpdateListener(sceneUpdateListener)
            scene.scene?.removeOnUpdateListener(faceSceneUpdateListener)
            scene.scene?.setOnTouchListener(null)
        } catch (e: Exception) {
            debugLog("listener detach failed: ${e.localizedMessage}")
        }

        for (faceNode in faceNodeMap.values) {
            try {
                faceNode.setParent(null)
            } catch (e: Exception) {
                debugLog("face node detach failed: ${e.localizedMessage}")
            }
        }
        faceNodeMap.clear()

        try {
            scene.pause()
        } catch (e: Exception) {
            debugLog("pause during teardown failed: ${e.localizedMessage}")
        }

        try {
            scene.destroy()
        } catch (e: Exception) {
            debugLog("destroy failed: ${e.localizedMessage}")
        }

        arSceneView = null
    }

    /**
     * Resumes the session if that is legal right now.
     *
     * Activity resume and an explicit Flutter resume can arrive together, and
     * calling `ArSceneView.resume()` twice - or on a torn-down view - throws on
     * the main thread. The lifecycle decides; this only performs.
     */
    private fun resumeSessionSafely(result: ArCallResult) {
        when (val outcome = lifecycle.requestResume()) {
            is ArLifecycleOutcome.Rejected -> {
                result.error(outcome.code, outcome.message, null)
                return
            }
            ArLifecycleOutcome.NoOp -> {
                result.success(null)
                return
            }
            ArLifecycleOutcome.Proceed -> Unit
        }

        val scene = arSceneView
        if (scene == null) {
            lifecycle.resumeFailed()
            result.error(
                    ArSessionLifecycle.CODE_SESSION_DISPOSED,
                    "The AR session is no longer available.",
                    null
            )
            return
        }

        try {
            scene.resume()
        } catch (e: CameraNotAvailableException) {
            // Another owner briefly holding the camera is recoverable. Closing
            // the Flutter activity over it destroyed unrelated app state and
            // looked to the user like a crash.
            lifecycle.resumeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_CAMERA_UNAVAILABLE,
                    "The camera is currently unavailable.",
                    null
            )
            return
        } catch (e: Throwable) {
            lifecycle.resumeFailed()
            result.error(
                    ArCoreSessionMapping.CODE_SESSION_UNAVAILABLE,
                    e.localizedMessage ?: "Failed to resume the AR session.",
                    null
            )
            return
        }

        lifecycle.resumeSucceeded()
        result.success(null)
    }

    /** Pauses the session if it is running; never an error. */
    private fun pauseSessionSafely() {
        if (lifecycle.requestPause() != ArLifecycleOutcome.Proceed) {
            return
        }
        try {
            arSceneView?.pause()
        } catch (e: Throwable) {
            debugLog("pause failed: ${e.localizedMessage}")
        }
    }

    /**
     * Resume driven by the activity, with no Flutter call to answer.
     *
     * A recoverable failure is reported as a session event rather than thrown,
     * so a backgrounded-and-restored AR screen degrades into a retryable state.
     */
    private fun resumeFromActivity() {
        if (lifecycle.requestResume() != ArLifecycleOutcome.Proceed) {
            return
        }
        val scene = arSceneView
        if (scene == null) {
            lifecycle.resumeFailed()
            return
        }
        try {
            scene.resume()
            lifecycle.resumeSucceeded()
        } catch (e: CameraNotAvailableException) {
            lifecycle.resumeFailed()
            reportSessionError(
                    ArCoreSessionMapping.CODE_CAMERA_UNAVAILABLE,
                    "The camera is currently unavailable."
            )
        } catch (e: Throwable) {
            lifecycle.resumeFailed()
            reportSessionError(
                    ArCoreSessionMapping.CODE_SESSION_UNAVAILABLE,
                    e.localizedMessage ?: "Failed to resume the AR session."
            )
        }
    }

    /* private fun tryPlaceNode(tap: MotionEvent?, frame: Frame) {
        if (tap != null && frame.camera.trackingState == TrackingState.TRACKING) {
            for (hit in frame.hitTest(tap)) {
                val trackable = hit.trackable
                if (trackable is Plane && trackable.isPoseInPolygon(hit.hitPose)) {
                    // Create the Anchor.
                    val anchor = hit.createAnchor()
                    val anchorNode = AnchorNode(anchor)
                    anchorNode.setParent(arSceneView?.scene)

                    ModelRenderable.builder()
                            .setSource(activity.applicationContext, Uri.parse("TocoToucan.sfb"))
                            .build()
                            .thenAccept { renderable ->
                                val node = Node()
                                node.renderable = renderable
                                anchorNode.addChild(node)
                            }.exceptionally { throwable ->
                                Log.e(TAG, "Unable to load Renderable.", throwable);
                                return@exceptionally null
                            }
                }
            }
        }

    }*/

    /*    fun updatePosition(call: MethodCall, result: ArCallResult) {
        val name = call.argument<String>("name")
        val node = arSceneView?.scene?.findByName(name)
        node?.localPosition = parseVector3(call.arguments as HashMap<String, Any>)
        result.success(null)
    }*/
}
