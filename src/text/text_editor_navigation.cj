package cui.text

import sdl.system.platformName
import cui.core.{UiContext, State, registerFrameSubscriber}

private let EDITOR_PLATFORM_NAME = platformName()

internal func subscribeEditorAutofocus(done: State<Bool>, editable: Bool, focus: (UiContext) -> Unit): Unit {
    if (editable && !done.value) {
        registerFrameSubscriber({ctx, _ => focus(ctx)})
    }
}

// Ctrl is the word modifier on Windows/Linux; Option is the native macOS alias.
internal func textWordModifier(ctx: UiContext): Bool {
    let modifiers = ctx.eventModifiers()
    modifiers.ctrl || (EDITOR_PLATFORM_NAME == "macOS" && modifiers.alt && !modifiers.gui)
}

internal func focusTextEditorOnce(ctx: UiContext, id: String, requested: Bool, editable: Bool, done: State<Bool>): Unit {
    if (requested && editable && !done.value) {
        ctx.focus(id, viaKeyboard: true)
        done.value = true
    }
}

internal func textEditorFocusableId(id: String, editable: Bool): ?String {
    if (editable) {
        Some(id)
    } else {
        None
    }
}
