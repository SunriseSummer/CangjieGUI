package cui.controls

import std.collection.ArrayList
import sdl.{Color, FontSizes, Key, MouseButton, Rect, Size, UiEvent, clampF32}
import cui.core.{clampItemIndex, Bindable, CUI_CONTROL_H, CUI_GAP, CursorShape, PaintOutset, Spring, UiContext, Widget,
    buildChildren, claimHoverIfInside, drawFocusRing, drawSurface, emit, focusableControlIdentity, localState,
    requireControlId, unregisterFocusable, ellipsize}

private let SEGMENT_MIN_WIDTH: Float32 = 96.0
private let SEGMENT_LABEL_PADDING: Float32 = 12.0

/*
 * A row of mutually exclusive segments bound to a `Bindable<Int64>` index, with a sliding
 * selection pill. A single focus stop: Tab reaches the strip, Left/Right move the selection.
 */
public class SegmentedControl <: Widget {
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private let controlId: String
    // The selection pill slides between segments. Retained across rebuilds and started at the
    // current selection, so a static first frame is settled (snapshot-stable).
    private let indicatorSpring: Spring
    private var frame = Rect.zero()

    public init(items: Array<String>, selected: Bindable<Int64>, key!: ?String = None) {
        this.items = items
        this.selected = selected
        // A focus stop: Tab reaches the control, Left/Right switch the selected segment. Identity is
        // optional and auto-derived by build order; pass `key` for a stable, addressable one.
        let base = match (key) {
            case Some(value) =>
                requireControlId(value, "SegmentedControl")
                value
            case None => "SegmentedControl"
        }
        let cid = focusableControlIdentity(base)
        this.controlId = cid
        let start = Float32(clampItemIndex(selected.value, items.size))
        this.indicatorSpring = localState<Spring>("${cid}:indicator") {Spring(start)}.value
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let desired = segmentedRowDesiredWidth(ctx, items)
        Size(min(available.w, desired), ctx.textRowHeight(minHeight: CUI_CONTROL_H, padding: 12.0))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (items.size == 0) {
            return
        }
        drawSurface(ctx, frame, ctx.theme.fieldSurface())
        let target = Float32(clampItemIndex(selected.value, items.size))
        drawSlidingSegments(ctx, frame, items, indicatorSpring.animate(ctx, target: target))
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, frame, ctx.theme.controlRadius)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, controlId, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y) && items.size > 0) {
                    ctx.focus(controlId)
                    let segmentW = frame.w / Float32(items.size)
                    selected.value = clampItemIndex(Int64((x - frame.x) / segmentW), items.size)
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) => return stepSelection(ctx, -1)
            case UiEvent.KeyDown(Key.Right, _) => return stepSelection(ctx, 1)
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    private func stepSelection(ctx: UiContext, delta: Int64): Bool {
        if (!ctx.hasFocus(controlId) || items.size == 0) {
            return false
        }
        selected.value = clampItemIndex(clampItemIndex(selected.value, items.size) + delta, items.size)
        true
    }
}

/*
 * A tab strip over a page area: `labels` name the tabs, the body block declares one page
 * per label, and `selected` binds the visible page index. Only the selected page is laid
 * out and drawn. The strip is a single focus stop with Left/Right switching tabs.
 */
public class TabView <: Widget {
    private let labels: Array<String>
    private let selected: Bindable<Int64>
    private let pages: Array<Widget>
    private let controlId: String
    private let indicatorSpring: Spring
    private var frame = Rect.zero()
    private var headerHeight: Float32 = CUI_CONTROL_H
    private var laidOutPage: Int64 = -1

    public init(labels: Array<String>, selected: Bindable<Int64>, key!: ?String = None, body!: () -> Unit) {
        this.labels = labels
        this.selected = selected
        // A focus stop: Tab reaches the strip, Left/Right switch the selected tab. Registered
        // before the pages build, so Tab lands on the strip before the controls inside a page —
        // matching the visual order (strip above content).
        let base = match (key) {
            case Some(value) =>
                requireControlId(value, "TabView")
                value
            case None => "TabView"
        }
        let cid = focusableControlIdentity(base)
        this.controlId = cid
        this.pages = buildChildren("TabView", body)
        // Only the active page can receive events, so stops on hidden pages would be dead
        // ends for Tab: building registers every page's controls, then the inactive pages'
        // stops are taken out again. Switching tabs re-registers on the next frame's rebuild.
        let active = clampItemIndex(selected.value, this.pages.size)
        var i = 0
        while (i < this.pages.size) {
            if (i != active) {
                for (id in this.pages[i].focusableIds()) {
                    unregisterFocusable(id)
                }
            }
            i += 1
        }
        // The active-tab indicator slides between tabs; started at the current tab so a static
        // first frame is settled (snapshot-stable).
        let start = Float32(clampItemIndex(selected.value, labels.size))
        this.indicatorSpring = localState<Spring>("${cid}:indicator") {Spring(start)}.value
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        headerHeight = ctx.textRowHeight(minHeight: CUI_CONTROL_H, padding: 12.0)
        frame = rect
        layoutActivePage(ctx)
    }

