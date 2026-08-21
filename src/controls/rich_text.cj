package cui.controls

import std.collection.{ArrayList, HashMap}
import sdl.{Color, FontSizes, Key, MouseButton, Rect, Size, UiEvent, drawIcon}
import cui.core.{CUI_SMALL_H, CursorShape, Length, LengthUnit, UiContext, Widget, drawFocusRing, emit,
    focusableControlIdentity, resolveControlKey}

// Gap after an inline icon before the next span.
private let RICH_SPAN_GAP: Float32 = 3.0

// Corner radius of a span's `<mark>`-style highlight box.
private let RICH_HIGHLIGHT_RADIUS: Float32 = 3.0

/**
 * Inline styled text: a sequence of `RichSpan`s (coloured, styled text runs and inline icons) laid out
 * on one line, wrapping to the available width across as many lines as needed. Runs vary by colour,
 * weight/slant/decoration, typeface, and point size (a run with no `fontSize` inherits the RichText's
 * base size); icons flow inline. Differently-sized runs on a line are centred against each other and the
 * line grows to the tallest. This is the multi-style, text-with-icons counterpart to the single `Label`.
 *
 * ```
 * RichText([
 *     RichSpan.text("128", color: accent).bold().fontSize(24.0),
 *     RichSpan.muted(" MB").fontSize(13.0),
 *     RichSpan.text("  已同步 ").italic(),
 *     RichSpan.icon(IconName.Save, color: ok)
 * ])
 * ```
 */
public class RichText <: Widget {
    private let spans: Array<RichSpan>
    private var pointSize: Length
    private let controlId: String
    // Focus-stop id per link span index — a keyboard focus stop and click-press slot for each link.
    // None for the common linkless RichText, which allocates nothing (the tree is rebuilt every frame).
    private let linkFocusIds: ?HashMap<Int64, String>
    private var frame = Rect.zero()
    // The layout is reused across measure and draw for the same width and point size, so wrapping (which
    // runs several renderer measurements) is not redone each pass.
    private var cached: ?RichLayout = None
    private var cachedWidthKey: Float32 = -1.0
    private var cachedPointSize: Float32 = -1.0
    // A 1vp probe folded into the cache key: per-span sizes resolve through the vp scale, which can
    // change (a DPI move) while the fp-resolved base size stays equal, so ps alone under-keys them.
    private var cachedVpProbe: Float32 = -1.0

    public init(
        spans: Array<RichSpan>,
        fontSize!: Length = Length(FontSizes.BODY, LengthUnit.Fp),
        key!: ?String = None
    ) {
        this.spans = spans
        this.pointSize = fontSize
        // An identity for click-press tracking of link spans; auto-derived by build order unless given.
        this.controlId = resolveControlKey(key, "RichText")
        // Register a keyboard focus stop for each link span, in declaration order so Tab walks links
        // left to right. A RichText with no links registers and allocates nothing, staying a plain,
        // inert widget.
        var ids: ?HashMap<Int64, String> = None
        for (i in 0..spans.size) {
            if (spans[i].tapAction.isSome()) {
                let slots = match (ids) {
                    case Some(existing) => existing
                    case None =>
                        let fresh = HashMap<Int64, String>()
                        ids = Some(fresh)
                        fresh
                }
                slots[i] = focusableControlIdentity("${controlId}:link:${i}")
            }
        }
        this.linkFocusIds = ids
        emit(this)
    }

    /** Sets the point size shared by all text runs. */
    public func fontSize(value: Length): RichText {
        pointSize = value
        this
    }

