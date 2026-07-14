package cui.controls

import sdl.{FontSizes, Key, MouseButton, Pen, Rect, Size, UiEvent}
import cui.core.{Bindable, CUI_CONTROL_H, CursorShape, Spring, UiContext, Widget, requireControlId, claimHoverIfInside, drawFocusRing,
    drawSurface, emit, focusableControlIdentity, localState, reregisterFocusable, registerFocusable}

private let SWITCH_TRACK_W: Float32 = 40.0
private let SWITCH_TRACK_H: Float32 = 22.0
private let PICKER_MIN_W: Float32 = 120.0
private let PICKER_BUTTON_W: Float32 = 34.0
private let STEPPER_BUTTON_W: Float32 = 36.0

/** A binary desktop switch bound to a Boolean state. */
public class Switch <: Widget {
    private let label: String
    private let checked: Bindable<Bool>
    private var controlId: String
    private let knobSpring: Spring
    private var frame = Rect.zero()

    public init(label: String, checked: Bindable<Bool>) {
        this.label = label
        this.checked = checked
        let cid = focusableControlIdentity("Switch:${label}")
        this.controlId = cid
        // The knob position animates between 0 (off) and 1 (on). Retained so the slide
        // survives per-frame rebuilds; started at the current state so a static first frame
        // is already settled (no animation, snapshot-stable).
        let start: Float32 = if (checked.value) {
            1.0
        } else {
            0.0
        }
        this.knobSpring = localState<Spring>("${cid}:knob") {Spring(start)}.value
        emit(this)
    }

    /** Sets an explicit focus and press identity; defaults are unique per build. */
    public func id(value: String): Switch {
        validateControlId(value, "Switch")
        reregisterFocusable(controlId, value)
        controlId = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, SWITCH_TRACK_W + 12.0 + ctx.renderer.textWidth(label)), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let goal: Float32 = if (checked.value) {
            1.0
        } else {
            0.0
        }
        let t = knobSpring.animate(target: goal, deltaMs: ctx.frame.deltaMs)

        let track = Rect(frame.x, frame.centerY() - SWITCH_TRACK_H / 2.0, SWITCH_TRACK_W, SWITCH_TRACK_H)
        // Track colour and knob position share the spring, so both cross together smoothly.
        ctx.renderer.fillRoundedRect(track, SWITCH_TRACK_H / 2.0, ctx.theme.panelEdge.lerp(ctx.theme.accent, t))
        let offX = track.x + 11.0
        let onX = track.right() - 11.0
        let knobX = offX + (onX - offX) * t
        ctx.renderer.fillCircle(knobX, track.centerY() + 1.0, 8.5, ctx.theme.shadow.withAlpha(28))
        ctx.renderer.fillCircle(knobX, track.centerY(), 8.0, ctx.theme.panelRaised)
        let textY = frame.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, track.right() + 12.0, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, track, SWITCH_TRACK_H / 2.0)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        toggleInteraction(ctx, event, frame, controlId, {=> checked.value = !checked.value})
    }

    public func focusableId(): ?String {
        Some(controlId)
    }
}

/** One option in a mutually exclusive integer-valued selection group. */
public class RadioButton <: Widget {
    private let label: String
    private let selected: Bindable<Int64>
    private let optionValue: Int64
    private var controlId: String
    private let dotSpring: Spring
    private var frame = Rect.zero()

    public init(label: String, selected: Bindable<Int64>, value: Int64) {
        this.label = label
        this.selected = selected
        this.optionValue = value
        this.controlId = focusableControlIdentity("RadioButton:${label}:${value}")
        // The inner dot scales in when this option becomes selected. Retained across rebuilds and
        // started at the current state, so a static first frame is settled (snapshot-stable).
        let dotStart: Float32 = if (selected.value == value) {
            1.0
        } else {
            0.0
        }
        this.dotSpring = localState<Spring>("${this.controlId}:dot") {Spring(dotStart)}.value
        emit(this)
    }

    /** Sets an explicit focus and press identity; defaults are unique per build. */
    public func id(value: String): RadioButton {
        validateControlId(value, "RadioButton")
        reregisterFocusable(controlId, value)
        controlId = value
        this
    }

