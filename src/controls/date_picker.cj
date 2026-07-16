package cui.controls

import sdl.{FontSizes, IconName, Key, MouseButton, Pen, Rect, Size, SurfaceStyle, UiEvent, clampF32, drawIcon}
import cui.core.{Bindable, CUI_CONTROL_H, CursorShape, Overlay, State, UiContext, Widget,
    resolveControlKey, claimHoverIfInside, drawSurface, emit, localState, registerFocusable}

private let DP_FIELD_W: Float32 = 176.0
private let DP_CELL_W: Float32 = 34.0
private let DP_CELL_H: Float32 = 30.0
private let DP_HEADER_H: Float32 = 34.0
private let DP_WEEKDAY_H: Float32 = 24.0
private let DP_PAD: Float32 = 8.0
private let DP_GAP: Float32 = 4.0
private let DP_MARGIN: Float32 = 4.0
private let DP_GRID_ROWS: Int64 = 6
private let DP_POPUP_W: Float32 = DP_CELL_W * 7.0 + DP_PAD * 2.0
private let DP_POPUP_H: Float32 = DP_PAD * 2.0 + DP_HEADER_H + DP_WEEKDAY_H + DP_CELL_H * Float32(DP_GRID_ROWS)

private let DP_WEEKDAYS: Array<String> = ["日", "一", "二", "三", "四", "五", "六"]

/*
 * A date field with a pop-up month calendar. The closed control shows the bound `CalendarDate`; opening
 * it floats a calendar over the tree via the interactive overlay (like Dropdown), so its clicks are
 * never stolen by whatever is beneath. Clicking a day selects it and closes; the header arrows page
 * months; clicking outside or pressing Escape dismisses.
 *
 * While open the arrow keys move a highlighted day (crossing month boundaries, which pages the view),
 * Home/End page months, Enter or Space commits the highlighted day and Escape closes. The bound value is
 * always a valid calendar date (see `CalendarDate`), so downstream code never sees an impossible day.
 */
public class DatePicker <: Widget {
    private let id: String
    private let selected: Bindable<CalendarDate>
    private let open: State<Bool>
    private let overlayOwner: String
    // The month on display in the pop-up (may differ from the selected month while browsing), and the
    // day the keyboard highlight sits on. Retained across the per-frame rebuild while open.
    private let viewYear: State<Int64>
    private let viewMonth: State<Int64>
    private let focusedDay: State<Int64>
    private var frame = Rect.zero()

