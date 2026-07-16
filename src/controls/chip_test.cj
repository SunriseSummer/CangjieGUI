package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, Size, UiEvent}
import cui.core.{State, Theme, UiContext}

private func chipTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

@Test
func chipMeasuresAndIsFocusable(): Unit {
    let ctx = chipTestContext()
    let chip = Chip("标签", State<Bool>(false), key: "c")
    let size = chip.measure(ctx, Size(200.0, 100.0))
    let height: Float32 = 28.0
    @Expect(size.h, height)
    @Expect(chip.focusableId().isSome())
}

@Test
func chipTogglesOnClick(): Unit {
    let ctx = chipTestContext()
    let on = State<Bool>(false)
    let chip = Chip("待办", on, key: "c")
    chip.layout(ctx, Rect(20.0, 40.0, 80.0, 28.0))
    @Expect(chip.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 54.0)))
    @Expect(on.value) // toggled on
    @Expect(chip.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 54.0)))
    @Expect(!on.value) // toggled back off
}

@Test
func chipTogglesOnKeyboardWhenFocused(): Unit {
    let ctx = chipTestContext()
    let on = State<Bool>(false)
    let chip = Chip("待办", on, key: "c")
    chip.layout(ctx, Rect(20.0, 40.0, 80.0, 28.0))
    ctx.focus("c")
    @Expect(chip.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(on.value)
    @Expect(chip.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(!on.value)
}

@Test
func chipUnfocusedIgnoresKeyboard(): Unit {
    let ctx = chipTestContext()
    let on = State<Bool>(false)
    let chip = Chip("待办", on, key: "c")
    chip.layout(ctx, Rect(20.0, 40.0, 80.0, 28.0))
    // Not focused, so a key press is not consumed and the value is unchanged.
    @Expect(!chip.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(!on.value)
}