    public func measure(ctx: UiContext, available: Size): Size {
        Size(min(available.w, ctx.renderer.textWidth(label) + 34.0), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let goal: Float32 = if (isSelected()) {
            1.0
        } else {
            0.0
        }
        let t = dotSpring.animate(target: goal, deltaMs: ctx.frame.deltaMs)
        let centerX = frame.x + 9.0
        let centerY = frame.centerY()
        ctx.renderer.fillCircle(centerX, centerY, 9.0, ctx.theme.field)
        ctx.renderer.strokeCircle(centerX, centerY, 8.5,
            Pen(width: 1.5, color: ctx.theme.panelEdge.lerp(ctx.theme.accent, t)), segments: 32)
        // Grows from nothing to the full 4.5-radius dot as the option is selected.
        if (t > 0.001) {
            ctx.renderer.fillCircle(centerX, centerY, 4.5 * t, ctx.theme.accent)
        }
        let textY = centerY - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.text(label, frame.x + 26.0, textY, ctx.theme.text, pointSize: FontSizes.CONTROL)
        if (ctx.showFocusRing(controlId)) {
            drawFocusRing(ctx, Rect(centerX - 9.0, centerY - 9.0, 18.0, 18.0), 9.0)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        toggleInteraction(ctx, event, frame, controlId, {=> selected.value = optionValue})
    }

    public func focusableId(): ?String {
        Some(controlId)
    }

    private func isSelected(): Bool {
        selected.value == optionValue
    }
}

/** A compact previous/next picker for a finite string collection. */
public class Picker <: Widget {
    private let id: String
    private let items: Array<String>
    private let selected: Bindable<Int64>
    private var frame = Rect.zero()

    public init(id: String, items: Array<String>, selected: Bindable<Int64>) {
        validateControlId(id, "Picker")
        this.id = id
        this.items = items
        this.selected = selected
        registerFocusable(id)
        emit(this)
    }

    // Content-adaptive width: wide enough for the longest item between the two chevron
    // zones (stable across selection changes), instead of a fixed generous default.
    public func measure(ctx: UiContext, available: Size): Size {
        var textW: Float32 = 0.0
        for (item in items) {
            textW = max(textW, ctx.renderer.textWidth(item, pointSize: FontSizes.CONTROL))
        }
        let natural = max(PICKER_MIN_W, textW + PICKER_BUTTON_W * 2.0 + 16.0)
        Size(min(available.w, natural), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id)))
        let label = if (items.isEmpty()) {
            "—"
        } else {
            items[currentIndex()]
        }
        // Item text comes from application data; clip it so a long item cannot paint
        // over the chevrons or escape the control surface.
        let labelArea = Rect(frame.x + PICKER_BUTTON_W, frame.y, max(0.0, frame.w - PICKER_BUTTON_W * 2.0), frame.h)
        ctx.renderer.pushClip(labelArea)
        ctx.renderer.textCenter(label, labelArea, ctx.theme.text, pointSize: FontSizes.CONTROL)
        ctx.renderer.popClip()
        ctx.renderer.textCenter("‹", leftButton(), ctx.theme.mutedText, pointSize: FontSizes.TITLE)
        ctx.renderer.textCenter("›", rightButton(), ctx.theme.mutedText, pointSize: FontSizes.TITLE)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    if (leftButton().contains(x, y)) {
                        move(-1)
                    } else if (rightButton().contains(x, y)) {
                        move(1)
                    }
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) =>
                if (ctx.hasFocus(id)) {
                    move(-1)
                    return true
                }
            case UiEvent.KeyDown(Key.Right, _) =>
                if (ctx.hasFocus(id)) {
                    move(1)
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    private func move(delta: Int64): Unit {
        if (items.isEmpty()) {
            return
        }
        selected.value = (currentIndex() + delta + items.size) % items.size
    }

    private func currentIndex(): Int64 {
        clampControlIndex(selected.value, items.size)
    }

    private func leftButton(): Rect {
        Rect(frame.x, frame.y, min(PICKER_BUTTON_W, frame.w), frame.h)
    }

    private func rightButton(): Rect {
        Rect(max(frame.x, frame.right() - PICKER_BUTTON_W), frame.y, min(PICKER_BUTTON_W, frame.w), frame.h)
    }
}

/** An integer value editor with decrement/increment buttons and keyboard support. */
public class Stepper <: Widget {
    private let id: String
    private let value: Bindable<Int64>
    private var lowerBound: Int64 = Int64.Min
    private var upperBound: Int64 = Int64.Max
    private var stepSize: Int64 = 1
    private var frame = Rect.zero()

    public init(
        id: String,
        value: Bindable<Int64>,
        lower!: Int64 = Int64.Min,
        upper!: Int64 = Int64.Max,
        step!: Int64 = 1
    ) {
        validateControlId(id, "Stepper")
        if (step <= 0) {
            throw IllegalArgumentException("Stepper step must be greater than zero")
        }
        this.id = id
        this.value = value
        this.lowerBound = min(lower, upper)
        this.upperBound = max(lower, upper)
        this.stepSize = step
        registerFocusable(id)
        // Clamp the initial value into range, like range() does (write-on-change to avoid churn).
        let clamped = clampInt(value.value)
        if (clamped != value.value) {
            value.value = clamped
        }
        emit(this)
    }

