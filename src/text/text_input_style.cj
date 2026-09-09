package cui.text

import sdl.{Color, Rect, SurfaceStyle}
import cui.core.{CUI_SMALL_H, Length, LengthInsets, LengthUnit, TextAlign, UiContext}

/** Width of selected hard-break lines; Content never extends ordinary selected text to the viewport edge. */
public enum TextSelectionWidth {
    | Content
    | Viewport
}

/** Editor appearance and inner geometry. Font family, size and weight still inherit TextStyle. */
public struct TextInputStyle {
    public let lineHeight: ?Length
    public let padding: LengthInsets
    public let alignment: TextAlign
    public let textColor: ?Color
    public let placeholderColor: ?Color
    public let selectionColor: ?Color
    public let inactiveSelectionColor: ?Color
    public let selectedTextColor: ?Color
    public let cursorColor: ?Color
    public let cursorWidth: Length
    public let cursorHeight: ?Length
    public let cursorBlinkIntervalMs: UInt64
    public let selectionWidth: TextSelectionWidth
    public let surface: ?SurfaceStyle
    public let focusedSurface: ?SurfaceStyle

    public init(lineHeight!: ?Length = None, padding!: LengthInsets = LengthInsets(Length(8.0, LengthUnit.Vp)),
        alignment!: TextAlign = TextAlign.Leading, textColor!: ?Color = None, placeholderColor!: ?Color = None,
        selectionColor!: ?Color = None, inactiveSelectionColor!: ?Color = None, selectedTextColor!: ?Color = None,
        cursorColor!: ?Color = None, cursorWidth!: Length = Length(1.5, LengthUnit.Vp), surface!: ?SurfaceStyle = None,
        focusedSurface!: ?SurfaceStyle = None, cursorHeight!: ?Length = None,
        cursorBlinkIntervalMs!: UInt64 = UInt64(530), selectionWidth!: TextSelectionWidth = TextSelectionWidth.Content) {
        if (let Some(value) <- lineHeight) {
            validateInputLength(value, positive: true)
        }
        validateInputLength(cursorWidth, positive: true)
        if (let Some(value) <- cursorHeight) {
            validateInputLength(value, positive: true)
        }
        for (value in [padding.top, padding.right, padding.bottom, padding.left]) {
            validateInputLength(value)
        }
        this.lineHeight = lineHeight
        this.padding = padding
        this.alignment = alignment
        this.textColor = textColor
        this.placeholderColor = placeholderColor
        this.selectionColor = selectionColor
        this.inactiveSelectionColor = inactiveSelectionColor
        this.selectedTextColor = selectedTextColor
        this.cursorColor = cursorColor
        this.cursorWidth = cursorWidth
        this.cursorHeight = cursorHeight
        this.cursorBlinkIntervalMs = cursorBlinkIntervalMs
        this.selectionWidth = selectionWidth
        this.surface = surface
        this.focusedSurface = focusedSurface
    }

    internal func viewport(ctx: UiContext, frame: Rect): Rect {
        let left = ctx.resolve(padding.left);
        let top = ctx.resolve(padding.top)
        Rect(frame.x + min(frame.w, left), frame.y + min(frame.h, top),
            max(0.0, frame.w - left - ctx.resolve(padding.right)), max(0.0, frame.h - top - ctx.resolve(padding.bottom)))
    }

    internal func rowHeight(ctx: UiContext, multiline!: Bool): Float32 {
        let natural = ctx.textHeight()
        match (lineHeight) {
            case Some(value) => max(natural, ctx.resolve(value))
            case None =>
                if (multiline) {
                    max(CUI_SMALL_H, natural + 4.0)
                } else {
                    natural
                }
        }
    }
}

private func validateInputLength(value: Length, positive!: Bool = false): Unit {
    if (value.value.isNaN() || value.value.isInf() || value.value < 0.0 || (positive && value.value <= 0.0)) {
        throw IllegalArgumentException(
            "Editor lengths must be finite and non-negative; line height and caret width must be positive")
    }
}
