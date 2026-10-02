package com.difrancescogianmarco.arcore_flutter_plugin

import kotlin.math.cos
import kotlin.math.sin

/** Pure coordinate-space contract used by the anchored placement bridge. */
data class AnchoredPlacementTransform(
    val anchorTranslation: FloatArray,
    val anchorRotation: FloatArray,
    val contentTranslation: FloatArray,
    val contentRotation: FloatArray,
    val contentScale: FloatArray,
)

object AnchoredPlacementTransforms {
    private val localOrigin = floatArrayOf(0f, 0f, 0f)

    fun initial(
        anchorTranslation: FloatArray,
        anchorRotation: FloatArray,
        localYawRadians: Double,
        localScale: Double,
    ) = AnchoredPlacementTransform(
        anchorTranslation = anchorTranslation.copyOf(),
        anchorRotation = anchorRotation.copyOf(),
        contentTranslation = localOrigin.copyOf(),
        contentRotation = yawQuaternion(localYawRadians),
        contentScale = uniformScale(localScale),
    )

    fun reposition(
        current: AnchoredPlacementTransform,
        anchorTranslation: FloatArray,
        anchorRotation: FloatArray,
    ) = current.copy(
        anchorTranslation = anchorTranslation.copyOf(),
        anchorRotation = anchorRotation.copyOf(),
        // Repositioning does not create or accumulate a child-local offset.
        contentTranslation = localOrigin.copyOf(),
    )

    fun withContent(
        current: AnchoredPlacementTransform,
        localYawRadians: Double?,
        localScale: Double?,
    ) = current.copy(
        contentTranslation = localOrigin.copyOf(),
        contentRotation = localYawRadians?.let(::yawQuaternion)
            ?: current.contentRotation.copyOf(),
        contentScale = localScale?.let(::uniformScale) ?: current.contentScale.copyOf(),
    )

    fun yawQuaternion(yawRadians: Double): FloatArray {
        val half = yawRadians / 2.0
        return floatArrayOf(0f, sin(half).toFloat(), 0f, cos(half).toFloat())
    }

    private fun uniformScale(scale: Double): FloatArray {
        val value = scale.toFloat()
        return floatArrayOf(value, value, value)
    }
}
