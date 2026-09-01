package cui.core

import sdl.Rect

// Frame scheduling and retained-paint coordination are kept together because a frame request made
// during command recording must invalidate every active recording scope.
extend UiContext {
    func trackRetainedPaint<T>(body: () -> T): (T, ?String) {
        retainedPaintDynamicReasons.add(None)
        try {
            let result = body()
            let reason = retainedPaintDynamicReasons[retainedPaintDynamicReasons.size - 1]
            (result, reason)
        } finally {
            retainedPaintDynamicReasons.remove(at: retainedPaintDynamicReasons.size - 1)
        }
    }

    /** Sets the optional retained-scene damage used by an advanced shell for paint culling. */
    protected func setRetainedDamage(damage: ?Rect): Unit {
        retainedDamage = damage
    }

    func retainedPaintIntersects(rect: Rect): Bool {
        match (retainedDamage) {
            case Some(damage) =>
                let overlap = damage.intersection(rect)
                overlap.w > 0.0 && overlap.h > 0.0
            case None => true
        }
    }

    func retainedPartialDamageActive(): Bool {
        retainedDamage.isSome()
    }

    func retainedDamageRegion(): ?Rect {
        retainedDamage
    }

    /**
     * Requests that the next frame be rendered even if no input arrived and no state changed. Call this
     * from a widget that animates on the frame clock (a caret, a spinner, a countdown); without it the
     * desktop loop may skip rendering while the screen is otherwise idle.
     */
    public func requestFrame(): Unit {
        markRetainedPaintDynamic("frame requested during paint")
        immediateFrameRequested = true
    }

    /** Requests one frame no earlier than the absolute SDL clock value `elapsedMs`. */
    public func requestFrameAt(elapsedMs: UInt64): Unit {
        markRetainedPaintDynamic("frame deadline requested during paint")
        frameDeadlineMs = match (frameDeadlineMs) {
            case Some(current) => Some(min(current, elapsedMs))
            case None => Some(elapsedMs)
        }
    }

    /** Reads and clears all frame requests made since the preceding take. */
    protected func takeFrameSchedule(): FrameSchedule {
        let schedule = FrameSchedule(immediate: immediateFrameRequested, deadlineMs: frameDeadlineMs)
        immediateFrameRequested = false
        frameDeadlineMs = None
        schedule
    }

    /** Clears frame requests when a test/custom host resets without consuming a result. */
    protected func clearFrameSchedule(): Unit {
        immediateFrameRequested = false
        frameDeadlineMs = None
    }

    /** Compatibility helper for custom shells that only distinguish pending versus idle. */
    protected func takeFrameRequest(): Bool {
        takeFrameSchedule().hasPending()
    }
}