    public init(selected: Bindable<CalendarDate>, key!: ?String = None) {
        let ident = resolveControlKey(key, "DatePicker")
        this.id = ident
        this.selected = selected
        this.overlayOwner = "DatePicker:${ident}"
        this.open = localState<Bool>("DatePicker:${ident}:open") {false}
        this.viewYear = localState<Int64>("DatePicker:${ident}:viewYear") {selected.get().year}
        this.viewMonth = localState<Int64>("DatePicker:${ident}:viewMonth") {selected.get().month}
        this.focusedDay = localState<Int64>("DatePicker:${ident}:focusedDay") {selected.get().day}
        registerFocusable(ident)
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, DP_FIELD_W), CUI_CONTROL_H)
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
        drawIcon(ctx.renderer, IconName.Calendar, Rect(frame.right() - 26.0, frame.centerY() - 8.0, 16.0, 16.0),
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
                openPopup()
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
            openPopup()
            return true
        }
        false
    }

    // Opens the calendar showing the selected date's month with the highlight on it.
    private func openPopup(): Unit {
        let current = selected.get()
        viewYear.value = current.year
        viewMonth.value = current.month
        focusedDay.value = current.day
        open.value = true
    }

    private func close(ctx: UiContext): Unit {
        open.value = false
        ctx.removeOverlay(overlayOwner)
    }

    private func handleOverlay(ctx: UiContext, event: UiEvent, popup: Rect): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (popup.contains(x, y)) {
                    if (prevArrowRect(popup).contains(x, y)) {
                        shiftMonth(-1)
                    } else if (nextArrowRect(popup).contains(x, y)) {
                        shiftMonth(1)
                    } else {
                        let day = dayAt(popup, x, y)
                        if (day > 0) {
                            selectDay(ctx, day)
                        }
                    }
                    return true
                }
                close(ctx) // dismiss on a click outside the calendar
                true
            case UiEvent.KeyDown(Key.Escape, _) =>
                close(ctx)
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                selectDay(ctx, focusedDay.value)
                true
            // Space commits like Enter (the standard select key in a date grid). It must be consumed
            // here regardless: unconsumed it would fall through to the field's own handler, whose Space
            // arm re-runs openPopup and snaps the browsed month back to the selection.
            case UiEvent.KeyDown(Key.Space, _) =>
                selectDay(ctx, focusedDay.value)
                true
            case UiEvent.MouseMove(x, y) =>
                if (popup.contains(x, y)) {
                    // Claim the default cursor over the calendar so a control beneath it cannot set
                    // its shape through the popup.
                    ctx.claimHover(overlayOwner, CursorShape.Default)
                }
                false
            case UiEvent.KeyDown(Key.Left, _) =>
                moveFocus(-1)
                true
            case UiEvent.KeyDown(Key.Right, _) =>
                moveFocus(1)
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                moveFocus(-7)
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                moveFocus(7)
                true
            case UiEvent.KeyDown(Key.Home, _) =>
                shiftMonth(-1)
                true
            case UiEvent.KeyDown(Key.End, _) =>
                shiftMonth(1)
                true
            case UiEvent.KeyDown(Key.Tab, _) =>
                close(ctx) // commit the browse and let Tab move focus on
                false
            case _ => false
        }
    }

    // Pages the shown month, keeping the highlighted day within the new month's length.
    private func shiftMonth(delta: Int64): Unit {
        let shifted = CalendarDate(viewYear.value, viewMonth.value, 1).addingMonths(delta)
        viewYear.value = shifted.year
        viewMonth.value = shifted.month
        let dim = shifted.daysInMonth()
        if (focusedDay.value > dim) {
            focusedDay.value = dim
        }
    }

    // Moves the highlight by whole days, rolling into the adjacent month (and paging the view) at edges.
    private func moveFocus(deltaDays: Int64): Unit {
        let next = CalendarDate(viewYear.value, viewMonth.value, focusedDay.value).addingDays(deltaDays)
        viewYear.value = next.year
        viewMonth.value = next.month
        focusedDay.value = next.day
    }

    private func selectDay(ctx: UiContext, day: Int64): Unit {
        selected.value = CalendarDate(viewYear.value, viewMonth.value, day)
        close(ctx)
    }

    /*
     * Anchors the calendar below the field, flipping above when it does not fit, and keeps it inside
     * the viewport horizontally (the calendar is wider than the field).
     */
    private func popupRect(ctx: UiContext): Rect {
        let x = clampF32(frame.x, DP_MARGIN, max(DP_MARGIN, ctx.viewportWidth - DP_POPUP_W - DP_MARGIN))
        let below = frame.bottom() + DP_GAP
        let y = if (below + DP_POPUP_H <= ctx.viewportHeight - DP_MARGIN) {
            below
        } else {
            max(DP_MARGIN, frame.y - DP_GAP - DP_POPUP_H)
        }
        Rect(x, y, DP_POPUP_W, DP_POPUP_H)
    }

    private func headerRect(popup: Rect): Rect {
        Rect(popup.x + DP_PAD, popup.y + DP_PAD, popup.w - DP_PAD * 2.0, DP_HEADER_H)
    }

    private func prevArrowRect(popup: Rect): Rect {
        let header = headerRect(popup)
        Rect(header.x, header.y, DP_HEADER_H, DP_HEADER_H)
    }

    private func nextArrowRect(popup: Rect): Rect {
        let header = headerRect(popup)
        Rect(header.right() - DP_HEADER_H, header.y, DP_HEADER_H, DP_HEADER_H)
    }

    private func gridOriginX(popup: Rect): Float32 {
        popup.x + DP_PAD
    }

    private func gridOriginY(popup: Rect): Float32 {
        popup.y + DP_PAD + DP_HEADER_H + DP_WEEKDAY_H
    }

    private func cellRect(popup: Rect, row: Int64, col: Int64): Rect {
        Rect(gridOriginX(popup) + Float32(col) * DP_CELL_W, gridOriginY(popup) + Float32(row) * DP_CELL_H, DP_CELL_W,
            DP_CELL_H)
    }

    // The day number under a pointer inside the grid, or 0 when the pointer is off the grid or on a
    // blank leading/trailing cell.
    private func dayAt(popup: Rect, x: Float32, y: Float32): Int64 {
        let gx = gridOriginX(popup)
        let gy = gridOriginY(popup)
        if (x < gx || x >= gx + DP_CELL_W * 7.0 || y < gy || y >= gy + DP_CELL_H * Float32(DP_GRID_ROWS)) {
            return 0
        }
        let col = Int64((x - gx) / DP_CELL_W)
        let row = Int64((y - gy) / DP_CELL_H)
        let firstWd = CalendarDate(viewYear.value, viewMonth.value, 1).firstWeekdayIndex()
        let day = row * 7 + col - firstWd + 1
        if (day >= 1 && day <= CalendarDate(viewYear.value, viewMonth.value, 1).daysInMonth()) {
            day
        } else {
            0
        }
    }

    private func drawPopup(ctx: UiContext, popup: Rect): Unit {
        drawSurface(ctx, popup, popupSurface(ctx))
        drawHeader(ctx, popup)
        drawWeekdayRow(ctx, popup)
        drawDayGrid(ctx, popup)
    }

    private func drawHeader(ctx: UiContext, popup: Rect): Unit {
        let header = headerRect(popup)
        let title = "${viewYear.value} 年 ${viewMonth.value} 月"
        let titleW = ctx.renderer.textWidth(title, pointSize: FontSizes.CONTROL)
        let titleY = header.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(title, header.centerX() - titleW / 2.0, titleY, ctx.theme.text, pointSize: FontSizes.CONTROL)
        drawArrow(ctx, prevArrowRect(popup), true)
        drawArrow(ctx, nextArrowRect(popup), false)
    }

    private func drawArrow(ctx: UiContext, box: Rect, pointsLeft: Bool): Unit {
        let hovered = box.contains(ctx.mouseX, ctx.mouseY)
        let color = if (hovered) {
            ctx.theme.accent
        } else {
            ctx.theme.mutedText
        }
        let pen = Pen(width: 1.8, color: color)
        let cx = box.centerX()
        let cy = box.centerY()
        if (pointsLeft) {
            ctx.renderer.strokeLine(cx + 3.0, cy - 5.0, cx - 3.0, cy, pen)
            ctx.renderer.strokeLine(cx - 3.0, cy, cx + 3.0, cy + 5.0, pen)
        } else {
            ctx.renderer.strokeLine(cx - 3.0, cy - 5.0, cx + 3.0, cy, pen)
            ctx.renderer.strokeLine(cx + 3.0, cy, cx - 3.0, cy + 5.0, pen)
        }
    }

    private func drawWeekdayRow(ctx: UiContext, popup: Rect): Unit {
        let gx = gridOriginX(popup)
        let wy = popup.y + DP_PAD + DP_HEADER_H
        let labelY = wy + (DP_WEEKDAY_H - ctx.renderer.textHeight(pointSize: FontSizes.CAPTION)) / 2.0
        for (col in 0..7) {
            let label = DP_WEEKDAYS[col]
            let lw = ctx.renderer.textWidth(label, pointSize: FontSizes.CAPTION)
            let cx = gx + Float32(col) * DP_CELL_W + DP_CELL_W / 2.0
            ctx.renderer.text(label, cx - lw / 2.0, labelY, ctx.theme.mutedText, pointSize: FontSizes.CAPTION)
        }
    }

    private func drawDayGrid(ctx: UiContext, popup: Rect): Unit {
        let monthStart = CalendarDate(viewYear.value, viewMonth.value, 1)
        let firstWd = monthStart.firstWeekdayIndex()
        let dim = monthStart.daysInMonth()
        let current = selected.get()
        let today = CalendarDate.today()
        for (row in 0..DP_GRID_ROWS) {
            for (col in 0..7) {
                let day = row * 7 + col - firstWd + 1
                if (day >= 1 && day <= dim) {
                    drawDayCell(ctx, cellRect(popup, row, col), day, current, today)
                }
            }
        }
    }

    private func drawDayCell(ctx: UiContext, cell: Rect, day: Int64, current: CalendarDate, today: CalendarDate): Unit {
        let inner = cell.inset(2.0)
        let isSelected = viewYear.value == current.year && viewMonth.value == current.month && day == current.day
        let isToday = viewYear.value == today.year && viewMonth.value == today.month && day == today.day
        let isFocused = day == focusedDay.value
        if (isSelected) {
            ctx.renderer.fillRoundedRect(inner, ctx.theme.smallRadius, ctx.theme.accent)
        } else if (inner.contains(ctx.mouseX, ctx.mouseY)) {
            ctx.renderer.fillRoundedRect(inner, ctx.theme.smallRadius, ctx.theme.fieldActive)
        } else if (isToday) {
            ctx.renderer.fillRoundedRect(inner, ctx.theme.smallRadius, ctx.theme.accentSoft)
        }
        if (isFocused && !isSelected) {
            ctx.renderer.strokeRoundedRect(inner, ctx.theme.smallRadius, Pen(width: 1.4, color: ctx.theme.accent))
        }
        let color = if (isSelected) {
            ctx.theme.accentText
        } else {
            ctx.theme.text
        }
        let text = "${day}"
        let tw = ctx.renderer.textWidth(text, pointSize: FontSizes.CONTROL)
        let ty = cell.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(text, cell.centerX() - tw / 2.0, ty, color, pointSize: FontSizes.CONTROL)
    }

    private func popupSurface(ctx: UiContext): SurfaceStyle {
        SurfaceStyle(ctx.theme.panelRaised, border: ctx.theme.panelEdge, radius: ctx.theme.controlRadius,
            borderWidth: 1.0, shadow: ctx.theme.shadow, shadowOffsetY: 4.0)
    }

    private func currentLabel(): String {
        let date = selected.get()
        "${date.year} 年 ${date.month} 月 ${date.day} 日"
    }
}
