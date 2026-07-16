package cui.controls

import std.collection.{ArrayList, HashSet}
import sdl.{Color, FontSizes, Key, MouseButton, Pen, Rect, Size, UiEvent}
import cui.core.{CursorShape, LAYOUT_UNBOUNDED, State, UiContext, Widget, resolveControlKey, buildKeyedChild,
    drawFocusRing, emit, focusableControlIdentity, localState}

private let ACCORDION_HEADER_H: Float32 = 42.0

/**
 * One section of an `Accordion`: a header title and a builder for the body shown when it is expanded.
 * The body is only built while the section is open, so a collapsed section costs nothing and its
 * per-body local state is dropped until it reopens.
 */
public struct AccordionSection {
    let title: String
    let body: () -> Unit

    public init(title: String, body: () -> Unit) {
        this.title = title
        this.body = body
    }
}

/**
 * A stack of collapsible sections: each has a clickable header (title plus a disclosure chevron) and a
 * body revealed when expanded. Good for settings groups, FAQs and property inspectors. With `single`
 * set, opening one section closes the others (an accordion proper); otherwise sections toggle
 * independently. Expansion is retained by the view's identity, seeded by `initiallyExpanded`, or owned
 * externally through `expanded`.
 *
 * Each header is a keyboard focus stop: Enter or Space toggles the focused section, and Tab walks the
 * headers and the controls inside open bodies. Only open bodies are built, so a collapsed section's
 * local state resets when it reopens — hoist anything that must persist.
 */
public class Accordion <: Widget {
    private let titles: Array<String>
    private let headerIds: Array<String>
    // The built body for each open section, or None while collapsed.
    private let bodies: Array<?Widget>
    private let expandedState: State<HashSet<Int64>>
    private let single: Bool
    private let headerRects: Array<Rect>

    public init(
        sections: Array<AccordionSection>,
        single!: Bool = false,
        expanded!: ?State<HashSet<Int64>> = None,
        initiallyExpanded!: Array<Int64> = [],
        key!: ?String = None
    ) {
        let ident = resolveControlKey(key, "Accordion")
        this.single = single
        this.expandedState = match (expanded) {
            case Some(value) => value
            case None => localState<HashSet<Int64>>("Accordion:${ident}:expanded") {
                seedExpanded(initiallyExpanded, single)
            }
        }
        let count = sections.size
        let builtTitles = ArrayList<String>()
        let builtIds = ArrayList<String>()
        let builtBodies = ArrayList<?Widget>()
        // Build header (focus) ids and open bodies in declaration order, so Tab walks header, its body's
        // controls, next header, and so on.
        for (i in 0..count) {
            builtTitles.add(sections[i].title)
            let headerId = focusableControlIdentity("Accordion:${ident}:header:${i}")
            builtIds.add(headerId)
            if (this.expandedState.value.contains(i)) {
                let sectionBody = sections[i].body
                builtBodies.add(Some(buildKeyedChild("Accordion:${ident}:body:${i}") {=> sectionBody()}))
            } else {
                builtBodies.add(None)
            }
        }
        this.titles = builtTitles.toArray()
        this.headerIds = builtIds.toArray()
        this.bodies = builtBodies.toArray()
        this.headerRects = Array<Rect>(count, {_ => Rect.zero()})
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        var height: Float32 = 0.0
        for (i in 0..titles.size) {
            height += ACCORDION_HEADER_H
            match (bodies[i]) {
                case Some(widget) => height += widget.measure(ctx, Size(available.w, LAYOUT_UNBOUNDED)).h
                case None => ()
            }
        }
        Size(available.w, height)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        var y = rect.y
        for (i in 0..titles.size) {
            headerRects[i] = Rect(rect.x, y, rect.w, ACCORDION_HEADER_H)
            y += ACCORDION_HEADER_H
            match (bodies[i]) {
                case Some(widget) =>
                    let bodyHeight = widget.measure(ctx, Size(rect.w, LAYOUT_UNBOUNDED)).h
                    widget.layout(ctx, Rect(rect.x, y, rect.w, bodyHeight))
                    y += bodyHeight
                case None => ()
            }
        }
    }

