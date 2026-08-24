package cui.core

import sdl.{EventKeyModifiers, UiEventMetadata}

/** IME pre-edit text owned by the currently focused text control. */
public struct ImeComposition {
    public let text: String
    public let selectionStart: Int32
    public let selectionLength: Int32

    public init(text: String, selectionStart: Int32, selectionLength: Int32) {
        this.text = text
        this.selectionStart = selectionStart
        this.selectionLength = selectionLength
    }
}

/** Candidate-list snapshot supplied by IMEs that expose candidates to the application. */
public struct ImeCandidates {
    public let values: Array<String>
    public let selected: Int32
    public let horizontal: Bool

    public init(values: Array<String>, selected: Int32, horizontal: Bool) {
        this.values = values
        this.selected = selected
        this.horizontal = horizontal
    }
}

extend UiContext {
    /** Metadata captured with the event currently being dispatched. */
    public func eventMetadata(): UiEventMetadata {
        currentEventMetadata
    }

    /** Modifier snapshot captured with the current event; stable even if dispatch was deferred. */
    public func eventModifiers(): EventKeyModifiers {
        currentEventMetadata.modifiers
    }

    protected func beginEvent(metadata: UiEventMetadata): Unit {
        currentEventMetadata = metadata
    }

    protected func endEvent(): Unit {
        currentEventMetadata = UiEventMetadata()
    }

    /** Updates IME pre-edit state when `id` is the focused text control. */
    public func setImeComposition(id: String, text: String, selectionStart: Int32, selectionLength: Int32): Unit {
        if (focusId != id) {
            return
        }
        if (text.isEmpty()) {
            clearImeComposition()
            return
        }
        compositionOwner = id
        compositionValue = Some(ImeComposition(text, selectionStart, selectionLength))
        immediateFrameRequested = true
    }

    /** Updates the optional application-visible IME candidate snapshot. */
    public func setImeCandidates(id: String, values: Array<String>, selected: Int32, horizontal: Bool): Unit {
        if (focusId != id) {
            return
        }
        compositionOwner = id
        candidateValue = Some(ImeCandidates(values, selected, horizontal))
        immediateFrameRequested = true
    }

    /** Returns the active pre-edit state only to its owning text control. */
    public func imeComposition(id: String): ?ImeComposition {
        markRetainedPaintDynamic("IME composition read during paint")
        if (compositionOwner == id) {
            compositionValue
        } else {
            None
        }
    }

    /** Returns the active candidate snapshot only to its owning text control. */
    public func imeCandidates(id: String): ?ImeCandidates {
        if (compositionOwner == id) {
            candidateValue
        } else {
            None
        }
    }

    /** Clears pre-edit and candidate state after commit, blur, or OS focus loss. */
    public func clearImeComposition(): Unit {
        compositionOwner = ""
        compositionValue = None
        candidateValue = None
    }

    /** Cancels pointer gestures and IME pre-edit state when the native window loses focus. */
    protected func cancelTransientInput(): Unit {
        leftMouseDown = false
        hoverId = ""
        dragId = ""
        pressedId = ""
        clearImeComposition()
    }
}
