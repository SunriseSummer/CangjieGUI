package cui_desktop_lifecycle_test

import std.fs.{Directory, File, exists}
import cui.{Color, MouseButton, Rect, RichSpan, RichText, SdlWindow, Size, State, UiEvent, WidgetTestHost, WindowSpec}

// Exercise the real font backend, widget measurement/painting and link hit boxes together.
func verifyRichTextBreaks(): Bool {
    let output = "../../../target/dev/fixtures/desktop_lifecycle/"
    if (!exists(output)) { Directory.create(output, recursive: true) }
    for (sampling in [Int32(1), Int32(2)]) {
        try (window = SdlWindow(WindowSpec("Rich text breaks E2E", 320, 240, supersample: sampling), hidden: true)) {
            let renderer = window.renderer
            let host = WidgetTestHost(renderer: renderer)
            let clicked = State<Int64>(0)
            let ink = Color.rgb(30, 60, 90)
            let rich = RichText([
                RichSpan.text("AV 仓颉\r", color: ink),
                RichSpan.text("\n\n", color: ink),
                RichSpan.text("Link", color: ink).onTap({=> clicked.value += 1}),
                RichSpan.text("\n", color: ink)
            ]).fontSize(20.0)
            try {
                renderer.beginScene(320.0, 240.0, Color.rgb(255, 255, 255))
                let height = host.context.textHeight(pointSize: 20.0)
                let measured = rich.measure(host.context, Size(300.0, 240.0))
                if (measured.h != height * 4.0 + 6.0) { return false }
                rich.layout(host.context, Rect(8.0, 8.0, 300.0, measured.h))
                rich.draw(host.context)
                renderer.captureBmp(output + "rich-breaks-${sampling}.bmp")
                renderer.endScene()

                renderer.beginScene(320.0, 240.0, Color.rgb(255, 255, 255))
                host.context.text("AV 仓颉", 8.0, 11.0, ink, pointSize: 20.0)
                host.context.text("Link", 8.0, 11.0 + 2.0 * height, ink, pointSize: 20.0)
                renderer.captureBmp(output + "rich-reference-${sampling}.bmp")
                renderer.endScene()
                let actual = File.readFrom(output + "rich-breaks-${sampling}.bmp")
                let reference = File.readFrom(output + "rich-reference-${sampling}.bmp")
                if (actual != reference) { return false }

                let blankY = 11.0 + 1.5 * height
                let linkY = 11.0 + 2.5 * height
                if (rich.handle(host.context, UiEvent.MouseDown(MouseButton.Left, 12.0, blankY))) { return false }
                if (!rich.handle(host.context, UiEvent.MouseDown(MouseButton.Left, 12.0, linkY)) ||
                    !rich.handle(host.context, UiEvent.MouseUp(MouseButton.Left, 12.0, linkY)) || clicked.value != 1) {
                    return false
                }
            } finally { host.reset() }
        }
    }
    true
}
