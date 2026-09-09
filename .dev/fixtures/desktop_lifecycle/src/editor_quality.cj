package cui_desktop_lifecycle_test

import std.fs.{Directory, File, exists}
import cui.{Color, DesktopApp, LengthInsets, LengthUnits, Rect, SdlWindow, Size, State, SurfaceStyle, TextArea,
    TextField, TextInputStyle, TextSelectionWidth, TextStyle, Theme, UiContext, UiEvent, VStack, Widget,
    WindowSpec, emit}

private let QUALITY_OUT = "../../../target/dev/fixtures/desktop_lifecycle/"
private let QUALITY_PAPER = Color.rgb(255, 255, 255)
private let QUALITY_INK = Color.rgb(20, 25, 35)
private let QUALITY_SELECTION = Color.rgb(55, 100, 180)

func verifyEditorQuality(): Bool {
    if (!exists(QUALITY_OUT)) { Directory.create(QUALITY_OUT, recursive: true) }
    for (sampling in [Int32(1), Int32(2)]) {
        if (!qualitySelectionPixels(sampling)) { println("content selection failed ${sampling}"); return false }
        if (!qualityCaretGeometry(sampling)) { println("caret symmetry failed ${sampling}"); return false }
    }
    for (empty in [false, true]) {
        if (!qualityBlink(empty)) { println("caret idle rendering failed empty=${empty}"); return false }
    }
    true
}

private func qualityCaretGeometry(sampling: Int32): Bool {
    try (window = SdlWindow(WindowSpec("Caret symmetry", 360, 180, supersample: sampling), hidden: true)) {
        let ctx = UiContext(window.renderer, Theme.light())
        for (size in [16, 24, 40]) {
            let ok = ctx.withTextStyle(TextStyle(fontSize: Float64(size).fp)) {
                let field = TextField(State<String>("国Ag🎉"), key: "geometry", cursor: State<Int64>(3), anchor: State<Int64>(3))
                    .style(TextInputStyle(cursorHeight: 32.vp, cursorBlinkIntervalMs: UInt64(0)))
                window.renderer.prepareTextLayout(360.0, 180.0)
                field.layout(ctx, Rect(0.0, 0.0, 360.0, 120.0)); ctx.focus("geometry")
                window.renderer.beginScene(360.0, 180.0, QUALITY_PAPER)
                field.draw(ctx)
                let caret = ctx.textInputAnchorRect().getOrThrow()
                let ink = window.renderer.textInkBounds("国Ag", pointSize: ctx.textSize(), style: ctx.effectiveFontStyle())
                let expectedCenter = 60.0 - ctx.textHeight() / 2.0 + ink.centerY()
                let error = caret.centerY() - expectedCenter
                window.renderer.endScene()
                error > -0.001 && error < 0.001 && caret.h == 32.0
            }
            if (!ok) { return false }
        }
    }
    true
}

private func qualitySelectionPixels(sampling: Int32): Bool {
    try (window = SdlWindow(WindowSpec("Selection bounds", 360, 180, supersample: sampling), hidden: true)) {
        let ctx = UiContext(window.renderer, Theme.light())
        let renderer = window.renderer
        let body = State<String>("abc  \r\n\r\n中文🎉")
        let area = TextArea(body, key: "selected")
        let bounds = Rect(0.0, 0.0, 360.0, 180.0)
        for (full in [false, true]) {
            area.style(TextInputStyle(padding: LengthInsets(12.vp), lineHeight: 38.vp, textColor: QUALITY_INK,
                selectionColor: QUALITY_SELECTION, surface: SurfaceStyle(QUALITY_PAPER),
                selectionWidth: if (full) { TextSelectionWidth.Viewport } else { TextSelectionWidth.Content }))
            ctx.withTextStyle(TextStyle(fontSize: 24.fp)) {
                renderer.prepareTextLayout(360.0, 180.0)
                area.layout(ctx, bounds); ctx.focus("selected"); area.selectAll()
                renderer.beginScene(360.0, 180.0, QUALITY_PAPER)
                area.draw(ctx)
                renderer.captureBmp(QUALITY_OUT + "quality-selection-${sampling}-${full}.bmp")
                renderer.endScene()
                renderer.beginScene(360.0, 180.0, QUALITY_PAPER)
                let lines = ["abc  ", "", "中文🎉"]
                for (row in 0..3) {
                    let y = 12.0 + Float32(row) * 38.0
                    let width = if (full && row < 2) { Float32(336.0) }
                        else if (row == 1) { Float32(1.5) } else { ctx.textWidth(lines[row]) }
                    renderer.fill(Rect(12.0, y, width, 38.0), QUALITY_SELECTION)
                    ctx.text(lines[row], 12.0, y + (38.0 - ctx.textHeight()) / 2.0, QUALITY_INK)
                }
                renderer.captureBmp(QUALITY_OUT + "quality-selection-reference-${sampling}-${full}.bmp")
                renderer.endScene()
            }
            if (File.readFrom(QUALITY_OUT + "quality-selection-${sampling}-${full}.bmp") !=
                File.readFrom(QUALITY_OUT + "quality-selection-reference-${sampling}-${full}.bmp")) { return false }
        }
    }
    true
}

private class BlinkObservation {
    var builds: Int64 = 0
    var layouts: Int64 = 0
    var lastLayouts: Int64 = 0
    var lastBuilds: Int64 = 0
    var partials: Int64 = 0
    var normal: Int64 = 0
    var ok = true
    var start: UInt64 = UInt64(0)
    var width: Float32 = 0.0
    var height: Float32 = 0.0
    var fontScale: Float32 = 1.0
    var displayScale: Float32 = 1.0
    var firstCaret = Rect.zero()
}

