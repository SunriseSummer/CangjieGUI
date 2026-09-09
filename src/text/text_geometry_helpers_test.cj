package cui.text

import sdl.{Point, Rect}
import cui.core.UiContext

private func geometryView(ctx: UiContext, frame: Rect, text: String, cursor: Int64,
    multiline!: Bool = false, scroll!: Float32 = 0.0, xShift!: Float32 = 0.0): TextEditorView {
    let edit = TextEditState(text)
    edit.moveTo(cursor)
    TextEditorView(ctx, frame, TextEditorDisplay(ctx, "field", edit, true), TextEditorLayoutCache(),
        TextEditorViewState(TextInputStyle(), multiline: multiline, scroll: scroll, xShift: xShift))
}

internal func textFieldCursorForPoint(ctx: UiContext, frame: Rect, text: String, x: Float32): Int64 {
    geometryView(ctx, frame, text, 0).hit(x, frame.centerY())[0]
}

internal func drawTextFieldCursor(ctx: UiContext, frame: Rect, id: String, text: String, cursor: Int64): Unit {
    geometryView(ctx, frame, text, cursor).draw(frame, id, true, "", UInt64(0))
}

internal struct TextAreaContent {
    let text: String
    let cursor: Int64
    let scroll: Float32
    init(text: String, cursor: Int64, scroll: Float32) {
        this.text = text; this.cursor = cursor; this.scroll = scroll
    }
}

internal func textAreaCursorForPoint(ctx: UiContext, frame: Rect, content: TextAreaContent, point: Point): Int64 {
    geometryView(ctx, frame, content.text, content.cursor, multiline: true, scroll: content.scroll).hit(point.x, point.y)[0]
}

internal func textAreaRowHeight(ctx: UiContext): Float32 { TextInputStyle().rowHeight(ctx, multiline: true) }
