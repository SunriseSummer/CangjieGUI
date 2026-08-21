package cui.controls

import sdl.{Color, FontStyle, IconName}
import cui.core.{Length, LengthUnit}

// What a span carries: a run of text, or an inline icon.
enum RichSpanKind {
    | SpanText(String)
    | SpanIcon(IconName)
}

/**
 * One styled run in a `RichText`: a run of text or an inline icon, each optionally coloured. Build them
 * with the factories — `RichSpan.text` (default or explicit colour), `RichSpan.muted` (secondary text
 * colour) and `RichSpan.icon` — then chain the style builders (`bold`, `italic`, `underline`,
 * `strikethrough`, `fontStyle`, `fontFamily`, `fontSize`, `highlight`) to vary weight, slant, decoration,
 * typeface, size, and background per run. A run with no `fontSize` inherits the `RichText`'s base size;
 * runs of differing sizes on one line are centred against each other and the line grows to the tallest.
 * `highlight(background)` paints a `<mark>`-style box behind a run (e.g. to mark search matches).
 */
public struct RichSpan {
    let kind: RichSpanKind
    let color: ?Color
    let isMuted: Bool
    let style: FontStyle
    let fontFace: ?String
    // None inherits the RichText's base point size; Some overrides just this run.
    let size: ?Length
    // Some makes this run a clickable link: clicking any of its fragments runs the action, and the
    // pointer shows the interactive cursor over it. None is an ordinary, inert run.
    let tapAction: ?() -> Unit
    // Some paints a rounded highlight box behind this run (a `<mark>`-style background), drawn under the
    // text or icon; None leaves the run on the plain background. Named to avoid clashing with `highlight`.
    let highlightColor: ?Color

    private init(
        kind: RichSpanKind,
        color: ?Color,
        style: FontStyle,
        fontFace: ?String,
        size: ?Length,
        tapAction: ?() -> Unit,
        highlightColor: ?Color,
        isMuted!: Bool
    ) {
        this.kind = kind
        this.color = color
        this.isMuted = isMuted
        this.style = style
        this.fontFace = fontFace
        this.size = size
        this.tapAction = tapAction
        this.highlightColor = highlightColor
    }

    /** A run of text in the default text colour, or an explicit `color`. */
    public static func text(text: String, color!: ?Color = None): RichSpan {
        RichSpan(RichSpanKind.SpanText(text), color, FontStyle.regular, None, None, None, None, isMuted: false)
    }

    /** A run of text in the theme's secondary (muted) text colour. */
    public static func muted(text: String): RichSpan {
        RichSpan(RichSpanKind.SpanText(text), None, FontStyle.regular, None, None, None, None, isMuted: true)
    }

    /** An inline icon, sized to the line and optionally coloured. */
    public static func icon(icon: IconName, color!: ?Color = None): RichSpan {
        RichSpan(RichSpanKind.SpanIcon(icon), color, FontStyle.regular, None, None, None, None, isMuted: false)
    }

    /** This span drawn bold (or with bold set to `value`). */
    public func bold(value!: Bool = true): RichSpan {
        RichSpan(kind, color, style.withBold(value: value), fontFace, size, tapAction, highlightColor, isMuted: isMuted)
    }

    /** This span drawn italic (or with italic set to `value`). */
    public func italic(value!: Bool = true): RichSpan {
        RichSpan(kind, color, style.withItalic(value: value), fontFace, size, tapAction, highlightColor, isMuted: isMuted)
    }

    /** This span underlined (or with the underline set to `value`). */
    public func underline(value!: Bool = true): RichSpan {
        RichSpan(kind, color, style.withUnderline(value: value), fontFace, size, tapAction, highlightColor, isMuted: isMuted)
    }

    /** This span struck through (or with the strikethrough set to `value`). */
    public func strikethrough(value!: Bool = true): RichSpan {
        RichSpan(kind, color, style.withStrikethrough(value: value), fontFace, size, tapAction, highlightColor, isMuted: isMuted)
    }

    /** This span with its whole text style replaced. */
    public func fontStyle(value: FontStyle): RichSpan {
        RichSpan(kind, color, value, fontFace, size, tapAction, highlightColor, isMuted: isMuted)
    }

    /** This span drawn in a registered application font (see `Fonts.register`). */
    public func fontFamily(name: String): RichSpan {
        RichSpan(kind, color, style, Some(name), size, tapAction, highlightColor, isMuted: isMuted)
    }

    /** This span drawn at its own point size, overriding the `RichText`'s base size. */
    public func fontSize(value: Length): RichSpan {
        RichSpan(kind, color, style, fontFace, Some(value), tapAction, highlightColor, isMuted: isMuted)
    }

    /** This span drawn at its own point size in font pixels. */
    public func fontSize(value: Float32): RichSpan {
        fontSize(Length(value, LengthUnit.Fp))
    }

    /** Makes this span a clickable link: clicking it runs `action`, and the pointer turns interactive. */
    public func onTap(action: () -> Unit): RichSpan {
        RichSpan(kind, color, style, fontFace, size, action, highlightColor, isMuted: isMuted)
    }

    /**
     * Paints a rounded `background` highlight box behind this span (a `<mark>`-style background), drawn
     * under the text or icon. The run's text colour is unchanged; pair with an explicit `text(color:)`
     * for readable contrast. The box covers exactly the span's fragments with rounded corners, so two
     * separately highlighted neighbouring spans each round their own ends at the seam — text that
     * should read as one continuous mark belongs in a single span.
     */
    public func highlight(background: Color): RichSpan {
        RichSpan(kind, color, style, fontFace, size, tapAction, Some(background), isMuted: isMuted)
    }
}
