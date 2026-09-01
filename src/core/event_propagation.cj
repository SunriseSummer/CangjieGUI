package cui.core

/** The structural phase at which an EventListener observes its targeted subtree. */
public enum EventPhase {
    | Capture
    | Target
    | Bubble
}

/** Whether an EventListener is limited to its subtree target or observes every routed event. */
public enum EventScope {
    | Subtree
    | Global
}

/**
 * A composable event result. `combined` is Boolean union over the handled and stopped effects, so
 * Continue is the identity and combination is associative, commutative, and idempotent.
 */
public enum EventOutcome {
    | Continue
    | Handled
    | StopPropagation
    | Consume

    /** Combines independent listener effects without making their evaluation order observable. */
    public func combined(other: EventOutcome): EventOutcome {
        eventOutcome(eventOutcomeHandled(this) || eventOutcomeHandled(other),
            eventOutcomeStopped(this) || eventOutcomeStopped(other))
    }
}

func eventOutcomeHandled(value: EventOutcome): Bool {
    match (value) {
        case EventOutcome.Handled | EventOutcome.Consume => true
        case EventOutcome.Continue | EventOutcome.StopPropagation => false
    }
}

func eventOutcomeStopped(value: EventOutcome): Bool {
    match (value) {
        case EventOutcome.StopPropagation | EventOutcome.Consume => true
        case EventOutcome.Continue | EventOutcome.Handled => false
    }
}

private func eventOutcome(handled: Bool, stopped: Bool): EventOutcome {
    if (handled) {
        if (stopped) {
            EventOutcome.Consume
        } else {
            EventOutcome.Handled
        }
    } else if (stopped) {
        EventOutcome.StopPropagation
    } else {
        EventOutcome.Continue
    }
}

extend UiContext {
    func beginNativeEventPropagation(): Unit {
        eventPropagationActive = true
        eventPropagationHandled = false
        eventPropagationStopped = false
    }

    func endNativeEventPropagation(): Unit {
        eventPropagationActive = false
        eventPropagationHandled = false
        eventPropagationStopped = false
    }

    /* Returns true when a direct EventListener call owns the temporary propagation session. */
    func enterEventPropagation(): Bool {
        if (eventPropagationActive) {
            return false
        }
        beginNativeEventPropagation()
        true
    }

    func leaveEventPropagation(owned: Bool): Unit {
        if (owned) {
            endNativeEventPropagation()
        }
    }

    func applyEventOutcome(value: EventOutcome): Unit {
        eventPropagationHandled = eventPropagationHandled || eventOutcomeHandled(value)
        eventPropagationStopped = eventPropagationStopped || eventOutcomeStopped(value)
    }

    func noteEventHandled(value: Bool): Unit {
        eventPropagationHandled = eventPropagationHandled || value
    }

    func eventWasHandled(): Bool {
        eventPropagationHandled
    }

    func eventIsPropagationStopped(): Bool {
        eventPropagationStopped
    }
}
