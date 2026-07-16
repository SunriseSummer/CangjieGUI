package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

private func menuBarTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 800.0
    ctx.viewportHeight = 600.0
    ctx
}

// Two menus: 文件 has a separator between its items, 编辑 leads with a disabled row. The bar is laid at
// the origin so the first title starts at x=4 and its dropdown opens at y=36 (bar height 34 + gap 2).
private func sampleBar(ran: State<Int64>): MenuBar {
    MenuBar([
        Menu("文件", [
            MenuItem("新建", {=> ran.value = 1}),
            MenuItem.separator(),
            MenuItem("退出", {=> ran.value = 2})
        ]),
        Menu("编辑", [
            MenuItem("撤销", {=> ran.value = 3}, enabled: false),
            MenuItem("重做", {=> ran.value = 4})
        ])
    ], key: "mb")
}

// The centre y of dropdown row `row` under the first title (popup top at 36, pad 5, row height 28).
private func rowCenterY(row: Int64): Float32 {
    36.0 + 5.0 + Float32(row) * 28.0 + 14.0
}

@Test
func menuBarClickTitleOpensAndRunsItem(): Unit {
    let ctx = menuBarTestContext()
    let ran = State<Int64>(0)
    let bar = sampleBar(ran)
    bar.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))

    // A press on the first title (near the left) opens its menu; draw registers the overlay.
    @Expect(bar.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 17.0)))
    bar.draw(ctx)
    @Expect(ctx.hasOverlay())

    // The dropdown opens at x=4; row 0 is "新建".
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 24.0, rowCenterY(0))))
    @Expect(ran.value, 1)
    @Expect(!ctx.hasOverlay())
}

@Test
func menuBarKeyboardOpensAndSkipsSeparator(): Unit {
    let ctx = menuBarTestContext()
    let ran = State<Int64>(0)
    let bar = sampleBar(ran)
    bar.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))
    ctx.focus("mb")

    @Expect(bar.handle(ctx, UiEvent.KeyDown(Key.Down, false))) // opens the focused title (0)
    bar.draw(ctx)
    // Highlight starts on "新建" (0); Down steps over the separator (1) to "退出" (2).
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false)))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(ran.value, 2)
}

@Test
func menuBarArrowSwitchesMenuAndSkipsDisabled(): Unit {
    let ctx = menuBarTestContext()
    let ran = State<Int64>(0)
    let bar = sampleBar(ran)
    bar.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))
    ctx.focus("mb")

    let _ = bar.handle(ctx, UiEvent.KeyDown(Key.Down, false)) // open 文件
    bar.draw(ctx)
    // Right switches to 编辑; its highlight starts past the disabled "撤销" on "重做".
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Right, false)))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(ran.value, 4)
}

@Test
func menuBarHoverHighlightThenEnterRuns(): Unit {
    let ctx = menuBarTestContext()
    let ran = State<Int64>(0)
    let bar = sampleBar(ran)
    bar.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))

    let _ = bar.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 17.0)) // open 文件
    bar.draw(ctx)
    // Hover over row 2 ("退出"), then Enter runs the highlighted row.
    let _ = ctx.dispatchOverlay(UiEvent.MouseMove(24.0, rowCenterY(2)))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(ran.value, 2)
}

@Test
func menuBarSeparatorClickClosesWithoutRunning(): Unit {
    let ctx = menuBarTestContext()
    let ran = State<Int64>(0)
    let bar = sampleBar(ran)
    bar.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))

    let _ = bar.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 17.0))
    bar.draw(ctx)
    // Row 1 is the separator: clicking it runs nothing but dismisses the menu.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 24.0, rowCenterY(1))))
    @Expect(ran.value, 0)
    @Expect(!ctx.hasOverlay())
}

@Test
func menuBarEscapeCloses(): Unit {
    let ctx = menuBarTestContext()
    let ran = State<Int64>(0)
    let bar = sampleBar(ran)
    bar.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))

    let _ = bar.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 17.0))
    bar.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!ctx.hasOverlay())
    @Expect(ran.value, 0)
}

@Test
func menuBarClickOutsideDismisses(): Unit {
    let ctx = menuBarTestContext()
    let ran = State<Int64>(0)
    let bar = sampleBar(ran)
    bar.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))

    let _ = bar.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 17.0))
    bar.draw(ctx)
    // A click well away from the bar and the dropdown dismisses it.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 500.0, 400.0)))
    @Expect(!ctx.hasOverlay())
    @Expect(ran.value, 0)
}

@Test
func menuBarUnfocusedKeysIgnored(): Unit {
    let ctx = menuBarTestContext()
    let ran = State<Int64>(0)
    let bar = sampleBar(ran)
    bar.layout(ctx, Rect(0.0, 0.0, 400.0, 34.0))
    // Not focused: navigation keys are not consumed and nothing opens.
    @Expect(!bar.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    bar.draw(ctx)
    @Expect(!ctx.hasOverlay())
}
