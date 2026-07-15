package cui.text

import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{CursorShape, State, StateStore, Theme, UiContext, buildRoot}

private func textTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func textAreaScrollbarThumbDragScrollsAndTakesPriorityOverTextDrag(): Unit {
    let ctx = textTestContext()
    let text = State<String>("one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten")
    let scroll = State<Float32>(0.0)
    let area = TextArea(text, key: "notes", scroll: Some(scroll))
    area.layout(ctx, Rect(0.0, 0.0, 200.0, 100.0))

    // Press in the scrollbar lane (right edge), not the text — then drag the thumb down.
    @Expect(area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 195.0, 6.0)))
    ctx.leftMouseDown = true
    @Expect(area.handle(ctx, UiEvent.MouseMove(195.0, 70.0)))
    @Expect(scroll.value > Float32(0.0))
    @Expect(text.value, "one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten") // dragging the bar never edits
}

@Test
func editableTextAreaRequestsTextCursorButReadOnlyDoesNot(): Unit {
    let editableCtx = textTestContext()
    let editable = TextArea(State<String>("hi"), key: "editable")
    editable.layout(editableCtx, Rect(0.0, 0.0, 200.0, 120.0))
    editableCtx.beginHoverTest()
    let _ = editable.handle(editableCtx, UiEvent.MouseMove(20.0, 20.0))
    editableCtx.settleHover()
    @Expect(editableCtx.desiredCursor() == CursorShape.Text)

    let readOnlyCtx = textTestContext()
    let readOnly = TextArea(State<String>("hi"), key: "readonly", editable: false)
    readOnly.layout(readOnlyCtx, Rect(0.0, 0.0, 200.0, 120.0))
    readOnlyCtx.beginHoverTest()
    let _ = readOnly.handle(readOnlyCtx, UiEvent.MouseMove(20.0, 20.0))
    readOnlyCtx.settleHover()
    @Expect(readOnlyCtx.desiredCursor() == CursorShape.Default)
}

@Test
func editableTextAreaJoinsFocusRingButReadOnlyDoesNot(): Unit {
    let editableStore = StateStore()
    let _ = buildRoot({=> TextArea(State<String>("hi"), key: "editable")}, editableStore)
    @Expect(editableStore.focusRing().size, 1)

    let readOnlyStore = StateStore()
    let _ = buildRoot({=> TextArea(State<String>("hi"), key: "readonly", editable: false)}, readOnlyStore)
    @Expect(readOnlyStore.focusRing().size, 0)
}

@Test
func textAreaWheelUpdatesSharedScrollState(): Unit {
    let ctx = textTestContext()
    let text = State<String>("one\ntwo\nthree\nfour\nfive\nsix\nseven\neight")
    let scroll = State<Float32>(0.0)
    let area = TextArea(text, key: "notes", scroll: Some(scroll))

    area.layout(ctx, Rect(0.0, 0.0, 180.0, 100.0))

    @Expect(area.handle(ctx, UiEvent.MouseWheel(0.0, -1.0, 12.0, 12.0)))
    @Expect(scroll.value, Float32(72.0))
}

@Test
func textEditStateInsertsAndDeletesAtUtf8Boundaries(): Unit {
    let edit = TextEditState("a你b")

    edit.moveTo(1)
    edit.moveRight()
    edit.backspace()

    @Expect(edit.text.value, "ab")
    @Expect(edit.cursor.value, Int64(1))
}

@Test
func textEditStateDeleteForwardRemovesWholeRune(): Unit {
    let edit = TextEditState("a你b")

    edit.moveTo(1)
    edit.deleteForward()

    @Expect(edit.text.value, "ab")
    @Expect(edit.cursor.value, Int64(1))
}

@Test
func textEditStateMovesBetweenLinesWithColumn(): Unit {
    let edit = TextEditState("abc\nde\nfghi")

    edit.moveTo(5)
    edit.moveLineDown()
    @Expect(edit.cursor.value, Int64(8))

    edit.moveLineUp()
    edit.moveLineUp()
    @Expect(edit.cursor.value, Int64(1))
}

@Test
func textFieldUsesExternalCursorState(): Unit {
    let ctx = textTestContext()
    let text = State<String>("abc")
    let cursor = State<Int64>(1)
    let field = TextField(text, key: "field", cursor: Some(cursor))

    field.layout(ctx, Rect(0.0, 0.0, 180.0, 34.0))
    ctx.focus("field")

    @Expect(field.handle(ctx, UiEvent.TextInput("X")))
    @Expect(text.value, "aXbc")
    @Expect(cursor.value, Int64(2))

    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(field.handle(ctx, UiEvent.KeyDown(Key.Backspace, false)))
    @Expect(text.value, "Xbc")
    @Expect(cursor.value, Int64(0))
}

@Test
func textAreaReadOnlyStillMovesCursor(): Unit {
    let ctx = textTestContext()
    let text = State<String>("abc")
    let cursor = State<Int64>(2)
    let area = TextArea(text, key: "output", cursor: Some(cursor), editable: false)

    area.layout(ctx, Rect(0.0, 0.0, 180.0, 80.0))
    ctx.focus("output")

    @Expect(!area.handle(ctx, UiEvent.TextInput("X")))
    @Expect(!area.handle(ctx, UiEvent.KeyDown(Key.Delete, false)))
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(text.value, "abc")
    @Expect(cursor.value, Int64(1))
}

@Test
func textFieldImplicitCursorSurvivesKeyedRebuild(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let store = StateStore()
    let text = State<String>("abc")

    let first = buildRoot({=> TextField(text, key: "remembered.field")}, store)
    first.layout(ctx, Rect(0.0, 0.0, 180.0, 34.0))
    let _ = first.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 170.0, 10.0))
    let _ = first.handle(ctx, UiEvent.KeyDown(Key.Left, false))

    let second = buildRoot({=> TextField(text, key: "remembered.field")}, store)
    second.layout(ctx, Rect(0.0, 0.0, 180.0, 34.0))
    let _ = second.handle(ctx, UiEvent.TextInput("X"))

    @Expect(text.value, "abXc")
}
