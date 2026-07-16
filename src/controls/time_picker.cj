package cui.controls

import std.collection.ArrayList
import sdl.{FontSizes, IconName, Key, MouseButton, Rect, Size, SurfaceStyle, UiEvent, clampF32, drawIcon}
import cui.core.{Bindable, TimeOfDay, CUI_CONTROL_H, CursorShape, Overlay, State, UiContext, Widget, resolveControlKey,
    claimHoverIfInside, drawSurface, emit, localState, registerFocusable}

private let TP_FIELD_W: Float32 = 132.0
private let TP_CELL_W: Float32 = 34.0
private let TP_CELL_H: Float32 = 30.0
private let TP_PAD: Float32 = 8.0
private let TP_GAP: Float32 = 4.0
private let TP_MARGIN: Float32 = 4.0
private let TP_LABEL_H: Float32 = 22.0
private let TP_SECTION_GAP: Float32 = 6.0
private let TP_HOUR_COLS: Int64 = 6
private let TP_HOUR_ROWS: Int64 = 4 // 24 hours across 6 columns
private let TP_MIN_COLS: Int64 = 6
private let TP_POPUP_W: Float32 = TP_CELL_W * Float32(TP_HOUR_COLS) + TP_PAD * 2.0

/*
 * A time field with a pop-up hour/minute grid. The closed control shows the bound `TimeOfDay`; opening
 * it floats a picker over the tree via the interactive overlay (like Dropdown/DatePicker), so its clicks
 * are never stolen by whatever is beneath. The pop-up shows all 24 hours and the minutes at `minuteStep`
 * spacing; clicking an hour or a minute updates the bound value live and keeps the pop-up open (a time
 * needs both parts), so it dismisses on a click outside, Escape, Enter or Tab.
 *
 * While open the arrow keys nudge the time: Up/Down by one `minuteStep`, Left/Right by a whole hour, all
 * wrapping across midnight. The bound value is always a valid 24-hour time (see `TimeOfDay`).
 */
public class TimePicker <: Widget {
    private let id: String
    private let selected: Bindable<TimeOfDay>
    private let open: State<Bool>
    private let overlayOwner: String
    private let step: Int64
    private let hour12: Bool
    private let minutes: Array<Int64>
    private var frame = Rect.zero()

