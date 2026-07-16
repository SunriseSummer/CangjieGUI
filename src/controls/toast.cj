package cui.controls

import std.collection.ArrayList
import sdl.{Color, FontSizes, Rect, Size, UiEvent, clampF32}
import cui.core.{UiContext, Widget, emit}

private let TOAST_MARGIN: Float32 = 16.0
private let TOAST_WIDTH: Float32 = 320.0
private let TOAST_HEIGHT: Float32 = 46.0
private let TOAST_GAP: Float32 = 10.0
// Entrance slide/fade and exit fade durations, in milliseconds.
private let TOAST_SLIDE_MS: Float32 = 150.0
private let TOAST_FADE_MS: Float32 = 300.0

/** The kind of a toast, which sets its accent colour. */
public enum ToastKind {
    | Info
    | Success
    | Warning
    | Error
}

// One live toast: its content and the time it has been shown / has left to live.
class ActiveToast {
    let id: Int64
    let message: String
    let kind: ToastKind
    var ageMs: UInt64
    var remainingMs: UInt64

    init(id: Int64, message: String, kind: ToastKind, remainingMs: UInt64) {
        this.id = id
        this.message = message
        this.kind = kind
        this.ageMs = 0
        this.remainingMs = remainingMs
    }
}

/**
 * A controller for transient toast notifications. Create one for the app's lifetime, call `show` from
 * anywhere to post a message, and place a `ToastLayer(toaster)` in the view to render and age them. Each
 * toast slides in, waits out its duration, then fades away — the `ToastLayer` drives the clock from the
 * frame loop and requests frames while any toast is alive, so the animation runs even on an otherwise
 * idle screen.
 */
public class Toaster {
    private let items = ArrayList<ActiveToast>()
    private var nextId: Int64 = 1

    /** Posts a toast that lives `durationMs` before fading out. */
    public func show(message: String, kind!: ToastKind = ToastKind.Info, durationMs!: UInt64 = 3200): Unit {
        items.add(ActiveToast(nextId, message, kind, durationMs))
        nextId += 1
    }

    /** How many toasts are currently alive. */
    public func count(): Int64 {
        items.size
    }

    // Ages every toast by `deltaMs` and drops any whose time is up. Called by the ToastLayer per frame.
    func tick(deltaMs: UInt64): Unit {
        var i = items.size - 1
        while (i >= 0) {
            let toast = items[i]
            toast.ageMs += deltaMs
            if (toast.remainingMs <= deltaMs) {
                items.remove(at: i)
            } else {
                toast.remainingMs -= deltaMs
            }
            i -= 1
        }
    }

    func snapshot(): Array<ActiveToast> {
        items.toArray()
    }

    func isEmpty(): Bool {
        items.isEmpty()
    }
}

/**
 * Renders a `Toaster`'s toasts stacked at the bottom-right of the viewport and drives their clock. Add
 * it once near the root of the tree (e.g. as the last layer of a root `ZStack`) so it draws above the
 * content; it takes no layout space and never consumes events, so it does not disturb the app beneath.
 */
public class ToastLayer <: Widget {
    private let toaster: Toaster

    public init(toaster: Toaster) {
        this.toaster = toaster
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func participatesInLayout(): Bool {
        false
    }

    public func draw(ctx: UiContext): Unit {
        let toasts = toaster.snapshot()
        if (toasts.isEmpty()) {
            return
        }
        let width = min(TOAST_WIDTH, max(0.0, ctx.viewportWidth - TOAST_MARGIN * 2.0))
        let x = ctx.viewportWidth - TOAST_MARGIN - width
        var bottom = ctx.viewportHeight - TOAST_MARGIN
        var i = toasts.size - 1
        while (i >= 0) {
            let toast = toasts[i]
            let enter = clampF32(Float32(toast.ageMs) / TOAST_SLIDE_MS, 0.0, 1.0)
            let exit: Float32 = if (Float32(toast.remainingMs) < TOAST_FADE_MS) {
                Float32(toast.remainingMs) / TOAST_FADE_MS
            } else {
                1.0
            }
            let alpha = min(enter, exit)
            // Starts one slot lower and slides up into place as it enters.
            let slide = (1.0 - enter) * (TOAST_HEIGHT + TOAST_GAP)
            drawToast(ctx, Rect(x, bottom - TOAST_HEIGHT + slide, width, TOAST_HEIGHT), toast, alpha)
            bottom = bottom - TOAST_HEIGHT - TOAST_GAP
            i -= 1
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(info) =>
                toaster.tick(info.deltaMs)
                // Keep frames coming while toasts animate; without this the idle loop would freeze them.
                if (!toaster.isEmpty()) {
                    ctx.requestFrame()
                }
            case _ => ()
        }
        false
    }

    private func drawToast(ctx: UiContext, rect: Rect, toast: ActiveToast, alpha: Float32): Unit {
        let a = Int64(clampF32(alpha, 0.0, 1.0) * 255.0)
        let accent = toastColor(ctx, toast.kind)
        // Soft shadow, card, then a coloured accent bar and the message — all faded by `alpha`.
        ctx.renderer.fillRoundedRect(rect.shift(0.0, 3.0), ctx.theme.controlRadius,
            ctx.theme.shadow.withAlpha(Int64(clampF32(alpha, 0.0, 1.0) * 40.0)))
        ctx.renderer.fillRoundedRect(rect, ctx.theme.controlRadius, ctx.theme.panelRaised.withAlpha(a))
        ctx.renderer.fillRoundedRect(Rect(rect.x + 6.0, rect.y + 8.0, 4.0, rect.h - 16.0), 2.0, accent.withAlpha(a))
        let textY = rect.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CONTROL) / 2.0
        ctx.renderer.pushClip(Rect(rect.x + 18.0, rect.y, rect.w - 28.0, rect.h))
        ctx.renderer.text(toast.message, rect.x + 18.0, textY, ctx.theme.text.withAlpha(a), pointSize: FontSizes.CONTROL)
        ctx.renderer.popClip()
    }
}

private func toastColor(ctx: UiContext, kind: ToastKind): Color {
    match (kind) {
        case ToastKind.Info => ctx.theme.accent
        case ToastKind.Success => Color.rgb(46, 160, 92)
        case ToastKind.Warning => Color.rgb(210, 150, 40)
        case ToastKind.Error => ctx.theme.danger
    }
}
