package cui.text

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.controls.Modal
import cui.core.{State, Theme, UiContext}

private func comboTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 300.0
    ctx.viewportHeight = 400.0
    ctx
}

// Clicking the chevron opens the suggestion list (an interactive overlay); clicking a row fills
// the bound text with that suggestion and closes.
@Test
func comboBoxChevronOpensAndClickSelects(): Unit {
    let ctx = comboTestContext()
    let text = State<String>("")
    let combo = ComboBox(text, ["北京", "上海", "广州", "深圳"], key: "city")
    combo.layout(ctx, Rect(0.0, 0.0, 200.0, 38.0))

    // The chevron occupies the right ~30px; a press there opens the list.
    @Expect(combo.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 185.0, 19.0)))
    combo.draw(ctx)
    @Expect(ctx.hasOverlay())

    // Popup opens just below the field; rows are 28px tall from y=47. Row 1 ("上海") spans [75,103).
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 60.0, 85.0)))
    @Expect(text.value, "上海")
    @Expect(!ctx.hasOverlay())
}

// Typed text filters the list; Enter commits the highlighted (only) match.
@Test
func comboBoxFiltersAndEnterCommits(): Unit {
    let ctx = comboTestContext()
    let text = State<String>("")
    let combo = ComboBox(text, ["北京", "上海", "广州", "深圳"], key: "city2")
    combo.layout(ctx, Rect(0.0, 0.0, 200.0, 38.0))
    ctx.focus("city2")

    @Expect(combo.handle(ctx, UiEvent.KeyDown(Key.Down, false))) // Down opens when focused
    combo.draw(ctx)
    @Expect(ctx.hasOverlay())

    text.value = "州" // as if typed — only 广州 matches
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(text.value, "广州")
    @Expect(!ctx.hasOverlay())
}

// A combo box inside a modal dialog — its popup stacks above the dialog, typing falls through
// the popup to the dialog's field (so the open list keeps filtering), and committing closes
// only the popup while the dialog stays open.
@Test
func comboBoxInsideModalTypesAndCommitsWithoutClosingDialog(): Unit {
    let ctx = comboTestContext()
    let presented = State<Bool>(true)
    let text = State<String>("")
    let modal = Modal(presented) {
        ComboBox(text, ["华为", "华夏", "同望"], key: "company")
    }
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    @Expect(ctx.overlayCount(), Int64(1))

    // The combo fills the dialog's content width (211px): the dialog centres at
    // (22.5,161,255,78) and the control sits at (44.5,183,211,34), its chevron on the right
    // ~30px. A press there, routed through the dialog, opens the list; drawing the stack
    // registers the popup above the dialog.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 240.0, 190.0)))
    ctx.drawActiveOverlay()
    @Expect(ctx.overlayCount(), Int64(2))

    // Typing is declined by the popup layer and falls through to the dialog's field — the
    // dialog consumes it, the text updates, and the list stays open (now filtered).
    @Expect(ctx.dispatchOverlay(UiEvent.TextInput("华")))
    @Expect(text.value, "华")
    @Expect(ctx.overlayCount(), Int64(2))

    // The popup opens below the field at (44.5,221); rows start at y=226, 28px each, so
    // y=260 lands on the second match ("华夏"). Committing closes only the popup.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 260.0)))
    @Expect(text.value, "华夏")
    @Expect(ctx.overlayCount(), Int64(1))
    @Expect(presented.value)

    // With the popup gone, Escape reaches the dialog and dismisses it.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!presented.value)
    @Expect(!ctx.hasOverlay())
}

// A long suggestion list scrolls inside the popup: the wheel moves the window, hit-testing
// follows the offset, and the padding strips hit nothing.
@Test
func comboBoxLongListScrollsInsidePopup(): Unit {
    let ctx = comboTestContext()
    let text = State<String>("")
    let combo = ComboBox(text, Array<String>(30, {i => "选项 ${i}"}), key: "long")
    combo.layout(ctx, Rect(0.0, 0.0, 200.0, 38.0))
    let _ = combo.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 185.0, 19.0))
    combo.draw(ctx)
    @Expect(ctx.hasOverlay())

    // The 850px list opens below at the 354px available there: popup (0,42,200,354). One
    // wheel notch scrolls 72px; a click at y=60 then lands on row (60-47+72)/28 = 3.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseWheel(0.0, -1.0, 100.0, 100.0)))
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 60.0)))
    @Expect(text.value, "选项 3")
    @Expect(!ctx.hasOverlay())

    // Reopen (scroll resets with the highlight); a press in the top padding (y<47) hits
    // nothing and dismisses without changing the committed text.
    let _ = combo.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 185.0, 19.0))
    combo.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 100.0, 44.0)))
    @Expect(text.value, "选项 3")
    @Expect(!ctx.hasOverlay())
}

// Arrow keys keep the highlight visible past the first screen of suggestions; Enter commits
// the highlighted row even though it opened out of view.
@Test
func comboBoxKeyboardWalksBeyondFirstScreen(): Unit {
    let ctx = comboTestContext()
    let text = State<String>("")
    let combo = ComboBox(text, Array<String>(30, {i => "城市 ${i}"}), key: "walk")
    combo.layout(ctx, Rect(0.0, 0.0, 200.0, 38.0))
    ctx.focus("walk")
    let _ = combo.handle(ctx, UiEvent.KeyDown(Key.Down, false)) // opens the list
    combo.draw(ctx)
    var presses = 0
    while (presses < 20) {
        let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))
        presses += 1
    }
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(text.value, "城市 20")
    @Expect(!ctx.hasOverlay())
}

// Escape closes without changing the typed text.
@Test
func comboBoxEscapeKeepsText(): Unit {
    let ctx = comboTestContext()
    let text = State<String>("自定义值")
    let combo = ComboBox(text, ["one", "two"], key: "c3")
    combo.layout(ctx, Rect(0.0, 0.0, 200.0, 38.0))

    let _ = combo.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 185.0, 19.0))
    combo.draw(ctx)
    @Expect(ctx.hasOverlay())

    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(text.value, "自定义值") // freely typed value is kept
    @Expect(!ctx.hasOverlay())
}
