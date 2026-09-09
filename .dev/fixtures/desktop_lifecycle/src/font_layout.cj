package cui_desktop_lifecycle_test

import cui.{DesktopApp, FontStyle, Rect, Size, UiContext, UiEvent, Widget, WindowSpec, emit}

private class FontLayoutObservation {
    var matched = true
    var frames: Int64 = 0
}

private class FontLayoutProbe <: Widget {
    private let observation: FontLayoutObservation
    private let sizes: Array<Float32> = [13.0, 15.0, 20.0, 32.0]
    private let widths = Array<Float32>(4, repeat: 0.0)
    private let text = "Title · 20fp 永远滚烫 The quick brown fox"
    private let style = FontStyle(bold: true, italic: true)
    private var grid = Size.zero()

    init(observation: FontLayoutObservation) { this.observation = observation; emit(this) }

    public func measure(_: UiContext, available: Size): Size { available }

    public func layout(ctx: UiContext, _: Rect): Unit {
        grid = ctx.renderer.textMeasurementScale()
        for (i in 0..sizes.size) { widths[i] = ctx.textWidth(text, pointSize: sizes[i], style: style) }
    }

    public func draw(ctx: UiContext): Unit {
        let drawnGrid = ctx.renderer.textMeasurementScale()
        observation.matched = observation.matched && grid.w.toBits() == drawnGrid.w.toBits() && grid.h.toBits() == drawnGrid.h.toBits()
        for (i in 0..sizes.size) {
            observation.matched = observation.matched && widths[i].toBits() == ctx.textWidth(text, pointSize: sizes[i], style: style).toBits()
        }
        observation.frames += 1
        if (observation.frames >= 3) { ctx.requestClose() } else { ctx.requestFrame() }
    }

    public func handle(_: UiContext, _: UiEvent): Bool { false }
}

func verifyFontLayout(): Bool {
    for (sampling in [Int32(1), Int32(2)]) {
        let observation = FontLayoutObservation()
        let app = DesktopApp(WindowSpec("Font layout E2E", 300, 180, scale: 1.25, vsync: false, supersample: sampling))
        app.run { FontLayoutProbe(observation) }
        if (!observation.matched || observation.frames < 3) { return false }
    }
    true
}
