package cui.core

import sdl.{Color, FontSizes, FontStyle, FontWeight, FontVariations, FontMetrics, Rect, TextMeasureSession}

/** Inherited text defaults. Unset fields keep the surrounding style; control/span overrides win. */
public struct TextStyle {
    public let fontFamily: ?String
    public let fontSize: ?Length
    public let fontStyle: ?FontStyle
    public let fontVariations: ?FontVariations
    public let fontWeight: ?FontWeight
    public let italic: ?Bool
    public let underline: ?Bool
    public let strikethrough: ?Bool

    public init(fontFamily!: ?String = None, fontSize!: ?Length = None, fontStyle!: ?FontStyle = None,
        fontWeight!: ?FontWeight = None, italic!: ?Bool = None, underline!: ?Bool = None, strikethrough!: ?Bool = None,
        fontVariations!: ?FontVariations = None) {
        this.fontFamily = fontFamily
        this.fontSize = fontSize
        this.fontStyle = fontStyle
        this.fontWeight = fontWeight
        this.fontVariations = fontVariations
        this.italic = italic
        this.underline = underline
        this.strikethrough = strikethrough
    }

    internal func over(parent: TextStyle): TextStyle {
        TextStyle(fontFamily: if (fontFamily.isSome()) {
            fontFamily
        } else {
            parent.fontFamily
        }, fontSize: if (fontSize.isSome()) {
            fontSize
        } else {
            parent.fontSize
        }, fontStyle: resolvedStyle(parent.resolvedStyle(FontStyle.regular)))
    }
    internal func resolvedStyle(parent: FontStyle): FontStyle {
        var result = fontStyle.getOrDefault({=> parent})
        if (let Some(value) <- fontWeight) {
            result = result.withWeight(value)
        }
        if (let Some(value) <- italic) {
            result = result.withItalic(value: value)
        }
        if (let Some(value) <- underline) {
            result = result.withUnderline(value: value)
        }
        if (let Some(value) <- strikethrough) {
            result = result.withStrikethrough(value: value)
        }
        if (let Some(value) <- fontVariations) {
            result = result.withVariations(value)
        }
        result
    }
}

extend UiContext {
    /** Minimum text-row height including vertical padding, for lists, menus and custom controls. */
    public func textRowHeight(minHeight!: Float32 = CUI_SMALL_H, padding!: Float32 = 8.0): Float32 {
        max(minHeight, textHeight() + padding)
    }

    /** Resolves a control's optional size, inherited size, then its default fp token. */
    public func textSize(fallback!: Float32 = FontSizes.BODY, override!: ?Length = None): Float32 {
        let length = override.getOrDefault(
            {=> inheritedTextStyle.fontSize.getOrDefault({=> Length(fallback, LengthUnit.Fp)})})
        max(1.0, resolve(length))
    }

    /** Resolves an explicit style before inherited weight/slant/decorations. */
    public func effectiveFontStyle(style!: ?FontStyle = None): FontStyle {
        style.getOrDefault({=> inheritedTextStyle.resolvedStyle(FontStyle.regular)})
    }

    /** Executes one synchronous widget phase under merged text defaults, restoring on failure. */
    public func withTextStyle<T>(style: TextStyle, body: () -> T): T {
        let previous = inheritedTextStyle
        inheritedTextStyle = style.over(previous)
        try {
            match (inheritedTextStyle.fontFamily) {
                case Some(name) => renderer.withFontFamily(name, body)
                case None => body()
            }
        } finally {
            inheritedTextStyle = previous
        }
    }

    private func logicalTextSize(pointSize: ?Float32): Float32 {
        match (pointSize) {
            case Some(value) => value
            case None => textSize()
        }
    }

    /** Measures text with inherited defaults; an explicit `pointSize` is already in logical pixels. */
    public func textWidth(text: String, pointSize!: ?Float32 = None, style!: ?FontStyle = None, font!: ?String = None): Float32 {
        renderer.textWidth(text, pointSize: logicalTextSize(pointSize), style: effectiveFontStyle(style: style),
            font: font)
    }

    /** Standard line height with the same effective font and size used by `text`. */
    public func textHeight(pointSize!: ?Float32 = None, style!: ?FontStyle = None, font!: ?String = None): Float32 {
        renderer.textHeight(pointSize: logicalTextSize(pointSize), style: effectiveFontStyle(style: style), font: font)
    }

    /** Primary-face baseline metrics with inherited text defaults. */
    public func fontMetrics(pointSize!: ?Float32 = None, style!: ?FontStyle = None, font!: ?String = None): FontMetrics {
        renderer.fontMetrics(pointSize: logicalTextSize(pointSize), style: effectiveFontStyle(style: style), font: font)
    }

    /** Draws text with inherited defaults; positions and explicit point sizes are logical pixels. */
    public func text(text: String, x: Float32, y: Float32, color: Color, pointSize!: ?Float32 = None,
        style!: ?FontStyle = None, font!: ?String = None): Unit {
        renderer.text(text, x, y, color, pointSize: logicalTextSize(pointSize), style: effectiveFontStyle(style: style),
            font: font)
    }

    /** Centers text in a logical rectangle using inherited defaults. */
    public func textCenter(text: String, rect: Rect, color: Color, pointSize!: ?Float32 = None,
        style!: ?FontStyle = None, font!: ?String = None): Unit {
        renderer.textCenter(text, rect, color, pointSize: logicalTextSize(pointSize),
            style: effectiveFontStyle(style: style), font: font)
    }

    /** Creates a measurement/hit-test session with the same effective style used for painting. */
    public func textMeasureSession(text: String, pointSize!: ?Float32 = None, style!: ?FontStyle = None,
        font!: ?String = None): TextMeasureSession {
        renderer.textMeasureSession(text, pointSize: logicalTextSize(pointSize), style: effectiveFontStyle(style: style),
            font: font)
    }
}

// A whole fontStyle replacement sets every bit; individual builders affect only their field.
protected func mergeFontStyle(parent: FontStyle, local: FontStyle, mask: Int32): FontStyle {
    var result = parent
    if ((mask & 1) != 0) {
        result = result.withWeight(local.weight)
    }
    if ((mask & 2) != 0) {
        result = result.withItalic(value: local.italic)
    }
    if ((mask & 4) != 0) {
        result = result.withUnderline(value: local.underline)
    }
    if ((mask & 8) != 0) {
        result = result.withStrikethrough(value: local.strikethrough)
    }
    if ((mask & 16) != 0) {
        result = result.withVariations(local.variations)
    }
    result
}
