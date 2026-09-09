package cui.text

import cui.core.{UiContext, Theme, State, TextStyle, LengthUnits}
import sdl.{Renderer, Rect, Point, Size}

@Test
func textInputGeometryUsesInheritedFontSize(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let text = State<String>("ab\ncd")
    let field = TextField(State<String>("AV office"), key: "font-field")
    ctx.withTextStyle(TextStyle(fontSize: 32.fp)) {
        @Expect(field.measure(ctx, Size(400.0, 200.0)).h >= ctx.textHeight() + 16.0)
        let row = textAreaRowHeight(ctx)
        @Expect(row > 28.0)
        let offset = textAreaCursorForPoint(ctx, Rect(0.0, 0.0, 400.0, 200.0), TextAreaContent(text.value, 0, 0.0),
            Point(8.0, 8.0 + row + 1.0))
        @Expect(offset, Int64(3))
    }
    @Expect(textAreaRowHeight(ctx), Float32(28.0))
}
