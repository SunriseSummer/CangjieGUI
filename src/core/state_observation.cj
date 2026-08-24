package cui.core

class StateListener<T> {
    let callback: (T, T) -> Unit
    var isActive = true

    init(callback: (T, T) -> Unit) {
        this.callback = callback
    }
}

/** A cancellable observation returned by `Observable.observe`. */
public class StateObservation<T> <: Resource {
    private var cancelAction: ?(() -> Unit)

    init(cancel: () -> Unit) {
        this.cancelAction = Some(cancel)
    }

    /** Returns whether this observation has been cancelled. */
    public func isClosed(): Bool {
        cancelAction.isNone()
    }

    /** Cancels future callbacks. Calling this method repeatedly is safe. */
    public func close(): Unit {
        match (cancelAction) {
            case Some(cancel) =>
                cancel()
                // Clear after success so a rejected cross-thread close remains retryable.
                cancelAction = None
            case None => ()
        }
    }
}
