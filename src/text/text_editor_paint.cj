package cui.text

import sdl.{Color, Rect}

internal func drawEditorRows(view: TextEditorView, id: String, placeholder: String): Unit {
    let ctx = view.ctx
    let first = if (view.multiline) {
        Int64(max(0.0, view.scroll) / view.rowHeight)
    } else {
        Int64(0)
    }
    var row = min(first, view.layout.rows.size - 1)
    while (row < view.layout.rows.size && view.textY(row) < view.viewport.bottom()) {
        let line = view.layout.rows[row]
        let hint = view.display.text.isEmpty() && !view.display.composing()
        let text = if (hint) {
            placeholder
        } else {
            view.display.text[line.start..line.end]
        }
        if (!view.paintRow(row, text, hint)) {
            row += 1
            continue
        }
        let selection = view.selectionRect(row)
        if (let Some(rect) <- selection) {
            let color = if (ctx.hasFocus(id)) {
                view.style.selectionColor.getOrDefault({=> ctx.theme.accent.withAlpha(115)})
            } else {
                view.style.inactiveSelectionColor.getOrDefault({=> ctx.theme.mutedText.withAlpha(45)})
            }
            ctx.renderer.fill(rect, color)
        }
        if (hint) {
            ctx.text(placeholder, view.paintedX(row), view.textY(row),
                view.style.placeholderColor.getOrDefault({=> ctx.theme.mutedText}))
        } else {
            drawEditorRowInk(view, row, text, selection)
        }
        drawEditorCompositionLine(view, row)
        row += 1
    }
}

private func drawEditorRowInk(view: TextEditorView, row: Int64, text: String, selection: ?Rect): Unit {
    let color = view.style.textColor.getOrDefault({=> view.ctx.theme.text})
    if (let Some(selected) <- view.style.selectedTextColor) {
        if (let Some(rect) <- selection) {
            let bounds = view.viewport
            // Preserve full-line shaping, but never draw normal ink below selected ink.
            drawClippedEditorInk(view, row, text, color, Rect(bounds.x, bounds.y, max(0.0, rect.x - bounds.x), bounds.h))
            drawClippedEditorInk(view, row, text, color,
                Rect(rect.right(), bounds.y, max(0.0, bounds.right() - rect.right()), bounds.h))
            drawClippedEditorInk(view, row, text, selected, rect)
            return
        }
    }
    view.ctx.text(text, view.rowX(row), view.textY(row), color)
}

private func drawClippedEditorInk(view: TextEditorView, row: Int64, text: String, color: Color, clip: Rect): Unit {
    if (clip.w <= 0.0 || clip.h <= 0.0) {
        return
    }
    view.ctx.renderer.pushClip(clip)
    try {
        view.ctx.text(text, view.rowX(row), view.textY(row), color)
    } finally {
        view.ctx.renderer.popClip()
    }
}

internal func editorSelectionRect(view: TextEditorView, row: Int64): ?Rect {
    let line = view.layout.rows[row]
    let a = max(line.start, view.display.selectionStart)
    let b = min(line.end, view.display.selectionEnd)
    let selectedBreak = view.display.selectionStart <= line.end && view.display.selectionEnd > line.end && line.next > line
        .end
    if (a >= b && !selectedBreak) {
        return None
    }
    let x = view.rowX(row) + view.localX(row, a)
    let end = match (view.style.selectionWidth) {
        case TextSelectionWidth.Viewport where selectedBreak => view.viewport.right()
        case _ =>
            if (a >= b) {
                x + view.caretWidth
            } else {
                view.rowX(row) + view.localX(row, b)
            }
    }
    let height = if (view.style.lineHeight.isSome()) {
        view.rowHeight
    } else {
        view.textHeight
    }
    let y = view.textY(row) - if (view.style.lineHeight.isSome()) {
        (view.rowHeight - view.textHeight) / 2.0
    } else {
        0.0
    }
    Some(Rect(x, y, max(0.0, end - x), height))
}

private func drawEditorCompositionLine(view: TextEditorView, row: Int64): Unit {
    if (!view.display.composing()) {
        return
    }
    let line = view.layout.rows[row]
    let a = max(line.start, view.display.compositionStart)
    let b = min(line.end, view.display.compositionEnd)
    if (a >= b) {
        return
    }
    let x = view.rowX(row) + view.localX(row, a)
    let end = view.rowX(row) + view.localX(row, b)
    let y = view.textY(row) + view.textHeight - 1.0
    view.ctx.renderer.line(x, y, end, y, view.style.cursorColor.getOrDefault({=> view.ctx.theme.accent}))
}
