package cui.core

import sdl.{MouseButton, Rect, Size, UiEvent}

// For a 440-wide layout with 4 steps: left = 44, right = 396, gap = 352/3 ≈ 117.33.
// Node centres are 44, 161.33, 278.67, 396; the node row's centre-y is 4 + 14 = 18.
private let STEP_NODE_CY: Float32 = 18.0

@Test
func stepIndicatorMeasuresFixedHeight(): Unit {
    let ctx = testContext()
    // circle 28 + top pad 4 + label gap 8 + label 18 = 58.
    let size = StepIndicator(["A", "B"], 0).measure(ctx, Size(400.0, 100.0))
    @Expect(size.h, Float32(58.0))
    @Expect(size.w, Float32(400.0))
}

@Test
func stepIndicatorClicksReachableSteps(): Unit {
    let ctx = testContext()
    let picked = State<Int64>(-1)
    let steps = StepIndicator(["账户", "资料", "偏好", "完成"], 2, onSelect: {i => picked.value = i})
    steps.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))

    // Step 0 is done (≤ current 2): clicking its node selects it.
    @Expect(steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 44.0, STEP_NODE_CY)))
    @Expect(picked.value, 0)
    // The current step (2) is also reachable.
    @Expect(steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 278.0, STEP_NODE_CY)))
    @Expect(picked.value, 2)
}

@Test
func stepIndicatorIgnoresFutureSteps(): Unit {
    let ctx = testContext()
    let picked = State<Int64>(-1)
    let steps = StepIndicator(["A", "B", "C", "D"], 1, onSelect: {i => picked.value = i})
    steps.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))

    // Step 3 is in the future (> current 1): the click is not consumed and nothing is selected.
    @Expect(!steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 396.0, STEP_NODE_CY)))
    @Expect(picked.value, -1)
}

@Test
func stepIndicatorWithoutCallbackIsDisplayOnly(): Unit {
    let ctx = testContext()
    let steps = StepIndicator(["A", "B", "C"], 1)
    steps.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))
    // No onSelect: node presses are never consumed.
    @Expect(!steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 44.0, STEP_NODE_CY)))
}

@Test
func stepIndicatorIgnoresPressesAwayFromNodes(): Unit {
    let ctx = testContext()
    let picked = State<Int64>(-1)
    let steps = StepIndicator(["A", "B", "C", "D"], 3, onSelect: {i => picked.value = i})
    steps.layout(ctx, Rect(0.0, 0.0, 440.0, 60.0))
    // Well below the node row (y = 50), no node is hit.
    @Expect(!steps.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 44.0, 50.0)))
    @Expect(picked.value, -1)
}
