package cui.text

import sdl.Rect
import std.collection.HashMap
import cui.core.{TextAlign, UiContext, drawSurface, clampScrollOffset}

private let EDITOR_SCROLL_GUTTER: Float32 = 8.0

internal struct TextEditorViewState {
    let style: TextInputStyle
    let multiline: Bool
    let wrap: Bool
    let scroll: Float32
    let xShift: Float32
    let upstream: Bool
    init(style: TextInputStyle, multiline!: Bool, wrap!: Bool = false, scroll!: Float32 = 0.0, xShift!: Float32 = 0.0,
        upstream!: Bool = false) {
        this.style = style
        this.multiline = multiline
        this.wrap = wrap
        this.scroll = scroll
        this.xShift = xShift
        this.upstream = upstream
    }
}

// One geometry shared by paint, hit-testing, visual-row navigation, scrolling and IME.
internal class TextEditorView {
    let ctx: UiContext
    let display: TextEditorDisplay
    let layout: TextEditorLayout
    let style: TextInputStyle
    let viewport: Rect
    let rowHeight: Float32
    let textHeight: Float32
    let caretWidth: Float32
    let multiline: Bool
    let upstream: Bool
    var scroll: Float32
    var xShift: Float32
    private var cachedCaret: ?Rect = None
    private let rowInk = HashMap<Int64, (Rect, Float32)>()

    init(ctx: UiContext, frame: Rect, display: TextEditorDisplay, cache: TextEditorLayoutCache,
        state: TextEditorViewState) {
        let style = state.style;
        let multiline = state.multiline
        this.ctx = ctx
        this.display = display
        this.style = style
        this.multiline = multiline
        this.upstream = state.upstream
        this.xShift = if (state.wrap && multiline) {
            Float32(0.0)
        } else {
            state.xShift
        }
        let inside = style.viewport(ctx, frame)
        this.viewport = if (multiline) {
            Rect(inside.x, inside.y, max(0.0, min(inside.right(), frame.right() - EDITOR_SCROLL_GUTTER) - inside.x),
                inside.h)
        } else {
            inside
        }
        this.textHeight = ctx.textHeight()
        this.rowHeight = style.rowHeight(ctx, multiline: multiline)
        this.caretWidth = min(max(1.0, viewport.w), ctx.resolve(style.cursorWidth))
        this.layout = cache.get(ctx, display.text, max(1.0, viewport.w - caretWidth), state.wrap && multiline, multiline)
        this.scroll = clampScrollOffset(state.scroll, Float32(layout.rows.size) * rowHeight, viewport.h)
    }

    func contentHeight(): Float32 {
        Float32(layout.rows.size) * rowHeight
    }
    func cursorRow(): Int64 {
        layout.rowAt(display.cursor, upstream: upstream && !display.composing())
    }
    func textY(row: Int64): Float32 {
        let leading = if (style.lineHeight.isSome()) {
            (rowHeight - textHeight) / 2.0
        } else {
            Float32(0.0)
        }
        if (multiline) {
            viewport.y + Float32(row) * rowHeight - scroll + leading
        } else {
            viewport.centerY() - textHeight / 2.0
        }
    }
    func rowX(row: Int64): Float32 {
        if (ctx.isCaretOnlyPaint()) {
            if (let Some(cached) <- rowInk.get(row)) {
                return cached[1]
            }
        }
        match (style.alignment) {
            case TextAlign.Leading => return viewport.x - xShift;
            case _ => ()
        }
        alignedX(layout.width(ctx, row))
    }
    func alignedX(width: Float32): Float32 {
        let space = max(0.0, viewport.w - caretWidth - width)
        let aligned = match (style.alignment) {
            case TextAlign.Leading => Float32(0.0)
            case TextAlign.Center => space / 2.0
            case TextAlign.Trailing => space
        }
        viewport.x + aligned - xShift
    }
    func localX(row: Int64, byte: Int64): Float32 {
        let line = layout.rows[row]
        ctx.textWidth(display.text[line.start..max(line.start, min(line.end, byte))])
    }
    func followHorizontal(): Float32 {
        let row = cursorRow()
        let caret = localX(row, display.cursor)
        let width = max(1.0, viewport.w - caretWidth)
        var offset = max(0.0, min(xShift, max(0.0, layout.width(ctx, row) - width)))
        if (caret < offset) {
            offset = caret
        } else if (caret > offset + width) {
            offset = caret - width
        }
        xShift = offset
        offset
    }
    func followVertical(): Float32 {
        scroll = textAreaVisibleScroll(cursorRow(), scroll, rowHeight, viewport.h, contentHeight())
        scroll
    }
    func hit(x: Float32, y: Float32): (Int64, Bool) {
        let row = if (multiline) {
            max(0, min(layout.rows.size - 1, Int64(max(0.0, y - viewport.y + scroll) / rowHeight)))
        } else {
            Int64(0)
        }
        let line = layout.rows[row]
        let offset = textCursorForOffset(ctx, display.text, line.start, line.end, x - rowX(row))
        let affinity = row + 1 < layout.rows.size && offset == line.end && layout.rows[row + 1].start == offset
        (display.documentOffset(offset), affinity)
    }
    func verticalTarget(direction: Int64, preferredX: Float32): (Int64, Float32, Bool) {
        let current = cursorRow()
        let goal = if (preferredX < 0.0) {
            rowX(current) - viewport.x + xShift + localX(current, display.cursor)
        } else {
            preferredX
        }
        if (current + direction < 0) {
            return (0, goal, false)
        }
        if (current + direction >= layout.rows.size) {
            return (display.documentOffset(display.text.size), goal, false)
        }
        let row = max(0, min(layout.rows.size - 1, current + direction))
        let line = layout.rows[row]
        let offset = textCursorForOffset(ctx, display.text, line.start, line.end, goal - (rowX(row) - viewport.x + xShift))
        (display.documentOffset(offset), goal, row + 1 < layout.rows.size && offset == line.end &&
                layout.rows[row + 1].start == offset)
    }

