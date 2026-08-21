package cui.core

// Clamp the timestep so a frame hitch (a long pause between frames) cannot inject a huge
// impulse and make the integration diverge; motion just proceeds at up to this step.
private let SPRING_MAX_STEP_MS: Float32 = 40.0
private let SPRING_SETTLE_POS: Float32 = 0.0005
private let SPRING_SETTLE_VEL: Float32 = 0.001

/*
 * A spring-damper that eases a value toward a target across frames. CUI redraws every frame,
 * so a widget ticks one in `draw` with the frame delta and reads `value` — smooth state
 * transitions with no separate animation timer. Integration is semi-implicit Euler with a
 * clamped timestep for stability, and it settles exactly onto the target so an idle spring
 * costs nothing.
 *
 * Defaults are tuned for UI toggles: snappy, with a barely-perceptible settle. Because a
 * spring initialised at its target is immediately settled, a control that starts a spring at
 * its current state animates only on later changes — static renders (snapshots) are unchanged.
 */
public class Spring {
    private var current: Float32
    private var velocity: Float32 = 0.0
    private var goal: Float32
    private let stiffness: Float32
    private let damping: Float32

    public init(value: Float32, stiffness!: Float32 = 210.0, damping!: Float32 = 24.0) {
        this.current = value
        this.goal = value
        this.stiffness = stiffness
        this.damping = damping
    }

    /** The current animated value. */
    public prop value: Float32 {
        get() {
            current
        }
    }

    /** Sets the value the spring eases toward. */
    public func target(value: Float32): Unit {
        goal = value
    }

    /** Snaps immediately to `value` with no animation (initial placement, or a hard reset). */
    public func reset(value: Float32): Unit {
        current = value
        goal = value
        velocity = 0.0
    }

    /** Whether the spring has reached its target and stopped. */
    public func settled(): Bool {
        // Exact comparison is the settle sentinel: tick() assigns current = goal and
        // velocity = 0.0 bit-for-bit when the spring lands; an epsilon would settle early.
        current == goal && velocity == 0.0 // cjcheck-ignore: float-equal # sentinel identity written verbatim by tick()
    }

    /*
     * The widget draw-time step: retarget, advance by this frame's delta, and — while still in
     * motion — request the next frame so the dirty-frame loop (档 0) keeps rendering instead of idling
     * mid-transition and freezing the animation. This is the form controls use; a settled spring asks
     * for nothing, so an idle control still costs no frames. Returns the new value.
     */
    public func animate(ctx: UiContext, target!: Float32): Float32 {
        goal = target
        tick(ctx.frame.deltaMs)
        if (!settled()) {
            ctx.requestFrame()
        }
        current
    }

    /*
     * The raw step: retarget, advance by an explicit delta, and read the new value, with no frame
     * request. For tests and non-draw callers that drive time themselves; widgets rendering under the
     * dirty-frame loop want `animate(ctx, target:)` so the transition is not frozen.
     */
    public func animate(target!: Float32, deltaMs!: UInt64): Float32 {
        goal = target
        tick(deltaMs)
        current
    }

    /** Advances the spring by `deltaMs` milliseconds toward the target. */
    public func tick(deltaMs: UInt64): Unit {
        if (settled()) {
            return
        }
        let dt = min(Float32(Int64(deltaMs)), SPRING_MAX_STEP_MS) / 1000.0
        if (dt <= 0.0) {
            return
        }
        let force = -stiffness * (current - goal) - damping * velocity
        velocity += force * dt
        current += velocity * dt
        if (absF32(current - goal) < SPRING_SETTLE_POS && absF32(velocity) < SPRING_SETTLE_VEL) {
            current = goal
            velocity = 0.0
        }
    }
}


/*
 * A duration-based tween: eases a value from where it is toward a target over a fixed time using an
 * `Easing` curve. Where `Spring` is physics-based (mass reacts to the target, timing emergent), an
 * `Animator` finishes in an exact duration with a chosen curve — the model behind CSS transitions and
 * SwiftUI/Compose `.animation(.easeInOut(duration:))`.
 *
 * Usage matches `Spring`: a widget ticks one in `draw` with `animate(ctx, target:)`, reads `value`,
 * and the animator asks for the next frame while in motion so the dirty-frame loop keeps rendering.
 * Retargeting mid-flight restarts the ease from the current value. An animator created at its target
 * is immediately settled, so it costs nothing idle and leaves static renders (snapshots) unchanged.
 */
public class Animator {
    private var current: Float32
    private var from: Float32
    private var to: Float32
    private var elapsedMs: Float32 = 0.0
    private let durationMs: Float32
    private let delayMs: Float32
    // The whole timeline one retarget runs: the held delay plus the ease itself. Precomputed because
    // every tick and every settled() check reads it.
    private let totalMs: Float32
    private let easing: Easing

    /*
     * `delay` holds the value still for that many milliseconds after each retarget before the ease
     * begins — the CSS `transition-delay` / SwiftUI `.delay()` model. Giving each item in a list a delay
     * proportional to its index staggers them into a cascade. The delay restarts on every retarget, so a
     * staggered group replays its cascade each time it is toggled.
     */
    public init(
        value: Float32,
        duration!: UInt64 = 250,
        easing!: Easing = Easing.EaseInOutQuad,
        delay!: UInt64 = 0
    ) {
        this.current = value
        this.from = value
        this.to = value
        this.durationMs = max(1.0, Float32(Int64(duration)))
        this.delayMs = max(0.0, Float32(Int64(delay)))
        this.totalMs = this.delayMs + this.durationMs
        this.easing = easing
    }

    /** The current animated value. */
    public prop value: Float32 {
        get() {
            current
        }
    }

