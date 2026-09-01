package cui.core

extend UiContext {
    /** Clears any pending tooltip; the shell calls this before drawing each frame. */
    public func clearTooltip(): Unit {
        tooltipText = ""
    }
}
