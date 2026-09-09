package cui.core

import sdl.Rect

// Frame scheduling and retained-paint coordination are kept together because a frame request made
// during command recording must invalidate every active recording scope.
extend UiContext {
    /** Brackets shell-driven paint resource observations, including the root outside retained boundaries. */
    protected func trackResourceReads<T>(body: () -> T): T {
        resourceReadDepth += 1
        try {
            body()
        } finally {
            resourceReadDepth -= 1
        }
    }

    /** Tracks external resource invalidation only during host painting or retained command recording. */
    protected func observeResource<T>(resource: Observable<T>): Unit {
        if (resourceReadDepth > 0) {
            let _ = resource.get() // cjcheck-ignore: ignore-result # the read registers a retained paint dependency
        }
    }

    /** Whether the current host paint or retained recording collects resource dependencies. */
    protected func tracksResourceReads(): Bool {
        resourceReadDepth > 0
    }

    func trackRetainedPaint<T>(body: () -> T): (T, ?String) {
        retainedPaintDynamicReasons.add(None)
        resourceReadDepth += 1
        try {
            let result = body()
            let reason = retainedPaintDynamicReasons[retainedPaintDynamicReasons.size - 1]
            (result, reason)
        } finally {
            resourceReadDepth -= 1
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

    /** Specialized editor damage; does not authorize skipping other input/state/timer work. */
    protected func requestCaretFrameAt(elapsedMs: UInt64, rect: Rect): Unit {
        if (rect.w <= 0.0 || rect.h <= 0.0 || rect.x.isNaN() || rect.y.isNaN() || rect.w.isNaN() || rect.h.isNaN() ||
            rect.x.isInf() || rect.y.isInf() || rect.w.isInf() || rect.h.isInf()) {
            return
        }
        markRetainedPaintDynamic("caret deadline requested during paint")
        caretDeadlineMs = match (caretDeadlineMs) {
            case Some(time) => Some(min(time, elapsedMs));
            case None => Some(elapsedMs)
        }
        caretDamage = match (caretDamage) {
            case Some(previous) => Some(unionRect(previous, rect));
            case None => Some(rect)
        }
    }

    protected func setCaretOnlyPaint(value!: Bool): Unit {
        caretOnlyPaint = value
    }
    protected func isCaretOnlyPaint(): Bool {
        caretOnlyPaint
    }
    protected func caretPaintIntersects(rect: Rect): Bool {
        !caretOnlyPaint || retainedPaintIntersects(rect)
    }
    protected func textWindowActive(): Bool {
        textWindowActiveValue
    }
    protected func setTextWindowActive(value!: Bool): Unit {
        textWindowActiveValue = value
    }
    protected func hasSceneFrameRequest(): Bool {
        immediateFrameRequested || frameDeadlineMs.isSome()
    }

    /** Reads and clears all frame requests made since the preceding take. */
    protected func takeFrameSchedule(): FrameSchedule {
        let schedule = FrameSchedule(immediateFrameRequested, frameDeadlineMs, caretDeadlineMs, caretDamage)
        immediateFrameRequested = false
        frameDeadlineMs = None
        caretDeadlineMs = None
        caretDamage = None
        schedule
    }

    /** Clears frame requests when a test/custom host resets without consuming a result. */
    protected func clearFrameSchedule(): Unit {
        immediateFrameRequested = false
        frameDeadlineMs = None
        caretDeadlineMs = None
        caretDamage = None
        caretOnlyPaint = false
    }

    /** Compatibility helper for custom shells that only distinguish pending versus idle. */
    protected func takeFrameRequest(): Bool {
        takeFrameSchedule().hasPending()
    }
}
