package cui.controls

import sdl.{FrameInfo, Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{Button, FrameHandler, State, StateStore, Theme, UiContext, buildRoot}

// A 400x300 viewport, matching the geometry the assertions below are written against.
private func modalTestContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = 400.0
    ctx.viewportHeight = 300.0
    ctx
}

// A modal hosts a real widget subtree: a press inside the panel reaches the button (release runs
// its action), a press on the backdrop dismisses, and the whole thing rides the interactive overlay.
@Test
func modalRoutesToContentAndBackdropDismisses(): Unit {
    let ctx = modalTestContext()
    let presented = State<Bool>(true)
    let clicked = State<Bool>(false)
    let modal = Modal(presented) {
        Button("确定", {=> clicked.value = true}).key("ok")
    }
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    @Expect(ctx.hasOverlay())

    // The single button centres at the viewport centre; press then release runs its action.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 200.0, 150.0)))
    @Expect(ctx.dispatchOverlay(UiEvent.MouseUp(MouseButton.Left, 200.0, 150.0)))
    @Expect(clicked.value)
    @Expect(presented.value) // the button didn't close it

    // A press on the backdrop (outside the panel) dismisses.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0)))
    @Expect(!presented.value)
    @Expect(!ctx.hasOverlay())
}

@Test
func modalEscapeDismissesAndHiddenRegistersNothing(): Unit {
    let ctx = modalTestContext()

    let open = State<Bool>(true)
    let modal = Modal(open) {
        Button("x", {=> ()}).key("x")
    }
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    @Expect(ctx.hasOverlay())
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!open.value)
    @Expect(!ctx.hasOverlay())

    // A dialog that starts hidden builds no content and registers no overlay.
    let hidden = State<Bool>(false)
    let quiet = Modal(hidden) {
        Button("y", {=> ()}).key("y")
    }
    quiet.layout(ctx, Rect.zero())
    quiet.draw(ctx)
    @Expect(!ctx.hasOverlay())
}

// If `presented` flips true after construction (as when a button opens the dialog mid-frame), the
// body is still None until the next build — draw must not register an (empty) overlay that frame.
@Test
func modalWaitsForBodyBeforeRegistering(): Unit {
    let ctx = modalTestContext()
    let presented = State<Bool>(false) // built hidden -> content is None
    let modal = Modal(presented) {
        Button("x", {=> ()}).key("x")
    }
    modal.layout(ctx, Rect.zero())

    presented.value = true // simulate an in-frame open, before a rebuild constructs the body
    modal.draw(ctx)
    @Expect(!ctx.hasOverlay()) // no empty panel; the dialog appears next frame
}

// The dialog subtree hangs off the overlay, but the shell dispatches the per-frame tick to the
// tree — Modal.handle must forward it, or timed behaviours inside a dialog (autofocus, an
// application Frame hook) would never run.
@Test
func modalForwardsFrameTickToContent(): Unit {
    let ctx = modalTestContext()
    let presented = State<Bool>(true)
    let ticks = State<Int64>(0)
    let modal = Modal(presented) {
        FrameHandler(onFrame: {_ => ticks.value = ticks.value + 1}) {
            Button("x", {=> ()}).key("x")
        }
    }
    modal.layout(ctx, Rect.zero())
    @Expect(!modal.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(16), UInt64(16)))))
    @Expect(ticks.value, Int64(1))
}

// A modal is a focus trap: Tab cycles the dialog's own focus stops (captured while its body
// was built) and never escapes to the controls under the backdrop.
@Test
func modalTabCyclesDialogFocusOnly(): Unit {
    let ctx = modalTestContext()
    let store = StateStore()
    let presented = State<Bool>(true)
    let captured = State<?Modal>(None)
    let _ = buildRoot({
        =>
        Button("背景", {=> ()}).key("bg")
        captured.value = Some(Modal(presented) {
            Button("甲", {=> ()}).key("m1")
            Button("乙", {=> ()}).key("m2")
        })
    }, store)
    let modal = captured.value.getOrThrow()
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    @Expect(ctx.hasOverlay())

    // From no focus Tab enters at the dialog's first stop, then wraps m1 -> m2 -> m1.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Tab, false)))
    @Expect(ctx.hasFocus("m1"))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Tab, false)))
    @Expect(ctx.hasFocus("m2"))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Tab, false)))
    @Expect(ctx.hasFocus("m1")) // wrapped inside the dialog; "bg" is never visited
}
