package cui.core

import sdl.{Key, MouseButton, Rect, Size, UiEvent}

// A leaf that reports a fixed focus id, so a container's focus-ring order can be inspected.
private class FocusIdProbe <: Widget {
    private let id: String

    init(id: String) {
        this.id = id
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }
}

private func approx(actual: Float32, expected: Float32): Bool {
    let delta = actual - expected
    delta < 0.001 && delta > -0.001
}

@Test
func splitFirstExtentSplitsContentByRatio(): Unit {
    // 208 available - 8 divider = 200 content; half of it is the first pane.
    @Expect(approx(splitFirstExtent(0.5, 208.0, 8.0, 0.0, 0.0), 100.0))
    @Expect(approx(splitFirstExtent(0.25, 208.0, 8.0, 0.0, 0.0), 50.0))
    // Ratio is clamped into [0, 1] before use.
    @Expect(approx(splitFirstExtent(2.0, 208.0, 8.0, 0.0, 0.0), 200.0))
    @Expect(approx(splitFirstExtent(-1.0, 208.0, 8.0, 0.0, 0.0), 0.0))
}

@Test
func splitFirstExtentHonoursPaneMinimums(): Unit {
    // A tiny ratio still leaves the first pane its minimum...
    @Expect(approx(splitFirstExtent(0.0, 208.0, 8.0, 40.0, 40.0), 40.0))
    // ...and a huge ratio still reserves the second pane its minimum (200 - 40).
    @Expect(approx(splitFirstExtent(1.0, 208.0, 8.0, 40.0, 40.0), 160.0))
}

@Test
func clampSplitExtentFallsBackToProportionalWhenMinimumsDoNotFit(): Unit {
    // 100 content cannot hold both 80 minimums; the constraint is dropped and only content bounds.
    @Expect(approx(clampSplitExtent(30.0, 100.0, 80.0, 80.0), 30.0))
    @Expect(approx(clampSplitExtent(140.0, 100.0, 80.0, 80.0), 100.0))
    // Degenerate content yields a zero extent rather than a negative one.
    @Expect(approx(clampSplitExtent(50.0, 0.0, 10.0, 10.0), 0.0))
}

@Test
func splitRatioForExtentInvertsExtent(): Unit {
    @Expect(approx(splitRatioForExtent(150.0, 208.0, 8.0), 0.75))
    @Expect(approx(splitRatioForExtent(0.0, 208.0, 8.0), 0.0))
    // No content means no meaningful ratio.
    @Expect(approx(splitRatioForExtent(10.0, 8.0, 8.0), 0.0))
}

@Test
func splitViewLaysPanesAroundDivider(): Unit {
    let ctx = testContext()
    let left = LayoutProbe()
    let right = LayoutProbe()
    let split = SplitView(axis: Axis.Horizontal, initialRatio: 0.5, minFirst: 0.0, minSecond: 0.0,
        dividerThickness: 8.0, first: {=> emit(left)}) {=> emit(right)}

    split.layout(ctx, Rect(0.0, 0.0, 208.0, 100.0))

    // content 200, split in half: left 0..100, 8px divider, right 108..208.
    @Expect(approx(left.rect.x, 0.0))
    @Expect(approx(left.rect.w, 100.0))
    @Expect(approx(left.rect.h, 100.0))
    @Expect(approx(right.rect.x, 108.0))
    @Expect(approx(right.rect.w, 100.0))
}

@Test
func splitViewLaysPanesVertically(): Unit {
    let ctx = testContext()
    let top = LayoutProbe()
    let bottom = LayoutProbe()
    let split = SplitView(axis: Axis.Vertical, initialRatio: 0.25, minFirst: 0.0, minSecond: 0.0,
        dividerThickness: 10.0, first: {=> emit(top)}) {=> emit(bottom)}

    split.layout(ctx, Rect(0.0, 0.0, 100.0, 210.0))

    // content 200, top gets a quarter: top 0..50, 10px divider, bottom 60..210.
    @Expect(approx(top.rect.h, 50.0))
    @Expect(approx(bottom.rect.y, 60.0))
    @Expect(approx(bottom.rect.h, 150.0))
    @Expect(approx(bottom.rect.w, 100.0))
}