private class BlinkProbe <: Widget {
    private let app: DesktopApp
    private let observation: BlinkObservation
    private let empty: Bool
    private let value: State<String>
    init(app: DesktopApp, observation: BlinkObservation, empty: Bool, value: State<String>) {
        this.app = app; this.observation = observation; this.empty = empty; this.value = value
        emit(this)
    }
    public func measure(_: UiContext, _: Size): Size { Size(0.0, 0.0) }
    public func layout(_: UiContext, _: Rect): Unit { observation.layouts += 1 }
    public func handle(_: UiContext, _: UiEvent): Bool { false }
    public func draw(ctx: UiContext): Unit {
        let now = ctx.frame.elapsedMs
        let renderer = ctx.renderer
        if (observation.start == 0) { observation.start = now }
        observation.width = ctx.viewportWidth; observation.height = ctx.viewportHeight
        observation.fontScale = ctx.fontScale; observation.displayScale = ctx.displayScale
        if (app.lastFrameUsedPartialDamage()) {
            observation.partials += 1
            observation.ok = observation.ok && observation.layouts == observation.lastLayouts &&
                observation.builds == observation.lastBuilds &&
                renderer.textMeasureCount() == 0 && renderer.textComputeCount() == 0 && renderer.textShapeCount() == 0 &&
                renderer.textDrawCount() <= 1
            let caret = ctx.textInputAnchorRect().getOrThrow()
            observation.firstCaret = caret
            if (observation.partials <= 2) {
                renderer.captureBmp(QUALITY_OUT + "quality-blink-${empty}-${observation.partials}.bmp")
            }
            println("blink empty=${empty} partial=${observation.partials} builds=${observation.builds - observation.lastBuilds} layouts=${observation.layouts - observation.lastLayouts} measure=${renderer.textMeasureCount()} compute=${renderer.textComputeCount()} shape=${renderer.textShapeCount()} draw=${renderer.textDrawCount()}")
            if (observation.partials == 3) { value.value = "changed after blink" }
        } else {
            observation.normal += 1
            if (observation.partials >= 3) {
                // Text changes need fresh row geometry, but a fixed-size editor may reuse its outer layout.
                observation.ok = observation.ok && value.value == "changed after blink"
                ctx.requestClose()
            }
        }
        if (now - observation.start > UInt64(5000)) { observation.ok = false; ctx.requestClose() }
        observation.lastLayouts = observation.layouts
        observation.lastBuilds = observation.builds
        renderer.resetTextMeasureCount()
    }
}

private func qualityStyle(visible: Bool): TextInputStyle {
    TextInputStyle(padding: LengthInsets(12.vp), lineHeight: 40.vp, cursorHeight: 26.vp,
        cursorBlinkIntervalMs: UInt64(530), cursorColor: if (visible) { QUALITY_SELECTION } else { Color.rgba(0, 0, 0, 0) },
        textColor: QUALITY_INK, placeholderColor: QUALITY_INK, surface: SurfaceStyle(QUALITY_PAPER))
}

private func qualityBlink(empty: Bool): Bool {
    let value = State<String>(if (empty) { "" } else { "国Ag 🎉\nsecond line\nthird line" })
    let original = value.value
    let cursor = State<Int64>(0); let anchor = State<Int64>(0)
    let obs = BlinkObservation()
    let app = DesktopApp(WindowSpec("Caret idle E2E", 360, 180, supersample: 2, vsync: false))
    app.run {
        obs.builds += 1
        VStack {
            TextArea(value, key: "blink", cursor: cursor, anchor: anchor).style(qualityStyle(true))
                .placeholder("国Ag placeholder 🎉").autofocus()
            BlinkProbe(app, obs, empty, value)
        }.spacing(0.0).padding(12.0)
    }
    if (!obs.ok || obs.partials < 3) { println("blink counters ok=${obs.ok}, partial=${obs.partials}"); return false }
    // Two consecutive blink phases must match complete independent frames in either order.
    try (window = SdlWindow(WindowSpec("Caret reference", 360, 180, supersample: 2, vsync: false), hidden: true)) {
        let renderer = window.renderer
        let ctx = UiContext(renderer, Theme.light())
        ctx.fontScale = obs.fontScale; ctx.displayScale = obs.displayScale
        let area = TextArea(State<String>(original), key: "reference", cursor: State<Int64>(0), anchor: State<Int64>(0))
            .placeholder("国Ag placeholder 🎉")
        let bounds = Rect(12.0, 12.0, obs.width - 24.0, obs.height - 24.0)
        for (visible in [false, true]) {
            area.style(qualityStyle(visible))
            renderer.prepareTextLayout(obs.width, obs.height)
            area.layout(ctx, bounds); ctx.focus("reference")
            renderer.beginScene(obs.width, obs.height, ctx.theme.bg)
            area.draw(ctx)
            renderer.captureBmp(QUALITY_OUT + "quality-blink-reference-${empty}-${visible}.bmp")
            renderer.endScene()
        }
    }
    let first = File.readFrom(QUALITY_OUT + "quality-blink-${empty}-1.bmp")
    let second = File.readFrom(QUALITY_OUT + "quality-blink-${empty}-2.bmp")
    let off = File.readFrom(QUALITY_OUT + "quality-blink-reference-${empty}-false.bmp")
    let on = File.readFrom(QUALITY_OUT + "quality-blink-reference-${empty}-true.bmp")
    (first == off && second == on) || (first == on && second == off)
}
