package cui.controls

import sdl.{Rect, Renderer, Size, UiEvent, MouseButton}
import cui.core.{Theme, UiContext}

private func approxEq(a: Float32, b: Float32): Bool {
    let d = a - b
    (if (d < 0.0) {
        -d
    } else {
        d
    }) < 0.6
}

private func prTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 400.0
    ctx.viewportHeight = 400.0
    ctx
}

@Test
func clampFractionClamps(): Unit {
    @Expect(approxEq(clampFraction(-0.5), 0.0))
    @Expect(approxEq(clampFraction(1.5), 1.0))
    @Expect(approxEq(clampFraction(0.3), 0.3))
}

@Test
func ringArcQuarterEndsAtRight(): Unit {
    let arc = ringArcPoints(100.0, 100.0, 50.0, 0.25)
    @Expect(arc.size, 17) // 16 segments + 1
    // Starts at the top (12 o'clock).
    @Expect(approxEq(arc[0].x, 100.0))
    @Expect(approxEq(arc[0].y, 50.0))
    // A clockwise quarter turn ends at 3 o'clock.
    let last = arc[arc.size - 1]
    @Expect(approxEq(last.x, 150.0))
    @Expect(approxEq(last.y, 100.0))
}

@Test
func ringArcHalfEndsAtBottom(): Unit {
    let arc = ringArcPoints(100.0, 100.0, 50.0, 0.5)
    let last = arc[arc.size - 1]
    @Expect(approxEq(last.x, 100.0))
    @Expect(approxEq(last.y, 150.0)) // 6 o'clock
}

@Test
func ringArcFullReturnsToTop(): Unit {
    let arc = ringArcPoints(100.0, 100.0, 50.0, 1.0)
    @Expect(arc.size, 65) // 64 segments + 1
    let last = arc[arc.size - 1]
    @Expect(approxEq(last.x, 100.0))
    @Expect(approxEq(last.y, 50.0)) // back to the top
}

@Test
func progressRingMeasuresToDiameter(): Unit {
    let ctx = prTestContext()
    let ring = ProgressRing(0.5, diameter: 80.0)
    let size = ring.measure(ctx, Size(200.0, 200.0))
    let expected: Float32 = 80.0
    @Expect(size.w, expected)
    @Expect(size.h, expected)
    // Pure display: no event is consumed.
    ring.layout(ctx, Rect(0.0, 0.0, 80.0, 80.0))
    @Expect(!ring.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 40.0)))
}