    public init(selected: Bindable<TimeOfDay>, minuteStep!: Int64 = 5, hour12!: Bool = false, key!: ?String = None) {
        let ident = resolveControlKey(key, "TimePicker")
        this.id = ident
        this.selected = selected
        this.overlayOwner = "TimePicker:${ident}"
        this.step = clampMinuteStep(minuteStep)
        this.hour12 = hour12
        this.minutes = minuteOptions(this.step)
        this.open = localState<Bool>("TimePicker:${ident}:open") {false}
        registerFocusable(ident)
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, TP_FIELD_W), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id) || open.value))
        let labelArea = Rect(frame.x + 10.0, frame.y, max(0.0, frame.w - 36.0), frame.h)
        ctx.renderer.pushClip(labelArea)
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(currentLabel(), labelArea.x, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
        ctx.renderer.popClip()
        drawIcon(ctx.renderer, IconName.Clock, Rect(frame.right() - 26.0, frame.centerY() - 8.0, 16.0, 16.0),
            ctx.theme.mutedText)

        if (open.value) {
            let popup = popupRect(ctx)
            ctx.setOverlay(Overlay(handleEvent: {c, e => handleOverlay(c, e, popup)}, render: {c => drawPopup(c, popup)},
                owner: overlayOwner))
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => if (frame.contains(x, y)) {
                ctx.focus(id)
                open.value = true
                return true
            }
            case UiEvent.KeyDown(Key.Enter, _) => return openIfFocused(ctx)
            case UiEvent.KeyDown(Key.Space, _) => return openIfFocused(ctx)
            case UiEvent.KeyDown(Key.Down, _) => return openIfFocused(ctx)
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    public func isFlexible(): Bool {
        false
    }

    private func openIfFocused(ctx: UiContext): Bool {
        if (ctx.hasFocus(id)) {
            open.value = true
            return true
        }
        false
    }

    private func close(ctx: UiContext): Unit {
        open.value = false
        ctx.removeOverlay(overlayOwner)
    }

    private func handleOverlay(ctx: UiContext, event: UiEvent, popup: Rect): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (popup.contains(x, y)) {
                    let h = hourAt(popup, x, y)
                    if (h >= 0) {
                        selected.value = selected.get().withHour(h)
                        return true
                    }
                    let mi = minuteIndexAt(popup, x, y)
                    if (mi >= 0) {
                        selected.value = selected.get().withMinute(minutes[mi])
                        return true
                    }
                    return true // a click on the pop-up chrome: consume but keep it open
                }
                close(ctx) // dismiss on a click outside
                true
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                close(ctx)
                true
            // Space commits like Enter; consumed so it cannot fall through to the field's own Space
            // arm (which would count as a no-op re-open rather than a dismissal).
            case UiEvent.KeyDown(Key.Space, _) =>
                close(ctx)
                true
            case UiEvent.MouseMove(x, y) =>
                if (popup.contains(x, y)) {
                    // Claim the default cursor over the pop-up so a control beneath it cannot set its
                    // shape through the grid.
                    ctx.claimHover(overlayOwner, CursorShape.Default)
                }
                false
            case UiEvent.KeyDown(Key.Up, _) =>
                nudge(step)
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                nudge(-step)
                true
            case UiEvent.KeyDown(Key.Right, _) =>
                nudge(60)
                true
            case UiEvent.KeyDown(Key.Left, _) =>
                nudge(-60)
                true
            case UiEvent.KeyDown(Key.Tab, _) =>
                close(ctx) // commit and let Tab move focus on
                false
            case _ => false
        }
    }

    private func nudge(deltaMinutes: Int64): Unit {
        selected.value = selected.get().addingMinutes(deltaMinutes)
    }

    /*
     * Anchors the pop-up below the field, flipping above when it does not fit, and keeps it inside the
     * viewport horizontally (the pop-up is wider than the field).
     */
    private func popupRect(ctx: UiContext): Rect {
        let h = popupHeight(minutes.size)
        let x = clampF32(frame.x, TP_MARGIN, max(TP_MARGIN, ctx.viewportWidth - TP_POPUP_W - TP_MARGIN))
        let below = frame.bottom() + TP_GAP
        let y = if (below + h <= ctx.viewportHeight - TP_MARGIN) {
            below
        } else {
            max(TP_MARGIN, frame.y - TP_GAP - h)
        }
        Rect(x, y, TP_POPUP_W, h)
    }

    private func hoursOriginY(popup: Rect): Float32 {
        popup.y + TP_PAD + TP_LABEL_H
    }

    private func minutesOriginY(popup: Rect): Float32 {
        hoursOriginY(popup) + Float32(TP_HOUR_ROWS) * TP_CELL_H + TP_SECTION_GAP + TP_LABEL_H
    }

    private func hourCellRect(popup: Rect, hour: Int64): Rect {
        let col = hour % TP_HOUR_COLS
        let row = hour / TP_HOUR_COLS
        Rect(popup.x + TP_PAD + Float32(col) * TP_CELL_W, hoursOriginY(popup) + Float32(row) * TP_CELL_H, TP_CELL_W,
            TP_CELL_H)
    }

    private func minuteCellRect(popup: Rect, index: Int64): Rect {
        let col = index % TP_MIN_COLS
        let row = index / TP_MIN_COLS
        Rect(popup.x + TP_PAD + Float32(col) * TP_CELL_W, minutesOriginY(popup) + Float32(row) * TP_CELL_H, TP_CELL_W,
            TP_CELL_H)
    }

    // The hour (0–23) under a pointer inside the hours grid, or -1 when off it.
    private func hourAt(popup: Rect, x: Float32, y: Float32): Int64 {
        let gx = popup.x + TP_PAD
        let gy = hoursOriginY(popup)
        if (x < gx || x >= gx + TP_CELL_W * Float32(TP_HOUR_COLS) || y < gy || y >= gy + TP_CELL_H *
            Float32(TP_HOUR_ROWS)) {
            return -1
        }
        let col = Int64((x - gx) / TP_CELL_W)
        let row = Int64((y - gy) / TP_CELL_H)
        row * TP_HOUR_COLS + col
    }

    // The index into `minutes` under a pointer inside the minutes grid, or -1 when off it or on a blank
    // trailing cell of the last row.
    private func minuteIndexAt(popup: Rect, x: Float32, y: Float32): Int64 {
        let rows = minuteRowCount(minutes.size)
        let gx = popup.x + TP_PAD
        let gy = minutesOriginY(popup)
        if (x < gx || x >= gx + TP_CELL_W * Float32(TP_MIN_COLS) || y < gy || y >= gy + TP_CELL_H * Float32(rows)) {
            return -1
        }
        let col = Int64((x - gx) / TP_CELL_W)
        let row = Int64((y - gy) / TP_CELL_H)
        let index = row * TP_MIN_COLS + col
        if (index < minutes.size) {
            index
        } else {
            -1
        }
    }

    private func drawPopup(ctx: UiContext, popup: Rect): Unit {
        drawSurface(ctx, popup, popupSurface(ctx))
        let current = selected.get()
        drawSectionLabel(ctx, "时", popup.x + TP_PAD, popup.y + TP_PAD)
        for (h in 0..24) {
            drawCell(ctx, hourCellRect(popup, h), padTwo(h), h == current.hour)
        }
        drawSectionLabel(ctx, "分", popup.x + TP_PAD, minutesOriginY(popup) - TP_LABEL_H)
        for (i in 0..minutes.size) {
            drawCell(ctx, minuteCellRect(popup, i), padTwo(minutes[i]), minutes[i] == current.minute)
        }
    }

    private func drawSectionLabel(ctx: UiContext, text: String, x: Float32, y: Float32): Unit {
        let ty = y + (TP_LABEL_H - ctx.renderer.textHeight(pointSize: FontSizes.CAPTION)) / 2.0
        ctx.renderer.text(text, x + 2.0, ty, ctx.theme.mutedText, pointSize: FontSizes.CAPTION)
    }

    private func drawCell(ctx: UiContext, cell: Rect, text: String, isSelected: Bool): Unit {
        let inner = cell.inset(2.0)
        if (isSelected) {
            ctx.renderer.fillRoundedRect(inner, ctx.theme.smallRadius, ctx.theme.accent)
        } else if (inner.contains(ctx.mouseX, ctx.mouseY)) {
            ctx.renderer.fillRoundedRect(inner, ctx.theme.smallRadius, ctx.theme.fieldActive)
        }
        let color = if (isSelected) {
            ctx.theme.accentText
        } else {
            ctx.theme.text
        }
        let tw = ctx.renderer.textWidth(text, pointSize: FontSizes.CONTROL)
        let ty = cell.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(text, cell.centerX() - tw / 2.0, ty, color, pointSize: FontSizes.CONTROL)
    }

    private func popupSurface(ctx: UiContext): SurfaceStyle {
        SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge, radius: ctx.theme.controlRadius,
            borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 4.0)
    }

    private func currentLabel(): String {
        let time = selected.get()
        if (hour12) {
            time.format12()
        } else {
            time.format()
        }
    }
}

// Clamp the minute spacing into a sensible 1–60 range.
internal func clampMinuteStep(step: Int64): Int64 {
    if (step < 1) {
        1
    } else if (step > 60) {
        60
    } else {
        step
    }
}

// The selectable minute values 0, step, 2·step … below 60.
internal func minuteOptions(step: Int64): Array<Int64> {
    let s = clampMinuteStep(step)
    let result = ArrayList<Int64>()
    var m = 0
    while (m < 60) {
        result.add(m)
        m += s
    }
    result.toArray()
}

// How many 6-column rows the minute options occupy.
internal func minuteRowCount(count: Int64): Int64 {
    (count + TP_MIN_COLS - 1) / TP_MIN_COLS
}

private func popupHeight(minuteCount: Int64): Float32 {
    TP_PAD * 2.0 + TP_LABEL_H + Float32(TP_HOUR_ROWS) * TP_CELL_H + TP_SECTION_GAP + TP_LABEL_H +
        Float32(minuteRowCount(minuteCount)) * TP_CELL_H
}

private func padTwo(value: Int64): String {
    if (value >= 0 && value < 10) {
        "0${value}"
    } else {
        "${value}"
    }
}
