package cui_desktop_lifecycle_test

import std.fs.{Directory, File, exists}
import cui.{Color, FontRole, LengthInsets, LengthUnits, MouseButton, Rect, SdlWindow, State,
    SurfaceStyle, TextArea, TextClipboard, TextInputStyle, TextStyle, UiEvent, WidgetTestHost, WindowSpec}

// Clipboard commands, real editor layout, hit testing and GPU pixels share the same fixture.
// Reference text uses the emoji face as primary, avoiding native fallback entirely.
func verifyEmojiPaste(): Bool {
    let output = "../../../target/dev/fixtures/desktop_lifecycle/"
    if (!exists(output)) { Directory.create(output, recursive: true) }
    for (sampling in [Int32(1), Int32(2)]) {
        try (window = SdlWindow(WindowSpec("Emoji paste E2E", 420, 220, supersample: sampling), hidden: true)) {
            let host = WidgetTestHost(renderer: window.renderer)
            try {
                if (!checkEmojiPaste(window, host, sampling, output)) { return false }
            } finally { host.reset() }
        }
    }
    true
}

private func checkEmojiPaste(window: SdlWindow, host: WidgetTestHost, sampling: Int32, output: String): Bool {
    let unit = "👩🏽‍💻"; let body = State<String>(unit); let clip = State<String>("")
    let paper = Color.rgb(255, 255, 255); let ink = Color.rgb(30, 60, 90)
    let cursor = State<Int64>(unit.size); let anchor = State<Int64>(unit.size)
    let area = TextArea(body, key: "emoji-paste", cursor: cursor, anchor: anchor,
        clipboard: TextClipboard(read: {=> clip.value}, write: {value => clip.value = value}))
        .style(TextInputStyle(lineHeight: 64.fp, padding: LengthInsets(16.vp), surface: SurfaceStyle(paper), textColor: ink))
    let ctx = host.context; let renderer = window.renderer; let bounds = Rect(0.0, 0.0, 420.0, 220.0)
    ctx.withTextStyle(TextStyle(fontSize: 24.fp)) {
        renderer.prepareTextLayout(420.0, 220.0); area.layout(ctx, bounds)
        area.selectAll()
        if (!area.copy() || clip.value != unit) { return false }
        area.selectRange(unit.size, unit.size)
        var expected = unit
        for (count in 1..5) {
            if (count > 1) { expected += unit; if (!area.paste()) { return false } }
            if (body.value != expected) { return false }
            ctx.focus("other")
            renderer.beginScene(420.0, 220.0, paper)
            area.layout(ctx, bounds); area.draw(ctx)
            renderer.captureBmp(output + "emoji-paste-${sampling}-${count}.bmp")
            renderer.endScene()
            renderer.beginScene(420.0, 220.0, paper)
            let y = 16.0 + (64.0 - ctx.textHeight()) / 2.0
            let baseline = renderer.fontMetrics(pointSize: 24.0).ascent - renderer.fontMetrics(pointSize: 24.0, font: FontRole.emoji).ascent
            // Direct primary-font layout is an independent reference. Its cluster y includes
            // the space reserved above the font box, which must be removed when embedding it.
            var origin: Float32 = 0.0
            try (session = renderer.textMeasureSession(expected, pointSize: 24.0, font: FontRole.emoji)) {
                origin = session.hitTest(0.0).bounds.y
            }
            renderer.text(expected, 16.0, y + baseline - origin, ink, pointSize: 24.0, font: FontRole.emoji)
            renderer.captureBmp(output + "emoji-paste-reference-${sampling}-${count}.bmp")
            renderer.endScene()
            if (!sameEmojiPixels(File.readFrom(output + "emoji-paste-${sampling}-${count}.bmp"), File.readFrom(output + "emoji-paste-reference-${sampling}-${count}.bmp"))) {
                println("Emoji paste pixels differ: ${sampling}, ${count}"); return false
            }
            if (ctx.textWidth(expected) != renderer.textWidth(expected, pointSize: 24.0, font: FontRole.emoji)) { return false }
        }
        let width = ctx.textWidth(unit)
        ctx.focus("emoji-paste")
        let y: Float32 = 48.0
        let _ = area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 16.0 + width * 0.25, y))
        let _ = area.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 16.0 + width * 0.25, y))
        if (cursor.value != 0) { return false }
        let _ = area.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 16.0 + width * 0.75, y))
        let _ = area.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 16.0 + width * 0.75, y))
        if (cursor.value != unit.size) { return false }
        area.selectRange(unit.size, unit.size * 2)
        if (!area.copy() || clip.value != unit || !area.cut()) { return false }
        area.undo(); if (body.value != expected) { return false }
        area.undo(); if (body.value.size != expected.size - unit.size) { return false }
        area.redo()
        body.value == expected
    }
}

// The two primary fonts quantize their baselines independently on fractional desktop DPI.
// Allow at most one physical row of translation; every RGB pixel must still match exactly.
private func sameEmojiPixels(actual: Array<UInt8>, expected: Array<UInt8>): Bool {
    if (actual == expected) { return true }
    let a = EmojiBitmap(actual); let b = EmojiBitmap(expected)
    if (a.width != b.width || a.height != b.height) { return false }
    let delta = a.firstInkRow() - b.firstInkRow()
    if (delta < -1 || delta > 1) { return false }
    for (y in 0..a.height) {
        for (x in 0..a.width) { if (a.pixel(x, y) != b.pixel(x, y - delta)) { return false } }
    }
    true
}

private class EmojiBitmap {
    let width: Int64
    let height: Int64
    private let bytes: Array<UInt8>
    private let offset: Int64
    private let stride: Int64
    private let channels: Int64
    private let topDown: Bool
    init(bytes: Array<UInt8>) {
        if (bytes.size < 54 || bytes[0] != 66 || bytes[1] != 77) { throw IllegalArgumentException("Invalid fixture BMP") }
        this.bytes = bytes
        offset = EmojiBitmap.word(bytes, 10); width = EmojiBitmap.word(bytes, 18)
        let signedHeight = EmojiBitmap.word(bytes, 22)
        topDown = signedHeight >= 0x80000000
        height = if (topDown) { 0x100000000 - signedHeight } else { signedHeight }
        let bits = Int64(bytes[28]) + Int64(bytes[29]) * 256
        channels = bits / 8; stride = (width * channels + 3) / 4 * 4
        if ((bits != 24 && bits != 32) || width <= 0 || height <= 0 || width > 8192 || height > 8192 ||
            offset < 54 || offset + stride * height > bytes.size) { throw IllegalArgumentException("Unsupported fixture BMP") }
    }
    private static func word(bytes: Array<UInt8>, at: Int64): Int64 {
        Int64(bytes[at]) + Int64(bytes[at + 1]) * 256 + Int64(bytes[at + 2]) * 65536 + Int64(bytes[at + 3]) * 16777216
    }
    func pixel(x: Int64, y: Int64): UInt32 {
        if (y < 0 || y >= height) { return 0xFFFFFF }
        let row = if (topDown) { y } else { height - y - 1 }
        let at = offset + row * stride + x * channels
        UInt32(bytes[at]) | (UInt32(bytes[at + 1]) << 8) | (UInt32(bytes[at + 2]) << 16)
    }
    func firstInkRow(): Int64 {
        for (y in 0..height) { for (x in 0..width) { if (pixel(x, y) != 0xFFFFFF) { return y } } }
        height
    }
}
