package cui.text

import sdl.{MouseButton, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

/*
 * Selection lives in the shared TextEditState as a span between anchor and cursor. Held
 * Shift extends it, plain navigation collapses it, and typing / delete replace it. When
 * anchor and cursor coincide every method reduces to the original caret behavior, which is
 * what keeps controls that never select (a read-only text area) unchanged.
 */
@Test
func shiftExtendGrowsSelectionAndPlainMoveCollapses(): Unit {
    let edit = TextEditState("hello")
    edit.moveTo(0)
    edit.extendRight()
    edit.extendRight()
    @Expect(edit.hasSelection())
    @Expect(edit.selectedText(), "he")
    @Expect(edit.selectionStart(), 0)
    @Expect(edit.selectionEnd(), 2)

    edit.moveRight() // collapses onto the selection's far edge
    @Expect(!edit.hasSelection())
    @Expect(edit.cursor.value, 2)
}

@Test
func typingReplacesSelection(): Unit {
    let edit = TextEditState("hello")
    edit.selectAll()
    edit.insert("Y")
    @Expect(edit.text.value, "Y")
    @Expect(!edit.hasSelection())
    @Expect(edit.cursor.value, 1)
}

@Test
func backspaceDeletesSelectionInsteadOfOneChar(): Unit {
    let edit = TextEditState("hello")
    edit.moveTo(1)
    edit.extendRight()
    edit.extendRight() // selection covers "el"
    edit.backspace()
    @Expect(edit.text.value, "hlo")
    @Expect(edit.cursor.value, 1)
    @Expect(!edit.hasSelection())
}

@Test
func deleteForwardRemovesSelection(): Unit {
    let edit = TextEditState("hello")
    edit.moveTo(0)
    edit.extendRight()
    edit.extendRight()
    edit.deleteForward()
    @Expect(edit.text.value, "llo")
}

@Test
func selectAllSpansWholeValue(): Unit {
    let edit = TextEditState("abc")
    edit.selectAll()
    @Expect(edit.selectionStart(), 0)
    @Expect(edit.selectionEnd(), 3)
    @Expect(edit.selectedText(), "abc")
}

@Test
func selectionRespectsUtf8Boundaries(): Unit {
    let edit = TextEditState("a你b")
    edit.moveTo(0)
    edit.extendRight() // past the 1-byte 'a'
    edit.extendRight() // past the 3-byte '你'
    @Expect(edit.selectionEnd(), 4)
    @Expect(edit.selectedText(), "a你")
}

@Test
func moveLeftCollapsesToSelectionStart(): Unit {
    let edit = TextEditState("hello")
    edit.moveTo(1)
    edit.extendRight()
    edit.extendRight()
    edit.moveLeft()
    @Expect(edit.cursor.value, 1)
    @Expect(!edit.hasSelection())
}

@Test
func plainEditingIsUnaffectedWhenNothingSelected(): Unit {
    let edit = TextEditState("ab")
    edit.moveTo(1)
    edit.insert("X")
    @Expect(edit.text.value, "aXb")
    @Expect(edit.cursor.value, 2)
    edit.backspace()
    @Expect(edit.text.value, "ab")
    @Expect(edit.cursor.value, 1)
}

@Test
func shiftDownExtendsSelectionAcrossLine(): Unit {
    let edit = TextEditState("abc\ndef\nghi")
    edit.moveTo(5) // line "def", one glyph in
    edit.extendLineDown() // same column on the next line, anchor stays
    @Expect(edit.hasSelection())
    @Expect(edit.selectionStart(), 5)
    @Expect(edit.selectionEnd(), 9)
    @Expect(edit.selectedText(), "ef\ng")

    edit.extendLineUp() // back to the starting column collapses the span
    @Expect(edit.cursor.value, 5)
    @Expect(!edit.hasSelection())
}

@Test
func deletingMultiLineSelectionJoinsLines(): Unit {
    let edit = TextEditState("abc\ndef\nghi")
    edit.moveTo(2)
    edit.extendTo(9) // selects "c\ndef\ng"
    edit.backspace()
    @Expect(edit.text.value, "abhi")
    @Expect(edit.cursor.value, 2)
}

@Test
func textAreaDragSelectsAcrossText(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("hello world")
    let cursor = State<Int64>(0)
    let area = TextArea(body, key: "a", cursor: Some(cursor))
    area.layout(ctx, Rect(0.0, 0.0, 300.0, 120.0))

    // Viewport insets 8px; line 0 baseline near y=12. Press at the start, drag past "hello".
    let _ = area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 12.0))
    @Expect(cursor.value, 0)

    ctx.leftMouseDown = true
    let _ = area.handle(ctx, UiEvent.MouseMove(49.0, 12.0))
    @Expect(cursor.value, 5) // caret dragged across "hello"
    @Expect(body.value, "hello world") // drag selects, does not edit
}

@Test
func doubleClickSelectsWordRun(): Unit {
    let edit = TextEditState("hello world foo")
    edit.selectWordAt(8) // inside "world"
    @Expect(edit.selectionStart(), 6)
    @Expect(edit.selectionEnd(), 11)
    @Expect(edit.selectedText(), "world")
}

