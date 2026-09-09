package cui.text

import sdl.{Rect, Renderer, Key, UiEvent, FrameInfo}
import cui.core.{State, Theme, UiContext}

@Test
func editorEvolutionReadOnlyDoesNotActivateIme(): Unit {
    for (multiline in [false, true]) {
        let ctx = UiContext(Renderer.headless(), Theme.light())
        let value = State<String>("read only")
        ctx.focus("readonly")
        if (multiline) {
            let input = TextArea(value, key: "readonly", editable: false)
            input.layout(ctx, Rect(0.0, 0.0, 250.0, 100.0)); input.draw(ctx)
        } else {
            let input = TextField(value, key: "readonly", editable: false)
            input.layout(ctx, Rect(0.0, 0.0, 250.0, 40.0)); input.draw(ctx)
        }
        @Expect(ctx.textInputAnchorRect().isNone())
    }
}

@Test
func editorEvolutionImeAnchorUsesCompositionSelection(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let value = State<String>("")
    let field = TextField(value, key: "composition")
    field.layout(ctx, Rect(0.0, 0.0, 300.0, 40.0))
    ctx.focus("composition")
    ctx.setImeComposition("composition", "ab🎉cd", 2, 1)
    field.draw(ctx)
    @Expect(ctx.textInputAnchorRect().getOrThrow().x, 8.0 + ctx.textWidth("ab🎉"))
    @Expect(value.value, "")
}

@Test
func editorEvolutionCompositionReplacesSelectionOnlyInDisplayUntilCommit(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("beforeOLDafter")
    let field = TextField(body, key: "preedit")
    field.layout(ctx, Rect(0.0, 0.0, 400.0, 60.0)); ctx.focus("preedit")
    field.selectRange(6, 9)
    @Expect(field.handle(ctx, UiEvent.TextEditing("🎉中文", 1, 1)))
    let edit = TextEditState(body); edit.moveTo(6); edit.extendTo(9)
    let display = TextEditorDisplay(ctx, "preedit", edit, true)
    @Expect(display.text, "before🎉中文after")
    @Expect(display.cursor, "before🎉中".size)
    @Expect(display.selectionStart, "before🎉".size)
    @Expect(display.documentOffset(display.text.size), body.value.size)
    @Expect(body.value, "beforeOLDafter")
    @Expect(!field.canUndo())
    @Expect(field.handle(ctx, UiEvent.TextInput("🎉中文")))
    @Expect(body.value, "before🎉中文after")
    field.undo(); @Expect(body.value, "beforeOLDafter")
}

@Test
func editorEvolutionCompositionClampsNativeScalarSelectionAndPreservesCrLfUnits(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light()); ctx.focus("ime")
    let edit = TextEditState("")
    ctx.setImeComposition("ime", "a\r\nb🎉", 3, 0)
    @Expect(TextEditorDisplay(ctx, "ime", edit, true).cursor, 3)
    ctx.setImeComposition("ime", "a🎉", Int32.Max, Int32.Max)
    @Expect(TextEditorDisplay(ctx, "ime", edit, true).cursor, "a🎉".size)
    ctx.setImeComposition("ime", "a🎉", -1, 0)
    @Expect(TextEditorDisplay(ctx, "ime", edit, true).cursor, "a🎉".size)
}

@Test
func editorEvolutionSubmitIsFocusedEditableAndDoesNotStealImeEnter(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("hello 🎉"); let submitted = State<String>("")
    let field = TextField(body, key: "submit").onSubmit({text => submitted.value = text})
    @Expect(!field.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    ctx.focus("submit"); ctx.setImeComposition("submit", "拼", 0, 1)
    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(submitted.value, "")
    ctx.clearImeComposition()
    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(submitted.value, body.value)
    let readonly = TextField(body, key: "submit", editable: false).onSubmit({_ => submitted.value = "wrong"})
    @Expect(!readonly.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(submitted.value, body.value)
}

@Test
func editorEvolutionCursorBlinkRestartsOnMotionAndHandlesClockReset(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.frame = FrameInfo(UInt64(800), UInt64(0))
    @Expect(!textCursorVisible(ctx))
    @Expect(textCursorVisible(ctx, epoch: UInt64(800)))
    ctx.frame = FrameInfo(UInt64(1330), UInt64(0))
    @Expect(!textCursorVisible(ctx, epoch: UInt64(800)))
    ctx.frame = FrameInfo(UInt64(10), UInt64(0))
    @Expect(textCursorVisible(ctx, epoch: UInt64(800)))
}
