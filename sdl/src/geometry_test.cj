/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

@Test
func colorFactoryClampsChannels(): Unit {
    let color = Color.rgba(-20, 42, 999, 300)

    @Expect(color.r, UInt8(0))
    @Expect(color.g, UInt8(42))
    @Expect(color.b, UInt8(255))
    @Expect(color.a, UInt8(255))
}

@Test
func rectHelpersPreserveExpectedGeometry(): Unit {
    let rect = Rect(10.0, 20.0, 100.0, 50.0)

    @Expect(rect.right(), Float32(110.0))
    @Expect(rect.bottom(), Float32(70.0))
    @Expect(rect.centerX(), Float32(60.0))
    @Expect(rect.centerY(), Float32(45.0))
    @Expect(rect.contains(10.0, 20.0))
    @Expect(rect.contains(110.0, 70.0))
    @Expect(!rect.contains(111.0, 70.0))
}

@Test
func insetsShrinkWithoutNegativeSize(): Unit {
    let rect = Rect(0.0, 0.0, 12.0, 8.0).inset(8.0)

    @Expect(rect.x, Float32(8.0))
    @Expect(rect.y, Float32(8.0))
    @Expect(rect.w, Float32(0.0))
    @Expect(rect.h, Float32(0.0))
}

@Test
func clampF32HonorsBounds(): Unit {
    @Expect(clampF32(-3.0, 0.0, 2.0), Float32(0.0))
    @Expect(clampF32(1.5, 0.0, 2.0), Float32(1.5))
    @Expect(clampF32(5.0, 0.0, 2.0), Float32(2.0))
}

@Test
func pointConvertsToSdlFPoint(): Unit {
    let raw = Point(12.5, 18.25).toSdlFPoint()

    @Expect(raw.x, Float32(12.5))
    @Expect(raw.y, Float32(18.25))
}

@Test
func pointConvertsToSdlPoint(): Unit {
    let raw = Point(12.5, 18.25).toSdlPoint()

    @Expect(raw.x, Int32(12))
    @Expect(raw.y, Int32(18))
}
