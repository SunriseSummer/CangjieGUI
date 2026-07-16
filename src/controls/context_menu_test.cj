package cui.controls

import sdl.{Key, MouseButton, Rect, Renderer, Size, UiEvent}
import cui.core.{State, Theme, UiContext, Widget, emit}

private func menuTestContext(w: Float32, h: Float32): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.viewportWidth = w
    ctx.viewportHeight = h
    ctx
}

// A layout probe with a fixed desired size, standing in for real content under the menu target.
private class SizedLayoutProbe <: Widget {
    let desired: Size

    init(desired: Size) {
        this.desired = desired
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(min(desired.w, available.w), min(desired.h, available.h))
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

// A right press opens the menu at the pointer; the popup is registered as the active overlay,
// and a left click on a row runs that item's action and closes.
@Test
func contextMenuOpensOnRightClickAndRunsItem(): Unit {
    let ctx = menuTestContext(300.0, 400.0)
    let ran = State<Int64>(0)
    let menu = ContextMenu(items: [MenuItem("复制", {=> ran.value = 1}), MenuItem("删除", {=> ran.value = 2})]) {
        emit(SizedLayoutProbe(Size(120.0, 60.0)))
    }
    menu.layout(ctx, Rect(20.0, 20.0, 120.0, 60.0))

    // A left click alone does nothing (no menu yet); a right click inside opens it.
    @Expect(!menu.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 40.0, 40.0)))
    @Expect(menu.handle(ctx, UiEvent.MouseDown(MouseButton.Right, 40.0, 40.0)))
    menu.draw(ctx)
    @Expect(ctx.hasOverlay())

    // Menu opens at (40,40); rows begin at y=45, height 28 each. y=80 falls in the second row.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 60.0, 80.0)))
    @Expect(ran.value, Int64(2))
    @Expect(!ctx.hasOverlay())
}

// A click outside dismisses without running anything; reopened, arrow keys move the highlight and
// Enter runs the highlighted item.
@Test
func contextMenuDismissesAndKeyboardRunsHighlight(): Unit {
    let ctx = menuTestContext(300.0, 400.0)
    let ran = State<Int64>(0)
    let menu = ContextMenu(
        items: [MenuItem("A", {=> ran.value = 1}), MenuItem("B", {=> ran.value = 2}), MenuItem("C", {=> ran.value = 3})]) {
        emit(SizedLayoutProbe(Size(120.0, 60.0)))
    }
    menu.layout(ctx, Rect(20.0, 20.0, 120.0, 60.0))

    let _ = menu.handle(ctx, UiEvent.MouseDown(MouseButton.Right, 40.0, 40.0))
    menu.draw(ctx)
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 5.0, 5.0)))
    @Expect(ran.value, Int64(0))
    @Expect(!ctx.hasOverlay())

    // Reopen, move highlight down twice (0 -> 2), Enter runs "C".
    let _ = menu.handle(ctx, UiEvent.MouseDown(MouseButton.Right, 40.0, 40.0))
    menu.draw(ctx)
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))
    let _ = ctx.dispatchOverlay(UiEvent.KeyDown(Key.Down, false))
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(ran.value, Int64(3))
    @Expect(!ctx.hasOverlay())
}

// The nesting the overlay stack exists for: a popup opened from inside a modal dialog. The
// menu registers above the dialog, sees events first, and running an item closes only the
// menu — the dialog keeps its own registration and dismisses on a later Escape.
@Test
func contextMenuInsideModalStacksAboveDialog(): Unit {
    let ctx = menuTestContext(400.0, 300.0)
    let presented = State<Bool>(true)
    let ran = State<Bool>(false)
    let modal = Modal(presented) {
        ContextMenu(items: [MenuItem("刷新", {=> ran.value = true})]) {
            emit(SizedLayoutProbe(Size(200.0, 100.0)))
        }
    }
    modal.layout(ctx, Rect.zero())
    modal.draw(ctx)
    @Expect(ctx.overlayCount(), Int64(1))

    // Content 200x100 plus 22px padding centres the dialog at (78,78,244,144); the body sits
    // at (100,100,200,100). A right press inside is routed through the dialog and opens the
    // menu at the pointer; drawing the stack then registers the menu above the dialog.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Right, 150.0, 120.0)))
    ctx.drawActiveOverlay()
    @Expect(ctx.overlayCount(), Int64(2))

    // The menu opens at (150,120); its single row spans y 125..153. Choosing it runs the
    // action and closes the menu only — the dialog beneath stays open.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 160.0, 130.0)))
    @Expect(ran.value)
    @Expect(ctx.overlayCount(), Int64(1))
    @Expect(presented.value)

    // With the menu gone, Escape reaches the dialog and dismisses it.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Escape, false)))
    @Expect(!presented.value)
    @Expect(!ctx.hasOverlay())
}

// A press in the menu's padding strip (above the first row) runs nothing and just closes —
// previously the negative row fraction truncated to 0 and ran the first item.
@Test
func contextMenuPaddingPressRunsNothing(): Unit {
    let ctx = menuTestContext(300.0, 400.0)
    let ran = State<Int64>(0)
    let menu = ContextMenu(items: [MenuItem("甲", {=> ran.value = 1}), MenuItem("乙", {=> ran.value = 2})]) {
        emit(SizedLayoutProbe(Size(120.0, 60.0)))
    }
    menu.layout(ctx, Rect(20.0, 20.0, 120.0, 60.0))
    let _ = menu.handle(ctx, UiEvent.MouseDown(MouseButton.Right, 40.0, 40.0))
    menu.draw(ctx)

    // The menu opens at (40,40); its top padding spans y 40..45.
    @Expect(ctx.dispatchOverlay(UiEvent.MouseDown(MouseButton.Left, 60.0, 42.0)))
    @Expect(ran.value, Int64(0))
    @Expect(!ctx.hasOverlay())
}
