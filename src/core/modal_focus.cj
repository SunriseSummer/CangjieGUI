package cui.core

import std.collection.ArrayList

class ModalFocusSession {
    let owner: String
    let previous: FocusTarget
    let previousRing: Bool
    var keys: Array<String> = []
    var semantics: ?SemanticFragment = None

    init(owner: String, previous: FocusTarget, previousRing: Bool) {
        this.owner = owner
        this.previous = previous
        this.previousRing = previousRing
    }
}

class ModalFocusRegistry {
    private let sessions = ArrayList<ModalFocusSession>()
    func clear(): Unit {
        sessions.clear()
    }
    /** Enters a newly registered modal once; nested modals capture their parent's focused target. */
    func enter(ctx: UiContext, owner: String, keys: Array<String>, initial: ?String): Unit {
        for (session in sessions) {
            if (session.owner == owner) {
                session.keys = keys
                return
            }
        }
        let previous = ctx.focusedTarget.getOrDefault({=> FocusTarget.detached(ctx.focusId)})
        let session = ModalFocusSession(owner, previous, ctx.focusRingVisible)
        session.keys = keys
        sessions.add(session)
        if (let Some(key) <- initial) {
            for (candidate in keys) {
                if (candidate == key) {
                    ctx.focus(key, viaKeyboard: true);
                    return
                }
            }
        }
        if (keys.isEmpty()) {
            ctx.clearFocus()
        } else {
            ctx.focus(keys[0], viaKeyboard: true)
        }
    }

    /** Restores removed modal scopes against the latest generational focus graph, topmost first. */
    func settle(ctx: UiContext, isActive: (String) -> Bool): Unit {
        var index = sessions.size - 1
        while (index >= 0) {
            let session = sessions[index]
            if (!isActive(session.owner)) {
                let topmost = index == sessions.size - 1
                sessions.remove(at: index)
                if (topmost) {
                    restore(ctx, session)
                }
            }
            index -= 1
        }
    }

    func setContent(owner: String, fragment: ?SemanticFragment): Unit {
        for (session in sessions) {
            if (session.owner == owner) {
                session.semantics = fragment
                return
            }
        }
    }

    func allowsAction(id: String): Bool {
        if (sessions.isEmpty()) {
            return true
        }
        match (sessions[sessions.size - 1].semantics) {
            case Some(fragment) => fragment.containsId(id)
            case None => false
        }
    }

    private func restore(ctx: UiContext, session: ModalFocusSession): Unit {
        if (let Some(target) <- ctx.focusTargetByKey.get(session.previous.key)) {
            if (sameFocusTarget(target, session.previous)) {
                ctx.focus(target.key, viaKeyboard: session.previousRing)
                return
            }
        }
        ctx.clearFocus()
        if (!sessions.isEmpty()) {
            for (key in sessions[sessions.size - 1].keys) {
                if (ctx.focusTargetByKey.contains(key)) {
                    ctx.focus(key, viaKeyboard: true);
                    return
                }
            }
            return
        }
        if (!ctx.focusOrder.isEmpty()) {
            ctx.focus(ctx.focusOrder[0].key, viaKeyboard: true)
        }
    }
}
