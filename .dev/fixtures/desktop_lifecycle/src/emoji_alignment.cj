package cui_desktop_lifecycle_test

import std.fs.{Directory, File, exists}
import cui.{Color, LengthInsets, LengthUnits, Rect, Renderer, SdlWindow, State,
    SurfaceStyle, TextArea, TextField, TextInputStyle, TextStyle, WidgetTestHost, WindowSpec}

// Control geometry is compared against a direct renderer draw of the complete line. Keep it
// whole: independently snapping several draw calls is not equivalent at fractional DPI.
// The font-run baseline itself is checked against raw SDL operations in emoji_baseline_test.cj,
// and emoji-paste separately compares pixels with a primary-emoji reference.
func verifyEmojiAlignment(): Bool {
    let output = "../../../target/dev/fixtures/desktop_lifecycle/"
    if (!exists(output)) { Directory.create(output, recursive: true) }
    for (sampling in [Int32(1), Int32(2)]) {
        try (window = SdlWindow(WindowSpec("Emoji baseline E2E", 940, 280, supersample: sampling), hidden: true)) {
            let host = WidgetTestHost(renderer: window.renderer)
            try {
                for (size in [18.0f32, 32.0f32]) {
                    if (!checkEmojiAlignment(window.renderer, host, output, sampling, size)) { return false }
                }
            } finally { host.reset() }
        }
    }
    true
}

private func checkEmojiAlignment(renderer: Renderer, host: WidgetTestHost, output: String, sampling: Int32, size: Float32): Bool {
    let prefix = "试试 Emoji "; let unit = "🎉👩🏽‍💻"; let suffix = " HH"
    let value = prefix + unit + suffix
    let paper = Color.rgb(255, 255, 255); let ink = Color.rgb(30, 60, 90)
    let style = TextInputStyle(lineHeight: 64.fp, padding: LengthInsets(16.vp), surface: SurfaceStyle(paper), textColor: ink)
    let area = TextArea(State<String>(value), key: "baseline-area").style(style)
    let field = TextField(State<String>(value), key: "baseline-field").style(style)
    let ctx = host.context
    let actualPath = output + "emoji-baseline-${sampling}-${size}.bmp"
    let expectedPath = output + "emoji-baseline-reference-${sampling}-${size}.bmp"
    ctx.withTextStyle(TextStyle(fontSize: Float64(size).fp)) {
        renderer.prepareTextLayout(940.0, 280.0)
        area.layout(ctx, Rect(0.0, 0.0, 940.0, 96.0))
        field.layout(ctx, Rect(0.0, 140.0, 940.0, 96.0))
        renderer.beginScene(940.0, 280.0, paper)
        area.draw(ctx); field.draw(ctx)
        renderer.captureBmp(actualPath)
        renderer.endScene()
        renderer.beginScene(940.0, 280.0, paper)
        let y = 16.0 + (64.0 - ctx.textHeight()) / 2.0
        renderer.text(value, 16.0, y, ink, pointSize: size)
        renderer.text(value, 16.0, 188.0 - ctx.textHeight() / 2.0, ink, pointSize: size)
        renderer.captureBmp(expectedPath)
        renderer.endScene()
    }
    let equal = File.readFrom(actualPath) == File.readFrom(expectedPath)
    if (!equal) { println("Emoji baseline pixels differ: sampling ${sampling}, size ${size}") }
    equal
}
