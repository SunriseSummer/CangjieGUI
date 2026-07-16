package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

private func ratingTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

@Test
func ratingWidthForCount(): Unit {
    let five: Float32 = 4.0 * 24.0 + 16.0 // 112
    let one: Float32 = 16.0
    @Expect(ratingWidth(5), five)
    @Expect(ratingWidth(1), one)
}

@Test
func ratingIndexAtMapsPointer(): Unit {
    // Row starts at x=20, step 24: dot 0 spans [20,44), dot 1 [44,68) …
    @Expect(ratingIndexAt(20.0, 20.0, 5), 0)
    @Expect(ratingIndexAt(30.0, 20.0, 5), 0)
    @Expect(ratingIndexAt(45.0, 20.0, 5), 1)
    @Expect(ratingIndexAt(20.0 + 4.0 * 24.0 + 5.0, 20.0, 5), 4) // within the last dot
    @Expect(ratingIndexAt(10.0, 20.0, 5), -1) // left of the row
    @Expect(ratingIndexAt(20.0 + 5.0 * 24.0, 20.0, 5), -1) // past the last dot
}

@Test
func ratingValueForClickToggles(): Unit {
    @Expect(ratingValueForClick(0, 3), 3) // set to the clicked position
    @Expect(ratingValueForClick(2, 4), 4) // raise
    @Expect(ratingValueForClick(3, 3), 0) // click the current rating → clear
}

@Test
func clampRatingClamps(): Unit {
    @Expect(clampRating(-1, 5), 0)
    @Expect(clampRating(3, 5), 3)
    @Expect(clampRating(9, 5), 5)
}

@Test
func ratingClickSetsAndClears(): Unit {
    let ctx = ratingTestContext()
    let value = State<Int64>(0)
    let rating = Rating(value, key: "r")
    rating.layout(ctx, Rect(20.0, 40.0, ratingWidth(5), 24.0))
    // Dot index 2 (the 3rd) sits at x = 20 + 8 + 2*24 = 76.
    @Expect(rating.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 76.0, 52.0)))
    @Expect(value.value, 3)
    // Clicking the same dot again clears to zero.
    @Expect(rating.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 76.0, 52.0)))
    @Expect(value.value, 0)
}

@Test
func ratingKeyboardAdjusts(): Unit {
    let ctx = ratingTestContext()
    let value = State<Int64>(2)
    let rating = Rating(value, key: "r")
    rating.layout(ctx, Rect(20.0, 40.0, ratingWidth(5), 24.0))
    ctx.focus("r")
    @Expect(rating.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(value.value, 3)
    @Expect(rating.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(value.value, 2)
    @Expect(rating.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(value.value, 5)
    @Expect(rating.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(value.value, 0)
    // Clamps at the top.
    value.value = 5
    @Expect(rating.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(value.value, 5)
}

@Test
func ratingReadonlyIgnoresInput(): Unit {
    let ctx = ratingTestContext()
    let value = State<Int64>(3)
    let rating = Rating(value, readonly: true, key: "r")
    rating.layout(ctx, Rect(20.0, 40.0, ratingWidth(5), 24.0))
    @Expect(!rating.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 76.0, 52.0)))
    @Expect(value.value, 3) // unchanged
    @Expect(rating.focusableId().isNone()) // readonly control takes no focus
}