    public func draw(ctx: UiContext): Unit {
        drawTabs(ctx)
        if (pages.size > 0) {
            ensureActivePageLayout(ctx)
            pages[pageIndex()].draw(ctx)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        // Only the tab strip is a click target; pages claim their own hover shapes.
        claimHoverIfInside(ctx, event, Rect(frame.x, frame.y, frame.w, headerHeight), controlId, CursorShape.Interactive)
        if (handleTabs(ctx, event)) {
            ensureActivePageLayout(ctx)
            return true
        }
        if (pages.size > 0) {
            ensureActivePageLayout(ctx)
            return pages[pageIndex()].handle(ctx, event)
        }
        false
    }

    public func isFlexible(): Bool {
        true
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    public func focusableIds(): Array<String> {
        // The strip plus every page's stops, so disabling a whole TabView removes them all
        // (including hidden pages', which a later frame's rebuild would otherwise re-register).
        let ids = ArrayList<String>()
        ids.add(controlId)
        for (page in pages) {
            for (id in page.focusableIds()) {
                ids.add(id)
            }
        }
        ids.toArray()
    }

    public func paintOutset(): PaintOutset {
        let strip = PaintOutset.all(4.0)
        if (pages.size == 0) {
            strip
        } else {
            strip.join(pages[pageIndex()].paintOutset())
        }
    }

    private func pageIndex(): Int64 {
        clampItemIndex(selected.value, pages.size)
    }

    private func layoutActivePage(ctx: UiContext): Unit {
        if (pages.size == 0) {
            return
        }
        let index = pageIndex()
        pages[index].layout(ctx, pageFrame())
        laidOutPage = index
    }

    /*
     * The selected tab can change between a frame's layout pass and its draw/handle
     * passes — a click switches pages mid event drain, or code drives the State. The
     * incoming page is laid out again on demand so it is never drawn or handled with a
     * stale (or never assigned) frame.
     */
    private func ensureActivePageLayout(ctx: UiContext): Unit {
        if (pages.size > 0) {
            if (pageIndex() != laidOutPage) {
                layoutActivePage(ctx)
            }
        }
    }

    private func pageFrame(): Rect {
        Rect(frame.x, frame.y + headerHeight + CUI_GAP, frame.w, max(0.0, frame.h - headerHeight - CUI_GAP))
    }

    private func drawTabs(ctx: UiContext): Unit {
        if (labels.size == 0) {
            return
        }
        let header = Rect(frame.x, frame.y, frame.w, ctx.textRowHeight(minHeight: headerHeight, padding: 12.0))
        drawSurface(ctx, header, ctx.theme.fieldSurface())
        let target = Float32(clampItemIndex(selected.value, labels.size))
        drawSlidingSegments(ctx, header, labels, indicatorSpring.animate(ctx, target: target))
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, header, ctx.theme.controlRadius)
        }
    }

    private func handleTabs(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                let header = Rect(frame.x, frame.y, frame.w, ctx.textRowHeight(minHeight: headerHeight, padding: 12.0))
                if (header.contains(x, y) && labels.size > 0) {
                    ctx.focus(controlId)
                    let tabW = frame.w / Float32(labels.size)
                    selected.value = clampItemIndex(Int64((x - frame.x) / tabW), labels.size)
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) => return stepTab(ctx, -1)
            case UiEvent.KeyDown(Key.Right, _) => return stepTab(ctx, 1)
            case _ => ()
        }
        false
    }

    private func stepTab(ctx: UiContext, delta: Int64): Bool {
        if (!ctx.hasFocus(controlId) || labels.size == 0) {
            return false
        }
        selected.value = clampItemIndex(clampItemIndex(selected.value, labels.size) + delta, labels.size)
        true
    }
}

// Draws a segmented row's selection pill and labels, with the pill slid to `animatedIndex` (a
// fractional segment index). The label the pill mostly covers is drawn in the accent-on text
// colour; the pill is clamped to the row so a spring overshoot never escapes the control.
private func drawSlidingSegments(ctx: UiContext, row: Rect, items: Array<String>, animatedIndex: Float32): Unit {
    let count = items.size
    let segmentW = row.w / Float32(count)
    let clamped = clampF32(animatedIndex, 0.0, Float32(count - 1))
    drawSurface(ctx, Rect(row.x + clamped * segmentW, row.y, segmentW, row.h).inset(3.0), ctx.theme.selectedSurface())
    let highlighted = Int64(clamped + 0.5)
    var i: Int64 = 0
    while (i < count) {
        let cell = Rect(row.x + Float32(i) * segmentW, row.y, segmentW, row.h)
        let color = if (i == highlighted) {
            ctx.theme.accentText
        } else {
            ctx.theme.text
        }
        drawSegmentLabel(ctx, items[i], cell, color)
        i += 1
    }
}

// Equal segments preserve the control's selection geometry; the widest label determines their
// natural width so a roomy toolbar does not truncate only because an old fixed width was too small.
private func segmentedRowDesiredWidth(ctx: UiContext, items: Array<String>): Float32 {
    var widest: Float32 = 0.0
    for (item in items) {
        widest = max(widest, ctx.textWidth(item, pointSize: ctx.textSize(fallback: FontSizes.BODY)))
    }
    let segmentCount = max(1, items.size)
    max(SEGMENT_MIN_WIDTH, widest + 2.0 * SEGMENT_LABEL_PADDING) * Float32(segmentCount)
}

// Text is independently fitted and clipped per cell. This remains necessary after content-aware
// measurement because an enclosing flex row may legitimately allocate less than the natural width.
private func drawSegmentLabel(ctx: UiContext, text: String, cell: Rect, color: Color): Unit {
    let textArea = Rect(cell.x + SEGMENT_LABEL_PADDING, cell.y, max(0.0, cell.w - 2.0 * SEGMENT_LABEL_PADDING), cell.h)
    let fitted = fittedSegmentLabel(ctx, text, cell.w)
    ctx.renderer.pushClip(textArea)
    try {
        ctx.textCenter(fitted, textArea, color, pointSize: ctx.textSize(fallback: FontSizes.BODY))
    } finally {
        ctx.renderer.popClip()
    }
}

func fittedSegmentLabel(ctx: UiContext, text: String, segmentWidth: Float32): String {
    ellipsize(ctx, text, max(0.0, segmentWidth - 2.0 * SEGMENT_LABEL_PADDING), FontSizes.BODY)
}
