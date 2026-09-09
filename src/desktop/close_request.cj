package cui.desktop

/** One pending UI-thread close decision. Keep it while an asynchronous confirmation is displayed. */
public class CloseRequest {
    private var completion: ?(Bool) -> Unit

    internal init(completion: (Bool) -> Unit) {
        this.completion = Some(completion)
    }

    /** Whether this decision is still pending; shutdown invalidates outstanding requests. */
    public func isPending(): Bool {
        completion.isSome()
    }
    /** Approves closing. Repeated calls after a completed decision do nothing. */
    public func accept(): Unit {
        finish(accepted: true)
    }
    /** Keeps the application open and allows a later independent close request. */
    public func cancel(): Unit {
        finish(accepted: false)
    }

    internal func invalidate(): Unit {
        completion = None
    }
    private func finish(accepted!: Bool): Unit {
        if (let Some(action) <- completion) {
            action(accepted)
            completion = None
        }
    }
}

class CloseCoordinator {
    private var handler: ?(CloseRequest) -> Unit = None
    private var pending: ?CloseRequest = None

    func setHandler(value: ?(CloseRequest) -> Unit): Unit {
        handler = value
    }

    func request(checkOwner: () -> Unit, accepted: () -> Unit): Unit {
        checkOwner()
        if (pending.isSome()) {
            return
        }
        match (handler) {
            case None => accepted()
            case Some(onRequest) =>
                let request = CloseRequest(
                    {
                        allow =>
                            checkOwner()
                            pending = None
                            if (allow) {
                                accepted()
                            }
                    }
                )
                pending = Some(request)
                try {
                    onRequest(request)
                } catch (error: Exception) {
                    request.invalidate()
                    pending = None
                    throw error
                }
        }
    }

    func stop(): Unit {
        if (let Some(request) <- pending) {
            request.invalidate()
        }
        pending = None
        handler = None
    }
}