    /** The value being eased toward. */
    public prop goal: Float32 {
        get() {
            to
        }
    }

    /** Retargets, restarting the ease from the current value. A no-op when already heading there. */
    public func target(value: Float32): Unit {
        if (value != to) { // cjcheck-ignore: float-equal # retarget no-op check compares the caller's own previous value verbatim
            from = current
            to = value
            elapsedMs = 0.0
        }
    }

    /** Snaps immediately to `value` with no animation (initial placement, or a hard reset). */
    public func reset(value: Float32): Unit {
        current = value
        from = value
        to = value
        elapsedMs = 0.0
    }

    /** Whether the animation has reached its target and stopped (a pending delay still counts as busy). */
    public func settled(): Bool {
        // Exact comparison is the settle sentinel: reset()/tick() assign from = to verbatim.
        from == to || elapsedMs >= totalMs // cjcheck-ignore: float-equal # sentinel identity written verbatim by reset()/tick()
    }

    /*
     * The widget draw-time step: retarget, advance by this frame's delta, and — while still in motion —
     * request the next frame so the dirty-frame loop keeps rendering instead of freezing mid-transition.
     * A settled animator asks for nothing, so an idle control still costs no frames. Returns the new value.
     */
    public func animate(ctx: UiContext, target!: Float32): Float32 {
        this.target(target)
        tick(ctx.frame.deltaMs)
        if (!settled()) {
            ctx.requestFrame()
        }
        current
    }

    /*
     * The raw step: retarget, advance by an explicit delta, and read the new value, with no frame
     * request. For tests and non-draw callers that drive time themselves.
     */
    public func animate(target!: Float32, deltaMs!: UInt64): Float32 {
        this.target(target)
        tick(deltaMs)
        current
    }

    /** Advances the animation by `deltaMs` milliseconds toward the target. */
    public func tick(deltaMs: UInt64): Unit {
        if (settled()) {
            return
        }
        // Duration-based motion tracks the wall clock, so a long stall (window drag, GC pause) lands
        // past the end of the timeline and is pinned to it below — the tween finishes rather than
        // stretching, exactly as a CSS transition would after the same stall.
        elapsedMs += Float32(Int64(deltaMs))
        if (elapsedMs >= totalMs) {
            elapsedMs = totalMs
            current = to
            return
        }
        // While inside the delay the progress argument is negative; `ease` clamps it to zero, so the
        // value simply holds at `from` until the delay is served. With no delay this is elapsed/duration.
        current = from + (to - from) * easing.ease((elapsedMs - delayMs) / durationMs)
    }
}

/*
 * A repeating timeline for perpetual motion — skeleton-screen shimmer, breathing status dots, loading
 * pulses. Where `Spring` and `Animator` run TO a target and settle, a `Pulse` has no target and never
 * settles: its value sweeps 0 to 1 over `period` milliseconds and either reflects back (autoreverse,
 * the breathing default) or jumps back to 0 (a sawtooth sweep, e.g. an indeterminate progress sweep).
 *
 * Usage matches the other primitives: a widget calls `animate(ctx)` in draw and reads the value.
 * Because a pulse is perpetual, `animate` requests the next frame unconditionally — a visible pulse
 * keeps the dirty-frame loop rendering, which is inherent to any endless animation; screens without
 * one still idle at zero frames. Hold a Pulse in a model or `localState` so it survives the per-frame
 * rebuild, exactly like a Spring.
 */
public class Pulse {
    private var elapsedMs: Float32 = 0.0
    // The frame stamp animate() last ticked on: several widgets may share one Pulse (a whole skeleton
    // screen breathing in sync) and each call animate in their draw — only the first call in a frame
    // advances the clock, so sharing does not multiply the speed.
    private var tickedAtMs: UInt64 = UInt64.Max
    private let periodMs: Float32
    private let reflect: Bool
    private let easing: Easing

    public init(period!: UInt64 = 1200, autoreverse!: Bool = true, easing!: Easing = Easing.EaseInOutSine) {
        this.periodMs = max(1.0, Float32(Int64(period)))
        this.reflect = autoreverse
        this.easing = easing
    }

    /** The eased position in `[0, 1]` at the current point of the cycle. */
    public prop value: Float32 {
        get() {
            let position = if (reflect) {
                if (elapsedMs < periodMs) {
                    elapsedMs / periodMs
                } else {
                    2.0 - elapsedMs / periodMs
                }
            } else {
                elapsedMs / periodMs
            }
            easing.ease(position)
        }
    }

    /** Advances the cycle by `deltaMs` milliseconds, wrapping so long runs never lose precision. */
    public func tick(deltaMs: UInt64): Unit {
        // One cycle is a full sweep (loop) or an out-and-back (autoreverse); wrap by whole cycles so
        // elapsed stays small — an unbounded Float32 clock would coarsen after hours of animation.
        let cycle = if (reflect) {
            periodMs * 2.0
        } else {
            periodMs
        }
        elapsedMs += Float32(Int64(deltaMs))
        if (elapsedMs >= cycle) {
            elapsedMs -= Float32(Int64(elapsedMs / cycle)) * cycle
        }
    }

    /*
     * The widget draw-time step: advance by this frame's delta, request the next frame (a pulse never
     * settles), and read the new value. Deduplicated per frame — when several widgets share one Pulse,
     * only the first animate of a frame ticks the clock and the rest just read it.
     */
    public func animate(ctx: UiContext): Float32 {
        if (tickedAtMs != ctx.frame.elapsedMs) {
            tickedAtMs = ctx.frame.elapsedMs
            tick(ctx.frame.deltaMs)
        }
        ctx.requestFrame()
        value
    }
}
