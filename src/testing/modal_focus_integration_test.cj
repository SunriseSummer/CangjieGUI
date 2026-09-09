package cui.testing

import sdl.{Key, MouseButton, Rect, UiEvent}
import cui.core.{Button, SemanticsAction, State, VStack}
import cui.controls.Modal

private let MODAL_VIEWPORT = Rect(0.0, 0.0, 500.0, 400.0)

@Test
func modalInitialFocusRestoresOpenerAndFallsBackAfterRemoval(): Unit {
    let host = WidgetTestHost()
    let open = State<Bool>(false)
    let showOpener = State<Bool>(true)
    let view: () -> Unit = {=>
        VStack {
            Button("Fallback", {=> ()}).key("fallback")
            if (showOpener.value) { Button("Open", {=> ()}).key("opener") }
            Modal(open, initialFocus: "cancel") {
                Button("Accept", {=> ()}).key("accept")
                Button("Cancel", {=> ()}).key("cancel")
            }
        }
        ()
    }
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    host.context.focus("opener", viaKeyboard: true)
    open.value = true
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.hasFocus("cancel"))
    open.value = false
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.hasFocus("opener"))
    open.value = true
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    showOpener.value = false
    open.value = false
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.hasFocus("fallback"))
    host.reset()
}

@Test
func nestedModalFocusReturnsToParentThenBackground(): Unit {
    let host = WidgetTestHost()
    let outer = State<Bool>(false)
    let inner = State<Bool>(false)
    let view: () -> Unit = {=>
        VStack {
            Button("Open", {=> ()}).key("open")
            Modal(outer) {
                Button("Outer", {=> ()}).key("outer")
                Modal(inner) { Button("Inner", {=> ()}).key("inner") }
            }
        }
        ()
    }
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    host.context.focus("open")
    outer.value = true
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.hasFocus("outer"))
    inner.value = true
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.hasFocus("inner"))
    inner.value = false
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.hasFocus("outer"))
    outer.value = false
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.hasFocus("open"))
    host.reset()
}

@Test
func modalDismissPolicyConsumesEscapeAndBackdropWithoutClosing(): Unit {
    let host = WidgetTestHost()
    let open = State<Bool>(true)
    let view: () -> Unit = {=>
        Modal(open, dismissOnEscape: false, dismissOnBackdrop: false) { Button("Stay", {=> ()}).key("stay") }
        ()
    }
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(host.context.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 0.0, 0.0)))
    @Expect(open.value)
    @Expect(host.context.hasFocus("stay"))
    host.reset()
}

@Test
func modalBlocksBackgroundAccessibilityActionsAndKeepsDisabledActionsDisabled(): Unit {
    let host = WidgetTestHost()
    let open = State<Bool>(true)
    let calls = State<Int64>(0)
    let view: () -> Unit = {=>
        VStack {
            Button("Background", {=> calls.value += 100}).key("background")
            Modal(open) {
                Button("Active", {=> calls.value += 1}).key("active")
                Button("Disabled", {=> calls.value += 1000}).key("disabled").enabled(false)
            }
        }
        ()
    }
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(!host.context.performSemanticsAction("background", SemanticsAction.Activate))
    @Expect(host.context.performSemanticsAction("active", SemanticsAction.Activate))
    @Expect(!host.context.performSemanticsAction("disabled", SemanticsAction.Activate))
    @Expect(calls.value, 1)
    open.value = false
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.performSemanticsAction("background", SemanticsAction.Activate))
    @Expect(calls.value, 101)
    host.reset()
}

@Test
func nestedModalLosingItsOpenerKeepsFocusInsideParent(): Unit {
    let host = WidgetTestHost()
    let inner = State<Bool>(false)
    let showOpener = State<Bool>(true)
    let view: () -> Unit = {=>
        VStack {
            Button("Background", {=> ()}).key("background")
            Modal(State<Bool>(true)) {
                if (showOpener.value) { Button("Opener", {=> ()}).key("opener") }
                Button("Parent fallback", {=> ()}).key("parent")
                Modal(inner) { Button("Inner", {=> ()}).key("inner") }
            }
        }
        ()
    }
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    inner.value = true
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    inner.value = false
    showOpener.value = false
    let _ = host.frame(MODAL_VIEWPORT, body: view)
    @Expect(host.context.hasFocus("parent"))
    host.reset()
}
