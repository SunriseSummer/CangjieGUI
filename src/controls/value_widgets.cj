/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.controls

import sdl.{FontSizes, Key, MouseButton, Pen, Rect, Size, UiEvent, clampF32}
import cui.core.{CUI_CONTROL_H, CUI_SMALL_H, State, UiContext, Widget, drawSurface, emit}

private let VALUE_CONTROL_W: Float32 = 180.0

public class ProgressBar <: Widget {
    private let value: State<Float32>
    private let lower: Float32
    private let upper: Float32
    private var frame = Rect.zero()

    public init(value: State<Float32>, lower!: Float32 = 0.0, upper!: Float32 = 1.0) {
        this.value = value
        this.lower = lower
        this.upper = upper
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, VALUE_CONTROL_W), CUI_SMALL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let amount = normalizedAmount(value.value, lower, upper)
        let fill = Rect(frame.x, frame.y, frame.w * amount, frame.h)
        drawSurface(ctx, frame, ctx.theme.fieldSurface(false))
        ctx.renderer.fillRoundedRect(fill, ctx.theme.smallRadius, ctx.theme.accent)
        ctx.renderer.textCenter("${Int64(amount * 100.0)}%", frame, ctx.theme.text, pointSize: FontSizes.CAPTION)
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

public class Slider <: Widget {
    private let id: String
    private let value: State<Float32>
    private let lower: Float32
    private let upper: Float32
    private var frame = Rect.zero()

    public init(id: String, value: State<Float32>, lower!: Float32 = 0.0, upper!: Float32 = 1.0) {
        this.id = id
        this.value = value
        this.lower = lower
        this.upper = upper
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(available.w, VALUE_CONTROL_W), CUI_CONTROL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let track = Rect(frame.x + 8.0, frame.centerY() - 3.0, max(0.0, frame.w - 16.0), 6.0)
        let amount = normalizedAmount(value.value, lower, upper)
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
                    value.value = clampF32(value.value - keyboardStep(), lower, upper)
                    return true
                }
            case UiEvent.KeyDown(Key.Right, _) =>
                if (ctx.hasFocus(id)) {
                    value.value = clampF32(value.value + keyboardStep(), lower, upper)
                    return true
                }
            case _ => ()
        }
        false
    }

    private func updateFromX(x: Float32): Unit {
        let trackX = frame.x + 8.0
        let trackW = max(1.0, frame.w - 16.0)
        let amount = clampF32((x - trackX) / trackW, 0.0, 1.0)
        value.value = lower + amount * rangeSize(lower, upper)
    }

    private func keyboardStep(): Float32 {
        rangeSize(lower, upper) / 100.0
    }
}

private func normalizedAmount(value: Float32, lower: Float32, upper: Float32): Float32 {
    clampF32((value - lower) / rangeSize(lower, upper), 0.0, 1.0)
}

private func rangeSize(lower: Float32, upper: Float32): Float32 {
    max(0.000001, upper - lower)
}
