package cui_desktop_lifecycle_test

import cui.{FontWeight, Rect, SdlWindow, State, TextArea, TextClipboard, TextStyle, Theme, WidgetTestHost, WindowSpec,
    LengthUnits}

private class TextEditingObservation {
    var area: ?TextArea = None
}

func verifyTextEditing(): Bool {
    for (sampling in [Int32(1), Int32(2)]) {
        let window = SdlWindow(WindowSpec("Text editing E2E", 320, 180, scale: 1.0, supersample: sampling))
        let renderer = window.renderer
        let host = WidgetTestHost(renderer: renderer, fontScale: 1.25)
        let text = State<String>("abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")
        let clipboardText = State<String>("e\u{0301} 仓颉\r\nabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")
        let clipboard = TextClipboard(read: {=> clipboardText.value}, write: {value => clipboardText.value = value})
        let readOnly = State<Bool>(false)
        let probe = TextEditingObservation()
        let view: () -> Unit = {
            =>
                let area = TextArea(text, key: "native-edit", editable: !readOnly.value, clipboard: clipboard)
                probe.area = Some(area)
                area.textStyle(TextStyle(fontFamily: "Cascadia Code", fontWeight: FontWeight(625), fontSize: 32.fp))
                ()
        }
        try {
            renderer.beginScene(320.0, 180.0, Theme.light().bg)
            let _ = host.frame(Rect(0.0, 0.0, 320.0, 180.0), body: view)
            host.context.focus("native-edit")
            let area = probe.area.getOrThrow()
            area.selectAll()
            if (!area.paste()) {
                return false
            }
            let _ = host.frame(Rect(0.0, 0.0, 320.0, 180.0), elapsedMs: UInt64(10), body: view)
            let caret = host.context.textInputAnchorRect().getOrThrow()
            if (caret.x < 8.0 || caret.right() > 312.0 || caret.bottom() > 172.0) {
                return false
            }
            let current = probe.area.getOrThrow()
            current.selectAll()
            if (!current.copy() || clipboardText.value != text.value || text.value.contains("\r")) {
                return false
            }
            let committed = text.value
            readOnly.value = true
            let _ = host.frame(Rect(0.0, 0.0, 320.0, 180.0), elapsedMs: UInt64(20), body: view)
            probe.area.getOrThrow().undo()
            if (text.value != committed || probe.area.getOrThrow().paste()) {
                return false
            }
            renderer.endScene()
        } finally {
            host.reset();
            window.close()
        }
    }
    true
}