    /** Sets the inclusive range and immediately clamps the current value. */
    public func range(lower: Int64, upper: Int64): Stepper {
        lowerBound = min(lower, upper)
        upperBound = max(lower, upper)
        // Write only when clamping changes the value: this runs on every frame's rebuild,
        // and an unconditional write would notify the bound state's observers each frame.
        let clamped = clampInt(value.value)
        if (clamped != value.value) {
            value.value = clamped
        }
        this
    }

    /** Sets a positive increment. Throws `IllegalArgumentException` for non-positive values. */
    public func step(value: Int64): Stepper {
        if (value <= 0) {
            throw IllegalArgumentException("Stepper step must be greater than zero")
        }
        stepSize = value
        this
    }

    // Content-adaptive width: the value area fits the current number (with a floor so one
    // or two digits stay stable and uncramped), plus the two step buttons.
    public func measure(ctx: UiContext, available: Size): Size {
        let valueW = max(40.0, ctx.renderer.textWidth("${value.value}", pointSize: FontSizes.CONTROL) + 20.0)
        Size(min(available.w, valueW + STEPPER_BUTTON_W * 2.0), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id)))
        ctx.renderer.textCenter("−", decrementButton(), ctx.theme.text, pointSize: FontSizes.TITLE)
        ctx.renderer.textCenter("${value.value}", valueFrame(), ctx.theme.text, pointSize: FontSizes.CONTROL)
        ctx.renderer.textCenter("+", incrementButton(), ctx.theme.text, pointSize: FontSizes.TITLE)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    if (decrementButton().contains(x, y)) {
                        decrement()
                    } else if (incrementButton().contains(x, y)) {
                        increment()
                    }
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) =>
                if (ctx.hasFocus(id)) {
                    decrement()
                    return true
                }
            case UiEvent.KeyDown(Key.Down, _) =>
                if (ctx.hasFocus(id)) {
                    decrement()
                    return true
                }
            case UiEvent.KeyDown(Key.Right, _) =>
                if (ctx.hasFocus(id)) {
                    increment()
                    return true
                }
            case UiEvent.KeyDown(Key.Up, _) =>
                if (ctx.hasFocus(id)) {
                    increment()
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    private func decrement(): Unit {
        value.value = clampInt(if (value.value < lowerBound + stepSize) {
            lowerBound
        } else {
            value.value - stepSize
        })
    }

    private func increment(): Unit {
        value.value = clampInt(if (value.value > upperBound - stepSize) {
            upperBound
        } else {
            value.value + stepSize
        })
    }

    private func clampInt(candidate: Int64): Int64 {
        min(upperBound, max(lowerBound, candidate))
    }

    private func decrementButton(): Rect {
        Rect(frame.x, frame.y, min(STEPPER_BUTTON_W, frame.w), frame.h)
    }

    private func incrementButton(): Rect {
        Rect(max(frame.x, frame.right() - STEPPER_BUTTON_W), frame.y, min(STEPPER_BUTTON_W, frame.w), frame.h)
    }

    private func valueFrame(): Rect {
        Rect(frame.x + STEPPER_BUTTON_W, frame.y, max(0.0, frame.w - STEPPER_BUTTON_W * 2.0), frame.h)
    }
}

private func toggleInteraction(
    ctx: UiContext,
    event: UiEvent,
    frame: Rect,
    id: String,
    activate: () -> Unit
): Bool {
    claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
    match (event) {
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            if (frame.contains(x, y)) {
                ctx.focus(id)
                ctx.press(id)
                return true
            }
        case UiEvent.MouseUp(MouseButton.Left, x, y) =>
            if (ctx.isPressed(id)) {
                if (frame.contains(x, y)) {
                    activate()
                }
                return true
            }
        case UiEvent.KeyDown(Key.Enter, _) =>
            if (ctx.hasFocus(id)) {
                activate()
                return true
            }
        case UiEvent.KeyDown(Key.Space, _) =>
            if (ctx.hasFocus(id)) {
                activate()
                return true
            }
        case _ => ()
    }
    false
}

/** Throws `IllegalArgumentException` when a focusable control receives an empty ID. */
private func validateControlId(id: String, kind: String): Unit {
    requireControlId(id, kind)
}

private func clampControlIndex(index: Int64, count: Int64): Int64 {
    if (count <= 0 || index < 0) {
        0
    } else if (index >= count) {
        count - 1
    } else {
        index
    }
}