@Test
func doubleClickSelectsCjkRun(): Unit {
    let edit = TextEditState("你好 世界")
    edit.selectWordAt(8) // a continuation byte of 世; normalizes onto the run
    @Expect(edit.selectedText(), "世界")
}

@Test
func doubleClickSelectsWhitespaceOrPunctuationRun(): Unit {
    let spaces = TextEditState("a   b")
    spaces.selectWordAt(2)
    @Expect(spaces.selectedText(), "   ")

    let punct = TextEditState("a==b")
    punct.selectWordAt(1)
    @Expect(punct.selectedText(), "==")
}

@Test
func tripleClickSelectsLineIncludingItsNewline(): Unit {
    let edit = TextEditState("abc\ndef\nghi")
    edit.selectLineAt(5) // inside "def"
    @Expect(edit.selectionStart(), 4)
    @Expect(edit.selectionEnd(), 8)
    @Expect(edit.selectedText(), "def\n")

    let lastLine = TextEditState("abc\ndef")
    lastLine.selectLineAt(5)
    @Expect(lastLine.selectedText(), "def") // no trailing newline on the final line
}

@Test
func textFieldDoubleClickSelectsWordUnderPointer(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("hello world")
    let cursor = State<Int64>(0)
    let field = TextField(body, key: "f", cursor: Some(cursor))
    field.layout(ctx, Rect(0.0, 0.0, 200.0, 32.0))

    ctx.clickCount = 2
    // x=70 lands inside "world"; a double-click jumps the caret to the word's end.
    let _ = field.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 70.0, 16.0))
    @Expect(cursor.value, 11)
    @Expect(body.value, "hello world")
}

@Test
func textFieldDragSelectsWithoutEditing(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("hello")
    let cursor = State<Int64>(0)
    let field = TextField(body, key: "f", cursor: Some(cursor))
    field.layout(ctx, Rect(0.0, 0.0, 200.0, 32.0))

    // Headless metrics: each ASCII byte is 8.25px at BODY=15, and text starts 8px in.
    let _ = field.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 16.0))
    @Expect(cursor.value, 0)

    ctx.leftMouseDown = true
    let _ = field.handle(ctx, UiEvent.MouseMove(28.0, 16.0))
    @Expect(cursor.value, 2) // dragged the caret across "he"
    @Expect(body.value, "hello") // a drag selects; it must not modify the text
}

// A value wider than the field slides left so the caret stays visible, and hit-testing
// accounts for the slide. Headless metrics: 8.25px per ASCII byte at BODY=15, 8px pad,
// so 40 bytes = 330px in a 184px inner width.
@Test
func textFieldFollowsCaretHorizontally(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let cursor = State<Int64>(body.value.size)
    let anchor = State<Int64>(body.value.size)
    let field = TextField(body, key: "f", cursor: Some(cursor), anchor: Some(anchor))
    field.layout(ctx, Rect(0.0, 0.0, 200.0, 32.0))
    ctx.focus("f")

    // Caret at the end: the draw slides the window right (shift 330-184 = 146), so a click
    // at the inner right edge lands on the last byte — not somewhere in the middle.
    field.draw(ctx)
    let _ = field.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 192.0, 16.0))
    @Expect(cursor.value, 40)

    // An external caret write to the start is followed too: the window slides back and a
    // click at the text origin is byte 0 again.
    cursor.value = 0
    anchor.value = 0
    field.draw(ctx)
    let _ = field.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 8.0, 16.0))
    @Expect(cursor.value, 0)
}

// Keyboard edits keep the caret's line inside the viewport: typing at the bottom of a long
// document scrolls it into view, editing back at the top scrolls home. Frame 120px tall,
// viewport insets 8px -> 104px; rows are CUI_SMALL_H = 28px; 30 lines = 840px of content.
@Test
func textAreaFollowsCaretLineVertically(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let lines = StringBuilder()
    var i = 0
    while (i < 30) {
        if (i > 0) {
            lines.append("\n")
        }
        lines.append("l${i}")
        i += 1
    }
    let body = State<String>(lines.toString())
    let cursor = State<Int64>(body.value.size)
    let anchor = State<Int64>(body.value.size)
    let scroll = State<Float32>(0.0)
    let area = TextArea(body, key: "a", scroll: Some(scroll), cursor: Some(cursor), anchor: Some(anchor))
    area.layout(ctx, Rect(0.0, 0.0, 300.0, 120.0))
    ctx.focus("a")

    // Typing on line 29 (row top 812, far below the 104px viewport) bottom-aligns it:
    // scroll = 812 + 28 - 104 = 736, which is also the content's maximum scroll.
    let _ = area.handle(ctx, UiEvent.TextInput("x"))
    @Expect(scroll.value, Float32(736.0))

    // An external caret move to the start followed by an edit scrolls back to the top.
    cursor.value = 0
    anchor.value = 0
    let _ = area.handle(ctx, UiEvent.TextInput("y"))
    @Expect(scroll.value, Float32(0.0))
}
