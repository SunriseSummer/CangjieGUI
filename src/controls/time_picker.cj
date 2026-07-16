package cui.controls

import sdl.{FontSizes, IconName, Key, MouseButton, Pen, Rect, Size, SurfaceStyle, UiEvent, clampF32, drawIcon}
import cui.core.{Bindable, CUI_CONTROL_H, CursorShape, Overlay, State, UiContext, Widget, resolveControlKey,
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
private let TP_POPUP_W: Float32 = TP_CELL_W * Float32(TP_HOUR_COLS) + TP_PAD * 2.0
// The minute editor row: −/+ step buttons flanking the editable value box, drawn as one
// stepper-style surface so it reads like the framework `Stepper`.
private let TP_STEP_BTN_W: Float32 = 34.0
private let TP_VALUE_W: Float32 = 48.0
private let TP_ROW_GAP: Float32 = 6.0
private let TP_SLIDER_H: Float32 = 26.0
// Hover/selection fills sit this far inside each grid cell; section labels and the minute editor
// row share the same inset vertically, so both sections breathe identically under their labels.
private let TP_CELL_INSET: Float32 = 2.0
// The minute editor (stepper surface and slider track) is inset from the content edge onto the
// hour digits' column: the digits centre in their 34px cells, (34 − width("00")) / 2 ≈ 9. The same
// inset keeps the slider knob (radius ≈ 9) clear of the pop-up border at both track ends.
private let TP_EDITOR_INSET: Float32 = 9.0

/*
 * A time field with a pop-up picker. The closed control shows the bound `TimeOfDay`; opening it floats
 * the picker over the tree via the interactive overlay (like Dropdown/DatePicker), so its clicks are
 * never stolen by whatever is beneath. The pop-up pairs a 24-hour grid with a per-minute editor: the
 * hour is one click away, and the minute offers three grains — a horizontal slider for coarse dragging
 * (snapping to `minuteStep` multiples, with both track ends exact), −/+ step buttons for single-minute
 * fine tuning, and direct typing for quick edits (click the value box or just start typing digits; a
 * leading 6–9 commits at once since no valid minute continues it, a second digit commits the pair,
 * Backspace clears, Enter commits and Escape cancels the pending digit). Picking an hour or a minute
 * updates the bound value live and keeps the pop-up open (a time needs both parts), so it dismisses on
 * a click outside, Escape, Enter or Tab.
 *
 * While open the arrow keys nudge the time: Up/Down by one minute, Left/Right by a whole hour, all
 * wrapping across midnight. The bound value is always a valid 24-hour time (see `TimeOfDay`).
 */
public class TimePicker <: Widget {
    private let id: String
    private let selected: Bindable<TimeOfDay>
    private let open: State<Bool>
    private let overlayOwner: String
    private let sliderId: String
    private let step: Int64
    private let hour12: Bool
    // A minute being typed: `editing` marks the value box active, `editBuffer` holds the pending
    // digit (at most one — a second digit or a leading 6–9 commits immediately, see typeDigit).
    private let editing: State<Bool>
    private let editBuffer: State<String>
    private var frame = Rect.zero()

    public init(selected: Bindable<TimeOfDay>, minuteStep!: Int64 = 5, hour12!: Bool = false, key!: ?String = None) {
        let ident = resolveControlKey(key, "TimePicker")
        this.id = ident
        this.selected = selected
        this.overlayOwner = "TimePicker:${ident}"
        this.sliderId = "TimePicker:${ident}:slider"
        // The coarse grain of the slider only; the step buttons, typing and arrow keys always
        // move by single minutes, so every minute stays reachable regardless of the step.
        this.step = clampMinuteStep(minuteStep)
        this.hour12 = hour12
        this.open = localState<Bool>("TimePicker:${ident}:open") {false}
        this.editing = localState<Bool>("TimePicker:${ident}:editing") {false}
        this.editBuffer = localState<String>("TimePicker:${ident}:editBuffer") {""}
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
        cancelEdit() // a reopened pop-up must not resume a half-typed minute
        open.value = false
        ctx.removeOverlay(overlayOwner)
    }

    private func handleOverlay(ctx: UiContext, event: UiEvent, popup: Rect): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (popup.contains(x, y)) {
                    // A press anywhere but the value box commits the pending typed minute first,
                    // like focus leaving a field.
                    if (!valueRect(popup).contains(x, y)) {
                        commitEdit()
                    }
                    let h = hourAt(popup, x, y)
                    if (h >= 0) {
                        selected.value = selected.get().withHour(h)
                        return true
                    }
                    if (minusRect(popup).contains(x, y)) {
                        stepMinute(-1)
                        return true
                    }
                    if (plusRect(popup).contains(x, y)) {
                        stepMinute(1)
                        return true
                    }
                    if (valueRect(popup).contains(x, y)) {
                        // A re-click while already editing keeps the pending digit (it is visible
                        // in the box); only a fresh click opens an empty edit.
                        if (!editing.value) {
                            editing.value = true
                            editBuffer.value = ""
                        }
                        return true
                    }
                    if (sliderRect(popup).contains(x, y)) {
                        ctx.beginDrag(sliderId)
                        applySlider(popup, x)
                        return true
                    }
                    return true // a click on the pop-up chrome: consume but keep it open
                }
                commitEdit() // dismiss on a click outside, keeping what was typed (like blur)
                close(ctx)
                true
            case UiEvent.MouseMove(x, y) =>
                if (ctx.isDragging(sliderId) && ctx.leftMouseDown) {
                    // A live slider drag follows the pointer even past the pop-up edge.
                    ctx.claimHover(overlayOwner, CursorShape.Interactive)
                    applySlider(popup, x)
                    return true
                }
                if (popup.contains(x, y)) {
                    // Claim the cursor over the pop-up so a control beneath it cannot set its
                    // shape through the picker; clickable regions advertise interactivity.
                    let shape = if (hourAt(popup, x, y) >= 0 || overMinuteControls(popup, x, y)) {
                        CursorShape.Interactive
                    } else {
                        CursorShape.Default
                    }
                    ctx.claimHover(overlayOwner, shape)
                }
                false
            case UiEvent.MouseUp(MouseButton.Left, x, _) =>
                if (ctx.isDragging(sliderId)) {
                    applySlider(popup, x)
                    return true
                }
                false
            case UiEvent.KeyDown(Key.Digit(code), _) =>
                typeDigit(Int64(code) - 48)
                true
            case UiEvent.KeyDown(Key.Backspace, _) =>
                if (editing.value) {
                    editBuffer.value = "" // the buffer holds at most one pending digit
                    return true
                }
                false
            case UiEvent.KeyDown(Key.Escape, _) =>
                if (editing.value) {
                    cancelEdit() // first Escape abandons the typed digit, keeping the pop-up open
                } else {
                    close(ctx)
                }
                true
            case UiEvent.KeyDown(Key.Enter, _) =>
                if (editing.value) {
                    commitEdit() // first Enter lands the typed minute, a second closes
                } else {
                    close(ctx)
                }
                true
            // Space commits like Enter; consumed so it cannot fall through to the field's own Space
            // arm (which would count as a no-op re-open rather than a dismissal).
            case UiEvent.KeyDown(Key.Space, _) =>
                if (editing.value) {
                    commitEdit()
                } else {
                    close(ctx)
                }
                true
            case UiEvent.KeyDown(Key.Up, _) =>
                commitEdit()
                nudge(1)
                true
            case UiEvent.KeyDown(Key.Down, _) =>
                commitEdit()
                nudge(-1)
                true
            case UiEvent.KeyDown(Key.Right, _) =>
                commitEdit()
                nudge(60)
                true
            case UiEvent.KeyDown(Key.Left, _) =>
                commitEdit()
                nudge(-60)
                true
            case UiEvent.KeyDown(Key.Tab, _) =>
                commitEdit()
                close(ctx) // commit and let Tab move focus on
                false
            case _ => false
        }
    }

    private func nudge(deltaMinutes: Int64): Unit {
        selected.value = selected.get().addingMinutes(deltaMinutes)
    }

    // The −/+ buttons wrap within the hour (59 → 00), like a spinner's minute field: the section
    // edits the minute alone, so it never carries into the hour the way the keyboard nudge does.
    private func stepMinute(delta: Int64): Unit {
        let minute = (selected.get().minute + delta + 60) % 60
        selected.value = selected.get().withMinute(minute)
    }

    private func typeDigit(digit: Int64): Unit {
        if (digit < 0 || digit > 9) {
            return
        }
        // Typing works without clicking the value box first: the first digit opens the edit.
        let buffer = if (editing.value) {
            editBuffer.value
        } else {
            ""
        }
        let (next, commit) = appendMinuteDigit(buffer, digit)
        match (commit) {
            case Some(minute) =>
                selected.value = selected.get().withMinute(minute)
                cancelEdit()
            case None =>
                editing.value = true
                editBuffer.value = next
        }
    }

    private func commitEdit(): Unit {
        if (!editing.value) {
            return
        }
        if (!editBuffer.value.isEmpty()) {
            selected.value = selected.get().withMinute(parseBufferedMinute(editBuffer.value))
        }
        cancelEdit()
    }

    private func cancelEdit(): Unit {
        editing.value = false
        editBuffer.value = ""
    }

    private func applySlider(popup: Rect, x: Float32): Unit {
        let track = trackRect(popup)
        selected.value = selected.get().withMinute(sliderMinute(track.x, track.w, x, step))
    }

    /*
     * Anchors the pop-up below the field, flipping above when it does not fit, and keeps it inside the
     * viewport horizontally (the pop-up is wider than the field).
     */
    private func popupRect(ctx: UiContext): Rect {
        let h = popupHeight()
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

    private func minuteLabelY(popup: Rect): Float32 {
        hoursOriginY(popup) + Float32(TP_HOUR_ROWS) * TP_CELL_H + TP_SECTION_GAP
    }

    // The editor surface hangs below the 分 label by the same inset that separates the 时 label
    // from the first hour cell's fill, so both sections breathe identically.
    private func stepperRowY(popup: Rect): Float32 {
        minuteLabelY(popup) + TP_LABEL_H + TP_CELL_INSET
    }

    private func minusRect(popup: Rect): Rect {
        Rect(popup.x + TP_PAD + TP_EDITOR_INSET, stepperRowY(popup), TP_STEP_BTN_W, TP_CELL_H)
    }

    private func valueRect(popup: Rect): Rect {
        Rect(popup.x + TP_PAD + TP_EDITOR_INSET + TP_STEP_BTN_W, stepperRowY(popup), TP_VALUE_W, TP_CELL_H)
    }

    private func plusRect(popup: Rect): Rect {
        Rect(popup.x + TP_PAD + TP_EDITOR_INSET + TP_STEP_BTN_W + TP_VALUE_W, stepperRowY(popup), TP_STEP_BTN_W,
            TP_CELL_H)
    }

    private func stepperRect(popup: Rect): Rect {
        Rect(popup.x + TP_PAD + TP_EDITOR_INSET, stepperRowY(popup), TP_STEP_BTN_W * 2.0 + TP_VALUE_W, TP_CELL_H)
    }

    private func sliderRect(popup: Rect): Rect {
        Rect(popup.x + TP_PAD, stepperRowY(popup) + TP_CELL_H + TP_ROW_GAP, popup.w - TP_PAD * 2.0, TP_SLIDER_H)
    }

    // The track shares the stepper's left edge and pulls in symmetrically on the right, so the
    // knob overhang at either extreme stays well inside the pop-up border.
    private func trackRect(popup: Rect): Rect {
        let row = sliderRect(popup)
        Rect(row.x + TP_EDITOR_INSET, row.centerY() - 3.0, max(1.0, row.w - TP_EDITOR_INSET * 2.0), 6.0)
    }

    private func overMinuteControls(popup: Rect, x: Float32, y: Float32): Bool {
        stepperRect(popup).contains(x, y) || sliderRect(popup).contains(x, y)
    }

    private func hourCellRect(popup: Rect, hour: Int64): Rect {
        let col = hour % TP_HOUR_COLS
        let row = hour / TP_HOUR_COLS
        Rect(popup.x + TP_PAD + Float32(col) * TP_CELL_W, hoursOriginY(popup) + Float32(row) * TP_CELL_H, TP_CELL_W,
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

    private func drawPopup(ctx: UiContext, popup: Rect): Unit {
        drawSurface(ctx, popup, popupSurface(ctx))
        let current = selected.get()
        drawSectionLabel(ctx, "时", popup.x + TP_PAD, popup.y + TP_PAD)
        for (h in 0..24) {
            drawCell(ctx, hourCellRect(popup, h), padTwo(h), h == current.hour)
        }
        drawSectionLabel(ctx, "分", popup.x + TP_PAD, minuteLabelY(popup))
        drawMinuteStepper(ctx, popup, current.minute)
        drawMinuteSlider(ctx, popup, current.minute)
    }

    private func drawSectionLabel(ctx: UiContext, text: String, x: Float32, y: Float32): Unit {
        let ty = y + (TP_LABEL_H - ctx.renderer.textHeight(pointSize: FontSizes.CAPTION)) / 2.0
        ctx.renderer.text(text, x + TP_CELL_INSET, ty, ctx.theme.mutedText, pointSize: FontSizes.CAPTION)
    }

    private func drawCell(ctx: UiContext, cell: Rect, text: String, isSelected: Bool): Unit {
        let inner = cell.inset(TP_CELL_INSET)
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

    // One stepper-style surface (like the framework `Stepper`): − and + at the sides, the editable
    // minute in the middle. While a digit is being typed the whole group shows the active field
    // border, and an empty buffer ghosts the current minute so the box never reads blank.
    private func drawMinuteStepper(ctx: UiContext, popup: Rect, minute: Int64): Unit {
        drawSurface(ctx, stepperRect(popup), ctx.theme.fieldSurface(editing.value))
        drawStepButton(ctx, minusRect(popup), "−")
        drawStepButton(ctx, plusRect(popup), "+")
        let box = valueRect(popup)
        if (editing.value && !editBuffer.value.isEmpty()) {
            ctx.renderer.textCenter(editBuffer.value, box, ctx.theme.text, pointSize: FontSizes.CONTROL)
        } else if (editing.value) {
            ctx.renderer.textCenter(padTwo(minute), box, ctx.theme.mutedText, pointSize: FontSizes.CONTROL)
        } else {
            ctx.renderer.textCenter(padTwo(minute), box, ctx.theme.text, pointSize: FontSizes.CONTROL)
        }
    }

    private func drawStepButton(ctx: UiContext, cell: Rect, glyph: String): Unit {
        let inner = cell.inset(TP_CELL_INSET)
        if (inner.contains(ctx.mouseX, ctx.mouseY)) {
            ctx.renderer.fillRoundedRect(inner, ctx.theme.smallRadius, ctx.theme.fieldActive)
        }
        ctx.renderer.textCenter(glyph, cell, ctx.theme.text, pointSize: FontSizes.TITLE)
    }

    // The coarse minute slider, in the framework `Slider`'s visual language: full track for 0–59
    // with the knob at the exact current minute, while drags snap to `minuteStep` multiples.
    private func drawMinuteSlider(ctx: UiContext, popup: Rect, minute: Int64): Unit {
        let row = sliderRect(popup)
        let track = trackRect(popup)
        let amount = Float32(minute) / 59.0
        let knobX = track.x + track.w * amount
        ctx.renderer.fillRoundedRect(track, ctx.theme.smallRadius, ctx.theme.field)
        ctx.renderer.fillRoundedRect(Rect(track.x, track.y, track.w * amount, track.h), ctx.theme.smallRadius,
            ctx.theme.accent)
        ctx.renderer.fillCircle(knobX, row.centerY() + 1.5, 9.5, ctx.theme.shadow.withAlpha(30))
        ctx.renderer.fillCircle(knobX, row.centerY(), 8.5, ctx.theme.panelRaised)
        ctx.renderer.strokeCircle(knobX, row.centerY(), 8.0, Pen(width: 2.0, color: ctx.theme.accent), segments: 40)
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

private func popupHeight(): Float32 {
    TP_PAD * 2.0 + TP_LABEL_H + Float32(TP_HOUR_ROWS) * TP_CELL_H + TP_SECTION_GAP + TP_LABEL_H + TP_CELL_INSET +
        TP_CELL_H + TP_ROW_GAP + TP_SLIDER_H
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

/*
 * The minute for a pointer at `x` on a slider track spanning 0–59: the position maps linearly, then
 * snaps to the nearest `step` multiple. The final clamp makes both extremes exact — the far right
 * lands on 59 even when the step does not divide it, so the ends of the track always mean 00 and 59.
 */
internal func sliderMinute(trackX: Float32, trackW: Float32, x: Float32, step: Int64): Int64 {
    let amount = clampF32((x - trackX) / max(1.0, trackW), 0.0, 1.0)
    if (amount >= 1.0) {
        // The track end means 59 unconditionally: for steps 40–58 the rounded multiple below
        // would win (59/s + 0.5 < 2), so the end is pinned rather than left to the snap.
        return 59
    }
    let raw = amount * 59.0
    let s = clampMinuteStep(step)
    let snapped = Int64(raw / Float32(s) + 0.5) * s
    min(59, snapped)
}

/*
 * Feeds one typed digit into the minute edit buffer, returning the new buffer and, when the digit
 * completes a minute, the committed value. A leading 6–9 commits immediately (no valid two-digit
 * minute starts with it); a second digit always completes the pair, so the buffer never holds more
 * than one digit and a committed value is always 0–59.
 */
internal func appendMinuteDigit(buffer: String, digit: Int64): (String, ?Int64) {
    if (buffer.isEmpty()) {
        if (digit > 5) {
            return ("", Some(digit))
        }
        return ("${digit}", None)
    }
    ("", Some(parseBufferedMinute(buffer) * 10 + digit))
}

// The buffer holds ASCII digits only (see appendMinuteDigit), so a plain positional parse suffices.
internal func parseBufferedMinute(buffer: String): Int64 {
    var value = 0
    for (r in buffer.toRuneArray()) {
        value = value * 10 + (Int64(UInt32(r)) - 48)
    }
    value
}

private func padTwo(value: Int64): String {
    if (value >= 0 && value < 10) {
        "0${value}"
    } else {
        "${value}"
    }
}
