package cui_paint

import cui.{Key, MouseButton, Rect, UiEvent, WidgetTestHost}

@Test
func strokesUseCanvasCoordinatesWhenTheToolbarReflows(): Unit {
    let model = PaintModel()
    let first = Rect(30.0, 140.0, 500.0, 300.0)
    @Expect(paintEvent(UiEvent.MouseDown(MouseButton.Left, 40.0, 150.0), first, model))
    @Expect(paintEvent(UiEvent.MouseMove(50.0, 160.0), first, model))
    @Expect(paintEvent(UiEvent.MouseUp(MouseButton.Left, 50.0, 160.0), first, model))
    @Expect(model.strokes[0].x1, 10.0)
    @Expect(model.strokes[0].y1, 10.0)
    let moved = Rect(30.0, 180.0, 400.0, 260.0)
    @Expect(paintEvent(UiEvent.MouseDown(MouseButton.Left, 40.0, 190.0), moved, model))
    @Expect(paintEvent(UiEvent.MouseMove(50.0, 200.0), moved, model))
    @Expect(model.strokes[1].y1, model.strokes[0].y1)
    @Expect(model.strokes[1].y2, model.strokes[0].y2)
}

@Test
func clearingCanvasCancelsTheCurrentGesture(): Unit {
    let model = PaintModel()
    model.extendStroke(2.0, 3.0)
    @Expect(!model.hasStrokes())
    model.beginStroke(1.0, 1.0)
    model.extendStroke(2.0, 3.0)
    @Expect(model.hasStrokes())
    model.clearStrokes()
    @Expect(!model.isDrawing())
    model.extendStroke(3.0, 4.0)
    @Expect(!model.hasStrokes())
    @Expect(model.strokes.isEmpty())
}

@Test
func paletteUsesKeyboardAndReleaseInsideActivation(): Unit {
    let model = PaintModel()
    let host = WidgetTestHost(theme: paintTheme())
    let bounds = Rect(0.0, 0.0, 640.0, 480.0)
    let build = {=> paintView(model)}
    let key = "paint-color-${PALETTE[0].name}"
    try {
        let _ = host.frame(bounds, body: build)
        host.context.focus(key)
        // cjcheck-ignore: bool-literal-arg # SDL KeyDown 的第二个位置参数固定为 repeat；false 表示首次按下。
        let _ = host.frame(bounds, events: [UiEvent.KeyDown(Key.Space, false), UiEvent.KeyUp(Key.Space)], body: build)
        @Expect(model.color.value.r, PALETTE[0].color.r)
        @Expect(model.color.value.g, PALETTE[0].color.g)
        @Expect(host.context.semanticsTreeSnapshot().node(key).getOrThrow().properties.label, PALETTE[0].name)
        let other = host.context.semanticsTreeSnapshot().node("paint-color-${PALETTE[2].name}").getOrThrow().bounds
        let _ = host.frame(bounds, events: [
            UiEvent.MouseDown(MouseButton.Left, other.x + 5.0, other.y + 5.0),
            UiEvent.MouseUp(MouseButton.Left, 1.0, 1.0)], body: build)
        @Expect(model.color.value.g, PALETTE[0].color.g)
    } finally { host.reset() }
}