    /** Sets the point size in font pixels. */
    public func fontSize(value: Float32): RichText {
        fontSize(Length(value, LengthUnit.Fp))
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let ps = resolvedPointSize(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps)
        let layout = layoutFor(ctx, available.w, ps, lineHeight)
        // Hug a single line so inline use in a row sizes to its content; fill the width once it wraps.
        // Single-line is judged by the line count, not by height — a lone line holding a run bigger
        // than the base size is taller than the base line height yet must still hug (the stat-widget
        // "big value + small unit" case). Its reported height follows the actual line, floored at the
        // base line height so an icon-only or empty line keeps the usual rhythm.
        if (layout.lines <= 1) {
            Size(min(available.w, layout.width), max(CUI_SMALL_H, max(layout.height, lineHeight) + 6.0))
        } else {
            Size(available.w, layout.height + 6.0)
        }
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let ps = resolvedPointSize(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps)
        let layout = layoutFor(ctx, frame.w, ps, lineHeight)
        // Centre the content block vertically, matching Label, so a RichText and a Label in the same
        // row share a baseline instead of the RichText riding measure()'s extra headroom.
        let offsetY = max(0.0, (frame.h - layout.height) / 2.0)
        for (item in layout.items) {
            // The fragment's box in window space; its y already centres it within its (possibly
            // taller) line, so icons and differently-sized text need no further offset here.
            let box = fragmentRect(item, offsetY)
            let color = colorFor(ctx, item)
            // A <mark>-style highlight box behind the fragment, drawn first so the glyphs sit on top.
            // It covers exactly the fragment box; a mark split across separately highlighted spans
            // rounds each fragment's own corners, so a continuous mark belongs in a single span.
            match (item.highlight) {
                case Some(bg) => ctx.renderer.fillRoundedRect(box, RICH_HIGHLIGHT_RADIUS, bg)
                case None => ()
            }
            match (item.kind) {
                case PlacedKind.PlacedText(text) =>
                    ctx.renderer.text(text, box.x, box.y, color, pointSize: item.size, style: item.style,
                        font: item.font)
                case PlacedKind.PlacedIcon(icon) => drawIcon(ctx.renderer, icon, box, color)
            }
            // A keyboard focus ring around the focused link's fragment (shown for keyboard focus only).
            match (linkIdFor(item.spanIndex)) {
                case Some(fid) where item.onTap.isSome() && ctx.showFocusRing(fid) =>
                    drawFocusRing(ctx, box, 3.0)
                case _ => ()
            }
        }
    }

    // The fragment's box in window space: layout position plus the block's vertical centring, sized by
    // the fragment's advance width and line height. Drawing (glyphs, highlight, focus ring) and link
    // hit-testing both use this one definition, so the drawn box and the hit box cannot drift apart.
    private func fragmentRect(item: PlacedItem, offsetY: Float32): Rect {
        Rect(frame.x + item.x, frame.y + offsetY + item.y, item.width, item.height)
    }

