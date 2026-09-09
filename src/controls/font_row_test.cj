package cui.controls

import sdl.{Renderer, Rect, Size, UiEvent, MouseButton}
import cui.core.{UiContext, Theme, State, TextStyle, LengthUnits}

@Test
func inheritedFontSizeKeepsListAndTableHitRowsAligned(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let listSelection = State<Int64>(0)
    let tableSelection = State<Int64>(0)
    let list = ListView(["one", "two", "three"], listSelection, key: "font-list")
    let table = Table([TableColumn("Value", 180.0)], [["one"], ["two"], ["three"]], tableSelection, key: "font-table")
    ctx.withTextStyle(TextStyle(fontSize: 32.fp)) {
        let row = ctx.textRowHeight()
        @Expect(row > 28.0)
        list.measure(ctx, Size(200.0, 240.0))
        list.layout(ctx, Rect(0.0, 0.0, 200.0, 240.0))
        @Expect(list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 8.0 + row + 1.0)))
        @Expect(listSelection.value, Int64(1))
        table.measure(ctx, Size(200.0, 240.0))
        table.layout(ctx, Rect(0.0, 0.0, 200.0, 240.0))
        @Expect(table.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, row * 2.0 + 1.0)))
        @Expect(tableSelection.value, Int64(1))
    }
}
