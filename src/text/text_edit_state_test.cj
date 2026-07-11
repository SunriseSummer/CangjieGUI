/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.text

import sdl.{Key, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

private func textTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func textAreaWheelUpdatesSharedScrollState(): Unit {
    let ctx = textTestContext()
    let text = State<String>("one\ntwo\nthree\nfour\nfive\nsix\nseven\neight")
    let scroll = State<Float32>(0.0)
    let area = TextArea("notes", text, scroll: Some(scroll))

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
    let field = TextField("field", text, cursor: Some(cursor))

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
    let area = TextArea("output", text, cursor: Some(cursor), editable: false)

    area.layout(ctx, Rect(0.0, 0.0, 180.0, 80.0))
    ctx.focus("output")

    @Expect(!area.handle(ctx, UiEvent.TextInput("X")))
    @Expect(!area.handle(ctx, UiEvent.KeyDown(Key.Delete, false)))
    @Expect(area.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(text.value, "abc")
    @Expect(cursor.value, Int64(1))
}