    /*
     * Link spans are clickable: pressing and releasing on the same link fragment runs its action, and
     * the pointer shows the interactive cursor while over one. A RichText with no link spans finds no
     * link fragment under the pointer, so it stays inert (returns false) exactly as before.
     */
    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(x, y) =>
                match (linkFragmentAt(ctx, x, y)) {
                    case Some(_) => ctx.claimHover(controlId, CursorShape.Interactive)
                    case None => ()
                }
                false
            case UiEvent.MouseDown(MouseButton.Left, x, y) => match (pressSlotAt(ctx, x, y)) {
                case Some(fid) =>
                    // Focus (without a keyboard ring) and press, so a click also makes the link the Tab
                    // anchor and a release on the same link fires it — mirroring Button.
                    ctx.focus(fid)
                    ctx.press(fid)
                    true
                case None => false
            }
            case UiEvent.MouseUp(MouseButton.Left, x, y) => match (linkFragmentAt(ctx, x, y)) {
                case Some(item) where isPressedLink(ctx, item.spanIndex) =>
                    fireLink(item.spanIndex)
                    true
                case _ => false
            }
            case UiEvent.KeyDown(Key.Enter, _) => activateFocusedLink(ctx)
            case UiEvent.KeyDown(Key.Space, _) => activateFocusedLink(ctx)
            case _ => false
        }
    }

    // The focus/press id for a link span index, or None when the span is not a link.
    private func linkIdFor(spanIndex: Int64): ?String {
        match (linkFocusIds) {
            case Some(ids) => ids.get(spanIndex)
            case None => None
        }
    }

    // The press slot id for a link fragment under (mx, my), or None.
    private func pressSlotAt(ctx: UiContext, mx: Float32, my: Float32): ?String {
        match (linkFragmentAt(ctx, mx, my)) {
            case Some(item) => linkIdFor(item.spanIndex)
            case None => None
        }
    }

    private func isPressedLink(ctx: UiContext, spanIndex: Int64): Bool {
        match (linkIdFor(spanIndex)) {
            case Some(fid) => ctx.isPressed(fid)
            case None => false
        }
    }

    // Runs the tap action of the link span at `spanIndex`, if it has one.
    private func fireLink(spanIndex: Int64): Unit {
        if (spanIndex >= 0 && spanIndex < spans.size) {
            match (spans[spanIndex].tapAction) {
                case Some(action) => action()
                case None => ()
            }
        }
    }

    // Enter/Space on a keyboard-focused link runs its action.
    private func activateFocusedLink(ctx: UiContext): Bool {
        for (i in 0..spans.size) {
            match (linkIdFor(i)) {
                case Some(fid) where ctx.hasFocus(fid) =>
                    fireLink(i)
                    return true
                case _ => ()
            }
        }
        false
    }

    public func focusableIds(): Array<String> {
        let ids = ArrayList<String>()
        for (i in 0..spans.size) {
            match (linkIdFor(i)) {
                case Some(fid) => ids.add(fid)
                case None => ()
            }
        }
        ids.toArray()
    }

    // The clickable link fragment under (mx, my) in window space, or None. Iterates the (cached)
    // layout, hit-testing each link fragment's box — the very rect draw paints it into.
    private func linkFragmentAt(ctx: UiContext, mx: Float32, my: Float32): ?PlacedItem {
        let ps = resolvedPointSize(ctx)
        let lineHeight = ctx.renderer.textHeight(pointSize: ps)
        let layout = layoutFor(ctx, frame.w, ps, lineHeight)
        let offsetY = max(0.0, (frame.h - layout.height) / 2.0)
        for (item in layout.items) {
            match (item.onTap) {
                case Some(_) =>
                    if (fragmentRect(item, offsetY).contains(mx, my)) {
                        return item
                    }
                case None => ()
            }
        }
        None
    }

    private func colorFor(ctx: UiContext, item: PlacedItem): Color {
        match (item.color) {
            case Some(value) => value
            case None =>
                if (item.muted) {
                    ctx.theme.mutedText
                } else {
                    ctx.theme.text
                }
        }
    }

    private func resolvedPointSize(ctx: UiContext): Float32 {
        max(1.0, ctx.resolve(pointSize))
    }

    // Exact float comparison is deliberate: the keys are reused values, so equality means same inputs.
    // A cached single-line layout is also reused for any width it still fits in — measure() hugs a
    // single line to its content width, so draw() asks for exactly layout.width and would otherwise
    // miss the cache (and re-wrap) every frame in the inline-row case.
    private func layoutFor(ctx: UiContext, width: Float32, ps: Float32, lineHeight: Float32): RichLayout {
        let vpProbe = ctx.resolve(Length(1.0, LengthUnit.Vp))
        match (cached) {
            // Exact float comparison is deliberate: the cache keys are reused input values,
            // not computed approximations, so equality means "same inputs as last time" and
            // the worst case of a near-miss is one redundant re-layout, never a wrong one.
            case Some(layout) where cachedPointSize == ps && cachedVpProbe == vpProbe && // cjcheck-ignore: float-equal # cache-key identity; miss only costs a re-layout
                (cachedWidthKey == width || (layout.lines <= 1 && layout.width <= width)) => layout // cjcheck-ignore: float-equal # cache-key identity; miss only costs a re-layout
            case _ =>
                let sizes = resolveSpanSizes(ctx, ps)
                let layout = layoutRichSpans(
                    spans,
                    sizes,
                    width,
                    richIconSize(lineHeight),
                    RICH_SPAN_GAP,
                    {text, size, style, font => ctx.renderer.textWidth(text, pointSize: size, style: style, font: font)},
                    {size, style, font => ctx.renderer.textHeight(pointSize: size, style: style, font: font)}
                )
                cached = Some(layout)
                cachedWidthKey = width
                cachedPointSize = ps
                cachedVpProbe = vpProbe
                layout
        }
    }

    // Resolves each span's point size against the context, falling back to the RichText's base size for
    // runs that set none. Parallel to `spans`.
    private func resolveSpanSizes(ctx: UiContext, basePointSize: Float32): Array<Float32> {
        Array<Float32>(spans.size) {
            i => match (spans[i].size) {
                case Some(length) => max(1.0, ctx.resolve(length))
                case None => basePointSize
            }
        }
    }
}
