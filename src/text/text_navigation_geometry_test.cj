package cui.text

import sdl.{Key, MouseButton, Point, Rect, Renderer, UiEvent}
import cui.core.{State, TextStyle, Theme, UiContext, LengthUnits}

@Test
func textNavigationClickNeverReturnsAnInteriorGraphemeBoundary(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    for (sample in ["e\u{0301}", "👩🏽‍💻", "🇨🇳"]) {
        for (x in 0..130) {
            let offset = textFieldCursorForPoint(ctx, Rect(0.0, 0.0, 200.0, 40.0), sample, Float32(x))
            @Expect(offset == 0 || offset == sample.size)
        }
    }
}

@Test
func textNavigationVerticalMotionKeepsPreferredColumnAcrossShortLines(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("abcdef\nx\nabcdef")
    let cursor = State<Int64>(5)
    let area = TextArea(body, key: "vertical", cursor: Some(cursor))
    ctx.withTextStyle(TextStyle(fontSize: 24.fp)) {
        area.layout(ctx, Rect(0.0, 0.0, 300.0, 160.0))
        ctx.focus("vertical")
        let _ = area.handle(ctx, UiEvent.KeyDown(Key.Down, false))
        @Expect(cursor.value, 8)
        let _ = area.handle(ctx, UiEvent.KeyDown(Key.Down, false))
        @Expect(cursor.value, 14)
        let _ = area.handle(ctx, UiEvent.KeyDown(Key.Up, false))
        let _ = area.handle(ctx, UiEvent.KeyDown(Key.Up, false))
        @Expect(cursor.value, 5)
    }
}

@Test
func textNavigationAreaFollowsLongLinesAndHitTestingUsesTheSameOffset(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let body = State<String>("abcdefghijklmnopqrstuvwxyz")
    let cursor = State<Int64>(body.value.size)
    let area = TextArea(body, key: "horizontal", cursor: Some(cursor))
    area.layout(ctx, Rect(0.0, 0.0, 100.0, 80.0))
    ctx.focus("horizontal")
    area.draw(ctx)
    let caret = ctx.textInputAnchorRect().getOrThrow()
    @Expect(caret.x >= 8.0 && caret.right() <= 92.0)
    let _ = area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 90.0, 12.0))
    @Expect(cursor.value >= body.value.size - 1)
    let _ = area.handle(ctx, UiEvent.KeyDown(Key.Home, false))
    area.draw(ctx)
    @Expect(ctx.textInputAnchorRect().getOrThrow().x, Float32(8.0))
}

@Test
func textNavigationCrLfRemainsOneEditingUnitAndUsesTwoRows(): Unit {
    let edit = TextEditState("ab\r\ncd")
    edit.moveTo(3) // between CR and LF, snaps to the cluster start
    @Expect(edit.cursor.value, 2)
    edit.deleteForward()
    @Expect(edit.text.value, "abcd")
    let ctx = UiContext(Renderer.headless(), Theme.light())
    @Expect(textAreaCursorForPoint(ctx, Rect(0.0, 0.0, 200.0, 100.0), TextAreaContent("ab\r\ncd", 0, 0.0),
        Point(8.0, 8.0 + textAreaRowHeight(ctx))), Int64(4))
}
