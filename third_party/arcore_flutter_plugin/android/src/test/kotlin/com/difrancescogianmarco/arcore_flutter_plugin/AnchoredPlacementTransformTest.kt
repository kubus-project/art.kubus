package com.difrancescogianmarco.arcore_flutter_plugin

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.math.PI

class AnchoredPlacementTransformTest {
    private val positionP = floatArrayOf(1f, 0f, -2f)
    private val positionQ = floatArrayOf(3f, 0.5f, -4f)
    private val positionR = floatArrayOf(-1f, 1f, -3f)
    private val hitRotation = floatArrayOf(0f, 0.2f, 0f, 0.98f)

    @Test
    fun `initial content starts at local origin beneath hit anchor`() {
        val state = AnchoredPlacementTransforms.initial(positionP, hitRotation, 0.0, 1.0)

        assertArrayEquals(positionP, state.anchorTranslation, 0f)
        assertArrayEquals(hitRotation, state.anchorRotation, 0f)
        assertArrayEquals(floatArrayOf(0f, 0f, 0f), state.contentTranslation, 0f)
    }

    @Test
    fun `scale and yaw preserve anchor position`() {
        val initial = AnchoredPlacementTransforms.initial(positionP, hitRotation, 0.0, 1.0)
        val adjusted = AnchoredPlacementTransforms.withContent(initial, PI / 2, 2.0)

        assertArrayEquals(positionP, adjusted.anchorTranslation, 0f)
        assertArrayEquals(floatArrayOf(0f, 0f, 0f), adjusted.contentTranslation, 0f)
        assertArrayEquals(floatArrayOf(2f, 2f, 2f), adjusted.contentScale, 0f)
        assertEquals(0.70710677f, adjusted.contentRotation[1], 0.00001f)
    }

    @Test
    fun `reposition replaces anchor without accumulating world position locally`() {
        val initial = AnchoredPlacementTransforms.initial(positionP, hitRotation, PI / 4, 1.5)
        val movedQ = AnchoredPlacementTransforms.reposition(initial, positionQ, hitRotation)
        val movedR = AnchoredPlacementTransforms.reposition(movedQ, positionR, hitRotation)

        assertArrayEquals(positionQ, movedQ.anchorTranslation, 0f)
        assertArrayEquals(positionR, movedR.anchorTranslation, 0f)
        assertArrayEquals(floatArrayOf(0f, 0f, 0f), movedR.contentTranslation, 0f)
        assertArrayEquals(initial.contentScale, movedR.contentScale, 0f)
        assertArrayEquals(initial.contentRotation, movedR.contentRotation, 0f)
    }
}