    public func draw(ctx: UiContext): Unit {
        for (i in 0..titles.size) {
            drawHeader(ctx, i)
            match (bodies[i]) {
                case Some(widget) => widget.draw(ctx)
                case None => ()
            }
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.MouseMove(x, y) => for (i in 0..titles.size) {
                if (headerRects[i].contains(x, y)) {
                    ctx.claimHover(headerIds[i], CursorShape.Interactive)
                }
            }
            case _ => ()
        }
        match (event) {
            case UiEvent.Frame(_) =>
                for (widget in bodies) {
                    match (widget) {
                        case Some(w) => let _ = w.handle(ctx, event)
                        case None => ()
                    }
                }
                return false
            case UiEvent.MouseDown(MouseButton.Left, x, y) => for (i in 0..titles.size) {
                if (headerRects[i].contains(x, y)) {
                    ctx.focus(headerIds[i])
                    toggleSection(i)
                    return true
                }
            }
            case UiEvent.KeyDown(Key.Enter, _) => if (toggleFocusedHeader(ctx)) {
                return true
            }
            case UiEvent.KeyDown(Key.Space, _) => if (toggleFocusedHeader(ctx)) {
                return true
            }
            case _ => ()
        }
        // Route remaining events to the open bodies so their controls work; reverse declaration order.
        var i = titles.size - 1
        while (i >= 0) {
            match (bodies[i]) {
                case Some(w) => if (w.handle(ctx, event)) {
                    return true
                }
                case None => ()
            }
            i -= 1
        }
        false
    }

    public func focusableIds(): Array<String> {
        let ids = ArrayList<String>()
        for (i in 0..titles.size) {
            ids.add(headerIds[i])
            match (bodies[i]) {
                case Some(w) => for (fid in w.focusableIds()) {
                    ids.add(fid)
                }
                case None => ()
            }
        }
        ids.toArray()
    }

    private func toggleFocusedHeader(ctx: UiContext): Bool {
        for (i in 0..titles.size) {
            if (ctx.hasFocus(headerIds[i])) {
                toggleSection(i)
                return true
            }
        }
        false
    }

    // Rebuilds the expansion set as a fresh value so the state write is observed. In single mode,
    // opening a section closes the others.
    private func toggleSection(index: Int64): Unit {
        let next = HashSet<Int64>()
        let isOpen = expandedState.value.contains(index)
        if (!isOpen && single) {
            // Opening in single mode: start from empty, so all others close.
            next.add(index)
        } else {
            for (existing in expandedState.value) {
                next.add(existing)
            }
            if (isOpen) {
                next.remove(index)
            } else {
                next.add(index)
            }
        }
        expandedState.value = next
    }

    private func drawHeader(ctx: UiContext, index: Int64): Unit {
        let rect = headerRects[index]
        let headerId = headerIds[index]
        let isExpanded = expandedState.value.contains(index)
        let hovered = ctx.isHovered(headerId)
        let surface = if (isExpanded || hovered) {
            ctx.theme.fieldActive
        } else {
            ctx.theme.field
        }
        ctx.renderer.fillRoundedRect(rect, ctx.theme.smallRadius, surface)
        if (ctx.showFocusRing(headerId)) {
            drawFocusRing(ctx, rect, ctx.theme.smallRadius)
        }
        drawDisclosure(ctx, rect.x + 16.0, rect.centerY(), isExpanded, ctx.theme.mutedText)
        let textY = rect.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(titles[index], rect.x + 32.0, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
    }
}

// A disclosure chevron pointing down when expanded, right when collapsed.
private func drawDisclosure(ctx: UiContext, cx: Float32, cy: Float32, expanded: Bool, color: Color): Unit {
    let pen = Pen(width: 1.7, color: color)
    let arm: Float32 = 3.5
    if (expanded) {
        ctx.renderer.strokeLine(cx - arm, cy - arm * 0.5, cx, cy + arm * 0.5, pen)
        ctx.renderer.strokeLine(cx, cy + arm * 0.5, cx + arm, cy - arm * 0.5, pen)
    } else {
        ctx.renderer.strokeLine(cx - arm * 0.5, cy - arm, cx + arm * 0.5, cy, pen)
        ctx.renderer.strokeLine(cx + arm * 0.5, cy, cx - arm * 0.5, cy + arm, pen)
    }
}

// The seed expansion set: the requested indices, capped to one when `single`.
private func seedExpanded(indices: Array<Int64>, single: Bool): HashSet<Int64> {
    let set = HashSet<Int64>()
    for (index in indices) {
        if (single && !set.isEmpty()) {
            break
        }
        set.add(index)
    }
    set
}