@Test
func splitViewDragMovesDividerAndClampsToMinimums(): Unit {
    let ctx = testContext()
    let ratio = State<Float32>(0.5)
    let split = SplitView(axis: Axis.Horizontal, ratio: ratio, minFirst: 20.0, minSecond: 20.0,
        dividerThickness: 8.0, first: {=> emit(LayoutProbe())}) {=> emit(LayoutProbe())}
    split.layout(ctx, Rect(0.0, 0.0, 208.0, 100.0)) // content 200, divider at x=100..108

    // Grab exactly at the divider's leading edge so the grab offset is zero.
    ctx.leftMouseDown = true
    @Expect(split.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 100.0, 50.0)))

    // Drag right to x=150 → first extent 150 → ratio 0.75.
    let _ = split.handle(ctx, UiEvent.MouseMove(150.0, 50.0))
    @Expect(approx(ratio.value, 0.75))

    // Past the right edge clamps to content - minSecond = 180 → ratio 0.9.
    let _ = split.handle(ctx, UiEvent.MouseMove(1000.0, 50.0))
    @Expect(approx(ratio.value, 0.9))

    // Past the left edge clamps to minFirst = 20 → ratio 0.1.
    let _ = split.handle(ctx, UiEvent.MouseMove(-500.0, 50.0))
    @Expect(approx(ratio.value, 0.1))
}

@Test
func splitViewIgnoresDragOutsideDivider(): Unit {
    let ctx = testContext()
    let ratio = State<Float32>(0.5)
    let split = SplitView(axis: Axis.Horizontal, ratio: ratio, minFirst: 0.0, minSecond: 0.0,
        dividerThickness: 8.0, first: {=> emit(LayoutProbe())}) {=> emit(LayoutProbe())}
    split.layout(ctx, Rect(0.0, 0.0, 208.0, 100.0))

    // A press well inside the first pane is not a divider grab.
    ctx.leftMouseDown = true
    @Expect(!split.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 30.0, 50.0)))
    let _ = split.handle(ctx, UiEvent.MouseMove(150.0, 50.0))
    @Expect(approx(ratio.value, 0.5))
}

@Test
func splitViewKeyboardNudgesFocusedDivider(): Unit {
    let ctx = testContext()
    let ratio = State<Float32>(0.5)
    let split = SplitView(axis: Axis.Horizontal, ratio: ratio, minFirst: 20.0, minSecond: 20.0,
        dividerThickness: 8.0, first: {=> emit(LayoutProbe())}) {=> emit(LayoutProbe())}
    split.layout(ctx, Rect(0.0, 0.0, 208.0, 100.0)) // content 200

    // Focus the divider by pressing it, then release so only focus (not a drag) remains.
    ctx.leftMouseDown = true
    @Expect(split.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 104.0, 50.0)))
    ctx.leftMouseDown = false
    ctx.clearDrag()

    // Right arrow adds one step (24px) to the first extent: 100 → 124 → ratio 0.62.
    @Expect(split.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(approx(ratio.value, 0.62))

    // Many right presses clamp at content - minSecond = 180 → ratio 0.9.
    for (_ in 0..20) {
        let _ = split.handle(ctx, UiEvent.KeyDown(Key.Right, false))
    }
    @Expect(approx(ratio.value, 0.9))

    // The cross-axis arrow is ignored by a horizontal split.
    @Expect(!split.handle(ctx, UiEvent.KeyDown(Key.Up, false)))
}

@Test
func splitViewPlacesDividerBetweenPanesInFocusOrder(): Unit {
    let split = SplitView(axis: Axis.Horizontal, first: {=> emit(FocusIdProbe("left"))}) {=>
        emit(FocusIdProbe("right"))
    }

    let ids = split.focusableIds()
    @Expect(ids.size, 3)
    @Expect(ids[0], "left")
    @Expect(ids[2], "right")
    @Expect(ids[1].contains("divider"))
}

@Test
func splitViewDragOffsetSurvivesPerFrameRebuild(): Unit {
    let ctx = testContext()
    let store = StateStore()
    let ratio = State<Float32>(0.5)
    // The real loop rebuilds the tree every frame, so the grab and the moves land on different
    // instances; the shared store plus an explicit key gives them the same retained grab offset.
    let buildFrame = {
        => buildRoot(
            {
                => SplitView(axis: Axis.Horizontal, ratio: ratio, minFirst: 0.0, minSecond: 0.0,
                    dividerThickness: 8.0, key: "sv", first: {=> emit(LayoutProbe())}) {=>
                    emit(LayoutProbe())
                }
            },
            store
        )
    }

    // Frame 1: grab the divider 6px into its body (divider spans x=100..108).
    let frameOne = buildFrame()
    frameOne.layout(ctx, Rect(0.0, 0.0, 208.0, 100.0))
    ctx.leftMouseDown = true
    @Expect(frameOne.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 106.0, 50.0)))

    // Frame 2, a fresh instance: moving the pointer +50px moves the divider exactly +50px — the
    // retained offset keeps the seam under the cursor instead of snapping its edge to the pointer.
    let frameTwo = buildFrame()
    frameTwo.layout(ctx, Rect(0.0, 0.0, 208.0, 100.0))
    let _ = frameTwo.handle(ctx, UiEvent.MouseMove(156.0, 50.0))
    @Expect(approx(ratio.value, 0.75)) // first extent 150 of content 200
}
