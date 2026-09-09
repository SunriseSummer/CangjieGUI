package cui.core

import sdl.Rect

/** A consumed snapshot of immediate/deadline frame requests made by widgets. */
public class FrameSchedule {
    public let immediate: Bool
    public let deadlineMs: ?UInt64
    private let sceneDeadlineMs: ?UInt64
    private let caretDeadlineMs: ?UInt64
    private let caretDamage: ?Rect

    public init(immediate!: Bool, deadlineMs!: ?UInt64) {
        this(immediate, deadlineMs, None, None)
    }

    protected init(immediate: Bool, sceneDeadline: ?UInt64, caretDeadline: ?UInt64, damage: ?Rect) {
        this.immediate = immediate
        this.sceneDeadlineMs = sceneDeadline
        this.caretDeadlineMs = caretDeadline
        this.caretDamage = damage
        this.deadlineMs = match ((sceneDeadline, caretDeadline)) {
            case (Some(a), Some(b)) => Some(min(a, b))
            case (Some(a), None) => Some(a)
            case (None, value) => value
        }
    }

    /** Shell-only fast path; other timers and immediate work always require normal processing. */
    protected func isCaretOnlyDue(elapsedMs: UInt64): Bool {
        !immediate && sceneDeadlineMs.isNone() && caretDamage.isSome() && match (caretDeadlineMs) {
            case Some(time) => elapsedMs >= time;
            case None => false
        }
    }

    protected func caretRegion(): ?Rect {
        caretDamage
    }

    /** Whether a frame is due at `elapsedMs`. */
    public func isDue(elapsedMs: UInt64): Bool {
        if (immediate) {
            return true
        }
        match (deadlineMs) {
            case Some(deadline) => elapsedMs >= deadline
            case None => false
        }
    }

    /** Whether either an immediate request or a future deadline is pending. */
    public func hasPending(): Bool {
        immediate || deadlineMs.isSome()
    }
}
