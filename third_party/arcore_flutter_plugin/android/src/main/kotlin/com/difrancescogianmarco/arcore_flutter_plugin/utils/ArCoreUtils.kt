package com.difrancescogianmarco.arcore_flutter_plugin.utils

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.annotation.Nullable
import androidx.core.content.ContextCompat
import com.google.ar.core.exceptions.*
import java.util.*
import androidx.core.content.ContextCompat.getSystemService
import android.os.Build.VERSION_CODES
import com.google.ar.core.*
import com.google.ar.core.CameraConfig


class ArCoreUtils {


    companion object {

        private val TAG = ArCoreUtils::class.java.name
        private val MIN_OPENGL_VERSION = 3.0
        private val CAMERA_PERMISSION_CODE = 0
        private val CAMERA_PERMISSION = Manifest.permission.CAMERA

        /**
         * Creates an ARCore session. This checks for the CAMERA permission, and if granted, checks the
         * state of the ARCore installation. If there is a problem an exception is thrown. Care must be
         * taken to update the installRequested flag as needed to avoid an infinite checking loop. It
         * should be set to true if null is returned from this method, and called again when the
         * application is resumed.
         *
         * @param activity - the activity currently active.
         * @param installRequested - the indicator for ARCore that when checking the state of ARCore, if
         * an installation was already requested. This is true if this method previously returned
         * null. and the camera permission has been granted.
         */
        @Throws(UnavailableException::class)
        fun createArSession(activity: Activity, userRequestedInstall: Boolean, isFrontCamera: Boolean): Session? {
            var session: Session? = null
            // if we have the camera permission, create the session
            if (hasCameraPermission(activity)) {
                session = when (ArCoreApk.getInstance().requestInstall(activity, userRequestedInstall)) {
                    ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                        Log.i(TAG, "ArCore INSTALL REQUESTED")
                        null
                    }
                    //                    ArCoreApk.InstallStatus.INSTALLED -> {}
                    else -> {
                        if (isFrontCamera) {
                            Session(activity, EnumSet.of(Session.Feature.FRONT_CAMERA))
                        } else {
                            Session(activity)
                        }
                    }
                }
                session?.let {
                    // Create a camera config filter for the session.
                    val filter = CameraConfigFilter(it)

                    // Return only camera configs that target 30 fps camera capture frame rate.
                    filter.setTargetFps(EnumSet.of(CameraConfig.TargetFps.TARGET_FPS_30))

                    // Return only camera configs that will not use the depth sensor.
                    filter.setDepthSensorUsage(EnumSet.of(CameraConfig.DepthSensorUsage.DO_NOT_USE))

                    // Get list of configs that match filter settings.
                    // In this case, this list is guaranteed to contain at least one element,
                    // because both TargetFps.TARGET_FPS_30 and DepthSensorUsage.DO_NOT_USE
                    // are supported on all ARCore supported devices.
                    val cameraConfigList = it.getSupportedCameraConfigs(filter)

                    // Use element 0 from the list of returned camera configs. This is because
                    // it contains the camera config that best matches the specified filter
                    // settings.
                    it.cameraConfig = cameraConfigList[0]
                }

            }
            return session
        }

        /** Check to see we have the necessary permissions for this app, and ask for them if we don't.  */
        fun requestCameraPermission(activity: Activity, requestCode: Int) {
            ActivityCompat.requestPermissions(
                    activity, arrayOf(Manifest.permission.CAMERA), requestCode)
        }

        /** Check to see we have the necessary permissions for this app.  */
        fun hasCameraPermission(activity: Activity): Boolean {
            return ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        }

        /** Check to see if we need to show the rationale for this permission.  */
        fun shouldShowRequestPermissionRationale(activity: Activity): Boolean {
            return ActivityCompat.shouldShowRequestPermissionRationale(
                    activity, Manifest.permission.CAMERA)
        }

        /** Launch Application Setting to grant permission.  */
        fun launchPermissionSettings(activity: Activity) {
            val intent = Intent()
            intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
            intent.data = Uri.fromParts("package", activity.packageName, null)
            activity.startActivity(intent)
        }

        /**
         * Logs an AR error.
         *
         * User-facing wording belongs to Flutter, which localizes it and
         * attaches an action. The platform Toast this used to raise was
         * untranslated, unattributable and appeared over unrelated screens.
         */
        fun displayError(
                context: Context, errorMsg: String, @Nullable problem: Throwable?) {
            val tag = context.javaClass.simpleName
            if (problem != null) {
                Log.e(tag, errorMsg, problem)
            } else {
                Log.e(tag, errorMsg)
            }
        }

        /**
         * Maps an ARCore availability failure to a stable code for Flutter.
         *
         * Flutter owns the user-facing wording so install, update, and
         * unsupported-device states can be localized and given an action,
         * rather than surfaced as an untranslated platform Toast.
         */
        fun availabilityCodeFor(sessionException: UnavailableException): String {
            // Delegates to ArCoreSessionMapping so the mapping itself is unit
            // testable on the JVM without the ARCore runtime.
            return com.difrancescogianmarco.arcore_flutter_plugin
                    .ArCoreSessionMapping
                    .availabilityCode(sessionException.javaClass.simpleName)
        }

        /**
         * Logs an availability failure and returns its stable code.
         *
         * Flutter turns the code into localized, actionable guidance, so no
         * platform Toast is raised here.
         */
        fun handleSessionException(
                activity: Activity, sessionException: UnavailableException): String {
            val code = availabilityCodeFor(sessionException)
            Log.e(TAG, "ARCore unavailable ($code): $sessionException")
            return code
        }

        /**
         * Whether Sceneform can run on this device.
         *
         * Sceneform requires Android N and OpenGL ES 3.0. This previously
         * called `activity.finish()` on failure, which tore down the whole
         * single-activity Flutter app - an unsupported device closed the
         * entire product rather than one screen. The caller now reports a
         * typed unsupported-device state and the app stays alive.
         */
        fun isSupportedDevice(activity: Activity): Boolean {
            if (Build.VERSION.SDK_INT < VERSION_CODES.N) {
                Log.e(TAG, "Sceneform requires Android N or later")
                return false
            }
            val openGlVersionString = (activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
                    .deviceConfigurationInfo
                    .glEsVersion
            if (java.lang.Double.parseDouble(openGlVersionString) < MIN_OPENGL_VERSION) {
                Log.e(TAG, "Sceneform requires OpenGL ES 3.0 or later")
                return false
            }
            return true
        }
    }
}