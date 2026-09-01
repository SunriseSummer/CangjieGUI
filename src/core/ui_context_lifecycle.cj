package cui.core

extend UiContext {
    /** Asks the desktop loop to exit after the current frame (window close, app quit action). */
    public func requestClose(): Unit {
        shouldClose = true
    }
}
