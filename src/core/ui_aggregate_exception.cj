package cui.core

import std.collection.ArrayList

/** Multiple failures from one UI transaction, in occurrence order, retaining each original exception. */
public class UiAggregateException <: Exception {
    private let items: Array<Exception>

    /** Requires at least two failures; callers with one failure should rethrow that original exception. */
    public init(failures: Array<Exception>) {
        super(aggregateFailureMessage(failures))
        this.items = failures.clone()
    }

    /** The original initiating failure, retaining its concrete type and stack trace. */
    public prop primary: Exception {
        get() {
            items[0]
        }
    }

    /** A defensive copy of the original failures, ordered primary first and then cleanup/notification failures. */
    public prop failures: Array<Exception> {
        get() {
            items.clone()
        }
    }
}

private func aggregateFailureMessage(failures: Array<Exception>): String {
    if (failures.size < 2) {
        throw IllegalArgumentException("UiAggregateException requires at least two failures")
    }
    let message = StringBuilder()
    message.append("Multiple UI failures (${failures.size})")
    for (error in failures) {
        message.append("\n${error.toString()}")
    }
    message.toString()
}

/** Internal transaction collector shared by core operations and desktop shutdown. */
protected class UiFailureCollector {
    private let items = ArrayList<Exception>()

    public init() {}

    /** Captures a fallible stage so later cleanup stages can still run. */
    public func run(body: () -> Unit): Unit {
        try {
            body()
        } catch (error: Exception) {
            add(Some(error))
        }
    }

    /** Flattens nested transaction failures without mutating the original exceptions. */
    public func add(candidate: ?Exception): Unit {
        match (candidate) {
            case Some(error) => match (error as UiAggregateException) {
                case Some(group) => for (failure in group.failures) {
                    add(Some(failure))
                }
                case None => items.add(error)
            }
            case None => ()
        }
    }

    /** Returns the exact original exception for a single failure and an aggregate only for multiple failures. */
    public func failure(): ?Exception {
        if (items.isEmpty()) {
            return None
        }
        if (items.size == 1) {
            return Some(items[0])
        }
        Some(UiAggregateException(items.toArray()))
    }

    /** Rethrows after every required stage has been attempted. */
    public func raiseIfAny(): Unit {
        match (failure()) {
            case Some(error) => throw error
            case None => ()
        }
    }
}

// Notification hot paths only allocate a collector after an actual listener failure.
func appendUiFailure(current: ?UiFailureCollector, error: Exception): ?UiFailureCollector {
    let failures = current ?? UiFailureCollector()
    failures.add(Some(error))
    Some(failures)
}

func mergeUiFailure(current: ?UiFailureCollector, candidate: ?Exception): ?UiFailureCollector {
    match (candidate) {
        case Some(error) => appendUiFailure(current, error)
        case None => current
    }
}

func collectedUiFailure(current: ?UiFailureCollector): ?Exception {
    match (current) {
        case Some(failures) => failures.failure()
        case None => None
    }
}

func rollbackUiFailure(primary: Exception, rollback: () -> ?Exception): Exception {
    let failures = UiFailureCollector()
    failures.add(Some(primary))
    failures.run({=> failures.add(rollback())})
    failures.failure() ?? primary
}
