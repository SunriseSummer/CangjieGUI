package cui.controls

import sdl.{FontSizes, Key, MouseButton, Pen, Rect, Size, UiEvent, clampF32}
import cui.core.{Bindable, CUI_CONTROL_H, CUI_SMALL_H, CursorShape, Observable, Spring, UiContext, Widget,
    claimHoverIfInside, controlIdentity, drawSurface, emit, localState, registerFocusable}

private let VALUE_CONTROL_W: Float32 = 180.0

public class ProgressBar <: Widget {
    private let value: Observable<Float32>
    private var lowerBound: Float32
    private var upperBound: Float32
    private let fillSpring: Spring
    private var frame = Rect.zero()

    public init(value: Observable<Float32>, lower!: Float32 = 0.0, upper!: Float32 = 1.0) {
        this.value = value
        this.lowerBound = lower
        this.upperBound = upper
        // The fill eases toward the value, so a jump slides rather than snaps. Retained across
        // rebuilds and started at the current amount, so a static first frame is snapshot-stable.
        let startAmount = normalizedAmount(value.get(), lower, upper)
        this.fillSpring = localState<Spring>("${controlIdentity("ProgressBar")}:fill") {Spring(startAmount)}.value
        emit(this)
    }

    /** Sets the inclusive value range represented by the bar. */
    public func range(lower: Float32, upper: Float32): ProgressBar {
        lowerBound = min(lower, upper)
        upperBound = max(lower, upper)
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, VALUE_CONTROL_W), CUI_SMALL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let amount = normalizedAmount(value.get(), lowerBound, upperBound)
        // Bar and percentage share the animated value, so both slide together toward the target.
        // Clamped: the underdamped spring overshoots slightly, and the fill must not paint past
        // the control's edge (nor the label read -0% / 101%).
        let shown = clampF32(fillSpring.animate(target: amount, deltaMs: ctx.frame.deltaMs), 0.0, 1.0)
        let fill = Rect(frame.x, frame.y, frame.w * shown, frame.h)
        drawSurface(ctx, frame, ctx.theme.fieldSurface(false))
        ctx.renderer.fillRoundedRect(fill, ctx.theme.smallRadius, ctx.theme.accent)
        ctx.renderer.textCenter("${Int64(shown * 100.0)}%", frame, ctx.theme.text, pointSize: FontSizes.CAPTION)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

public class Slider <: Widget {
    private let id: String
    private let value: Bindable<Float32>
    private var lowerBound: Float32
    private var upperBound: Float32
    // 0 means continuous; a positive step snaps the value to `lower + k*step` multiples.
    private var stepSize: Float32 = 0.0
    private var frame = Rect.zero()

    public init(id: String, value: Bindable<Float32>, lower!: Float32 = 0.0, upper!: Float32 = 1.0,
        step!: Float32 = 0.0) {
        this.id = id
        this.value = value
        this.lowerBound = lower
        this.upperBound = upper
        this.stepSize = max(0.0, step)
        // Snap the initial value only for a discrete slider, so a continuous slider keeps its exact
        // starting value (byte-identical to before this parameter existed).
        if (stepSize > 0.0) {
            applyNormalize()
        }
        registerFocusable(id)
        emit(this)
    }

    /** Sets the inclusive value range controlled by the slider. */
    public func range(lower: Float32, upper: Float32): Slider {
        lowerBound = min(lower, upper)
        upperBound = max(lower, upper)
        // Write only when normalizing changes the value: this runs on every frame's rebuild,
        // and an unconditional write would notify the bound state's observers each frame.
        applyNormalize()
        this
    }

    /**
     * Sets the value increment. Values snap to `lower + k*step` multiples; 0 (the default) leaves
     * the slider continuous. Parallels `Stepper.step`, so a slider and a stepper express a discrete
     * range the same way.
     */
    public func step(step: Float32): Slider {
        stepSize = max(0.0, step)
        applyNormalize()
        this
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, VALUE_CONTROL_W), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let track = Rect(frame.x + 8.0, frame.centerY() - 3.0, max(0.0, frame.w - 16.0), 6.0)
        let amount = normalizedAmount(value.value, lowerBound, upperBound)
        let knobX = track.x + track.w * amount
        ctx.renderer.fillRoundedRect(track, ctx.theme.smallRadius, ctx.theme.field)
        ctx
            .renderer
            .fillRoundedRect(Rect(track.x, track.y, track.w * amount, track.h), ctx.theme.smallRadius, ctx.theme.accent)
        ctx.renderer.fillCircle(knobX, frame.centerY() + 1.5, 9.5, ctx.theme.shadow.withAlpha(30))
        ctx.renderer.fillCircle(knobX, frame.centerY(), 8.5, ctx.theme.panelRaised)
        ctx.renderer.strokeCircle(knobX, frame.centerY(), 8.0, Pen(width: 2.0, color: ctx.theme.accent), segments: 40)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, id, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    ctx.beginDrag(id)
                    updateFromX(x)
                    return true
                }
            case UiEvent.MouseMove(x, _) =>
                if (ctx.isDragging(id) && ctx.leftMouseDown) {
                    updateFromX(x)
                    return true
                }
            case UiEvent.MouseUp(MouseButton.Left, x, _) =>
                if (ctx.isDragging(id)) {
                    updateFromX(x)
                    return true
                }
            case UiEvent.KeyDown(Key.Left, _) =>
                if (ctx.hasFocus(id)) {
                    value.value = normalize(value.value - keyboardStep())
                    return true
                }
            case UiEvent.KeyDown(Key.Right, _) =>
                if (ctx.hasFocus(id)) {
                    value.value = normalize(value.value + keyboardStep())
                    return true
                }
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    private func updateFromX(x: Float32): Unit {
        let trackX = frame.x + 8.0
        let trackW = max(1.0, frame.w - 16.0)
        let amount = clampF32((x - trackX) / trackW, 0.0, 1.0)
        value.value = normalize(lowerBound + amount * rangeSize(lowerBound, upperBound))
    }

    private func keyboardStep(): Float32 {
        if (stepSize > 0.0) {
            return stepSize
        }
        rangeSize(lowerBound, upperBound) / 100.0
    }

    // Clamps to the range, then (for a discrete slider) snaps to the nearest step multiple. With
    // stepSize <= 0 this is a plain range clamp, so the continuous path is unchanged.
    private func normalize(raw: Float32): Float32 {
        let clamped = clampF32(raw, lowerBound, upperBound)
        if (stepSize <= 0.0) {
            return clamped
        }
        // clamped >= lowerBound, so the quotient is non-negative and Int64(.. + 0.5) rounds to
        // nearest. A step that overshoots the range is pulled back to the bound by the final clamp.
        let steps = Float32(Int64((clamped - lowerBound) / stepSize + 0.5))
        clampF32(lowerBound + steps * stepSize, lowerBound, upperBound)
    }

    private func applyNormalize(): Unit {
        let normalized = normalize(value.value)
        if (normalized != value.value) {
            value.value = normalized
        }
    }
}

private func normalizedAmount(value: Float32, lower: Float32, upper: Float32): Float32 {
    clampF32((value - lower) / rangeSize(lower, upper), 0.0, 1.0)
}

private func rangeSize(lower: Float32, upper: Float32): Float32 {
    max(0.000001, upper - lower)
}
