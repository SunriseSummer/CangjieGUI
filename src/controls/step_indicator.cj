package cui.controls

import sdl.{Color, FontSizes, MouseButton, Pen, Rect, Size, UiEvent}
import cui.core.{CursorShape, UiContext, Widget, resolveControlKey, emit}

private let STEP_CIRCLE_R: Float32 = 14.0
private let STEP_EDGE_PAD: Float32 = 44.0
private let STEP_LABEL_GAP: Float32 = 8.0
private let STEP_LABEL_H: Float32 = 18.0
private let STEP_TOP_PAD: Float32 = 4.0

/**
 * A horizontal step progress indicator for multi-step flows (checkout, onboarding, wizards). It shows a
 * row of numbered nodes joined by a connector, with everything before `current` marked done (filled and
 * checked), `current` highlighted, and later steps dimmed. Each step's label sits beneath its node.
 *
 * It is display-first: the flow's own Back/Next controls drive `current`. An `onSelect` callback makes
 * the already-reached steps (index ≤ current) clickable, so the user can jump back to a completed step.
 */
public class StepIndicator <: Widget {
    private let id: String
    private let steps: Array<String>
    private let current: Int64
    private let onSelect: ?(Int64) -> Unit
    private var frame = Rect.zero()

    public init(steps: Array<String>, current: Int64, onSelect!: ?(Int64) -> Unit = None, key!: ?String = None) {
        this.id = resolveControlKey(key, "StepIndicator")
        this.steps = steps
        this.current = current
        this.onSelect = onSelect
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, STEP_CIRCLE_R * 2.0 + STEP_TOP_PAD + STEP_LABEL_GAP + STEP_LABEL_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        let n = steps.size
        if (n == 0) {
            return
        }
        let cy = frame.y + STEP_TOP_PAD + STEP_CIRCLE_R
        let xs = stepCenters()
        // Connectors first, behind the nodes: done segments accent, the rest neutral.
        var i = 0
        while (i < n - 1) {
            let color = if (i < current) {
                ctx.theme.accent
            } else {
                ctx.theme.panelEdge
            }
            ctx.renderer.strokeLine(xs[i] + STEP_CIRCLE_R, cy, xs[i + 1] - STEP_CIRCLE_R, cy,
                Pen(width: 2.5, color: color))
            i += 1
        }
        for (step in 0..n) {
            drawNode(ctx, xs[step], cy, step)
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match ((event, onSelect)) {
            // Only the already-reached steps are clickable, so only they show the interactive cursor.
            case (UiEvent.MouseMove(x, y), Some(_)) => if (reachedStepAt(x, y) >= 0) {
                ctx.claimHover(id, CursorShape.Interactive)
            }
            case (UiEvent.MouseDown(MouseButton.Left, x, y), Some(callback)) =>
                let step = reachedStepAt(x, y)
                if (step >= 0) {
                    callback(step)
                    return true
                }
            case _ => ()
        }
        false
    }

    // The reached (index ≤ current) step whose hit circle contains the pointer, or -1.
    private func reachedStepAt(x: Float32, y: Float32): Int64 {
        let cy = frame.y + STEP_TOP_PAD + STEP_CIRCLE_R
        let xs = stepCenters()
        let hit = STEP_CIRCLE_R + 4.0
        for (step in 0..steps.size) {
            let dx = x - xs[step]
            let dy = y - cy
            if (step <= current && dx * dx + dy * dy <= hit * hit) {
                return step
            }
        }
        -1
    }

    // The x centre of each node, spread evenly with padding so edge labels have room.
    private func stepCenters(): Array<Float32> {
        let n = steps.size
        if (n <= 1) {
            return [frame.centerX()]
        }
        let left = frame.x + STEP_EDGE_PAD
        let right = frame.right() - STEP_EDGE_PAD
        let gap = (right - left) / Float32(n - 1)
        Array<Float32>(n, {i => left + Float32(i) * gap})
    }

    private func drawNode(ctx: UiContext, cx: Float32, cy: Float32, step: Int64): Unit {
        let done = step < current
        let isCurrent = step == current
        if (done || isCurrent) {
            ctx.renderer.fillCircle(cx, cy, STEP_CIRCLE_R, ctx.theme.accent)
            if (done) {
                drawCheck(ctx, cx, cy, ctx.theme.accentText)
            } else {
                drawNumber(ctx, cx, cy, step + 1, ctx.theme.accentText)
            }
        } else {
            ctx.renderer.fillCircle(cx, cy, STEP_CIRCLE_R, ctx.theme.field)
            ctx.renderer.strokeCircle(cx, cy, STEP_CIRCLE_R - 1.0, Pen(width: 1.6, color: ctx.theme.panelEdge))
            drawNumber(ctx, cx, cy, step + 1, ctx.theme.mutedText)
        }
        let labelColor = if (isCurrent) {
            ctx.theme.accent
        } else if (done) {
            ctx.theme.text
        } else {
            ctx.theme.mutedText
        }
        let label = steps[step]
        let labelW = ctx.renderer.textWidth(label, pointSize: FontSizes.CAPTION)
        let ly = cy + STEP_CIRCLE_R + STEP_LABEL_GAP
        ctx.renderer.text(label, cx - labelW / 2.0, ly, labelColor, pointSize: FontSizes.CAPTION)
    }

    private func drawNumber(ctx: UiContext, cx: Float32, cy: Float32, number: Int64, color: Color): Unit {
        let text = "${number}"
        let w = ctx.renderer.textWidth(text, pointSize: FontSizes.CAPTION)
        let h = ctx.renderer.textHeight(pointSize: FontSizes.CAPTION)
        ctx.renderer.text(text, cx - w / 2.0, cy - h / 2.0, color, pointSize: FontSizes.CAPTION)
    }

    private func drawCheck(ctx: UiContext, cx: Float32, cy: Float32, color: Color): Unit {
        let pen = Pen(width: 2.0, color: color)
        ctx.renderer.strokeLine(cx - 5.0, cy, cx - 1.5, cy + 4.0, pen)
        ctx.renderer.strokeLine(cx - 1.5, cy + 4.0, cx + 5.5, cy - 4.0, pen)
    }
}