    func draw(frame: Rect, id: String, editable: Bool, placeholder: String, blinkEpoch: UInt64): Unit {
        let surface = if (ctx.hasFocus(id) && style.focusedSurface.isSome()) {
            style.focusedSurface
        } else {
            style.surface
        }
        drawSurface(ctx, frame, surface.getOrDefault({=> ctx.theme.fieldSurface(active: ctx.showFocusRing(id))}))
        ctx.renderer.pushClip(viewport)
        try {
            drawEditorRows(this, id, placeholder)
            if (editable && ctx.hasFocus(id)) {
                paintCaret(blinkEpoch)
            }
        } finally {
            ctx.renderer.popClip()
        }
    }

    func caretRect(): Rect {
        if (let Some(value) <- cachedCaret) {
            return value
        }
        let row = cursorRow()
        let ink = ctx.renderer.textInkBounds("国Ag", pointSize: ctx.textSize(), style: ctx.effectiveFontStyle())
        let height = min(max(1.0, viewport.h),
            style.cursorHeight.map({length => ctx.resolve(length)}).getOrDefault({=> textHeight}))
        let center = if (ink.h > 0.0) {
            ink.centerY()
        } else {
            textHeight / 2.0
        }
        let caret = Rect(rowX(row) + localX(row, display.cursor), textY(row) + center - height / 2.0, caretWidth, height)
        cachedCaret = Some(caret)
        caret
    }

    func selectionRect(row: Int64): ?Rect {
        editorSelectionRect(this, row)
    }

    func paintRow(row: Int64, text: String, placeholder: Bool): Bool {
        if (ctx.isCaretOnlyPaint()) {
            return rowInk.get(row).map({cached => ctx.caretPaintIntersects(cached[0])}).getOrDefault({=> true})
        }
        let ink = ctx.renderer.textInkBounds(text, pointSize: ctx.textSize(), style: ctx.effectiveFontStyle())
        let x = if (placeholder) {
            alignedX(ctx.textWidth(text))
        } else {
            rowX(row)
        }
        rowInk[row] = (Rect(x + ink.x - 1.0, textY(row) + ink.y - 1.0, ink.w + 2.0, ink.h + 2.0), x)
        true
    }

    func paintedX(row: Int64): Float32 {
        rowInk.get(row).map({cached => cached[1]}).getOrDefault({=> rowX(row)})
    }

    private func paintCaret(epoch: UInt64): Unit {
        let caret = caretRect()
        // Keep the input session alive even when the document selection hides the caret.
        let anchor = Rect(max(viewport.x, min(caret.x, viewport.right() - caretWidth)),
            max(viewport.y, min(caret.y, viewport.bottom() - min(caret.h, viewport.h))), min(caretWidth, viewport.w),
            min(caret.h, viewport.h))
        ctx.setTextInputAnchor(anchor)
        if (!ctx.textWindowActive() || (!display.composing() && display.selectionStart != display.selectionEnd)) {
            return
        }
        var visible = caret.intersection(viewport)
        if (let Some(parent) <- ctx.renderer.currentClip()) {
            visible = visible.intersection(parent)
        }
        if (visible.w <= 0.0 || visible.h <= 0.0) {
            return
        }
        let interval = style.cursorBlinkIntervalMs
        let elapsed = ctx.frame.elapsedMs
        let phase = if (elapsed >= epoch) {
            elapsed - epoch
        } else {
            UInt64(0)
        }
        if (!display.composing() && interval > 0) {
            let wait = interval - phase % interval
            if (UInt64.Max - elapsed >= wait) {
                ctx.requestCaretFrameAt(elapsed + wait,
                    Rect(visible.x - 1.0, visible.y - 1.0, visible.w + 2.0, visible.h + 2.0))
            }
        }
        if (display.composing() || interval == 0 || textCursorVisible(ctx, epoch: epoch, interval: interval)) {
            ctx.renderer.fill(caret, style.cursorColor.getOrDefault({=> ctx.theme.accent}))
        }
    }
}
