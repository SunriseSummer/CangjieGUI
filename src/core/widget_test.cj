package cui.core

import sdl.{Color, FrameInfo, IconName, Key, MouseButton, Rect, Renderer, Size, SurfaceStyle, UiEvent}

internal func testContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

@Test
func uiContextTracksFocusAndDrag(): Unit {
    let ctx = testContext()

    ctx.focus("input")
    ctx.beginDrag("slider")

    @Expect(ctx.hasFocus("input"))
    @Expect(ctx.isDragging("slider"))

    ctx.clearDrag()
    @Expect(!ctx.isDragging("slider"))
}

@Test
func frameHandlerReceivesFrameInfo(): Unit {
    let ctx = testContext()
    let count = State<Int64>(0)
    let handler = FrameHandler(onFrame: {
        info => if (info.deltaMs == UInt64(16)) {
            count.value += 1
        }
    }) {
        Spacer()
    }

    @Expect(!handler.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(100), UInt64(16)))))
    @Expect(count.value, Int64(1))
}

@Test
func stackBroadcastsFrameEventsToAllChildren(): Unit {
    let ctx = testContext()
    let first = State<Int64>(0)
    let second = State<Int64>(0)
    let stack = VStack {
        FrameHandler(onFrame: {_ => first.value += 1}) {
            Spacer()
        }
        FrameHandler(onFrame: {_ => second.value += 1}) {
            Spacer()
        }
    }

    @Expect(!stack.handle(ctx, UiEvent.Frame(FrameInfo(UInt64(100), UInt64(16)))))
    @Expect(first.value, Int64(1))
    @Expect(second.value, Int64(1))
}

@Test
func stackBuildersSupportTrailingLambdaSyntax(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let view = VStack(padding: LengthInsets(2.vp)) {
        Label("Title")
        HStack(spacing: 0.vp) {
            Button("Run", {=> pressed.value = true})
            Spacer()
        }
    }

    view.layout(ctx, Rect(0.0, 0.0, 240.0, 120.0))

    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 44.0)))
    @Expect(view.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 10.0, 44.0)))
    @Expect(pressed.value)
}

@Test
func panelSupportsStyledTrailingLambdaContent(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let panel = Panel(
        padding: LengthInsets(6.vp),
        style: Some(SurfaceStyle(Color.rgb(250, 250, 250), border: Color.rgb(120, 130, 140), radius: 10.0))
    ) {
        Button("Go", {=> pressed.value = true})
    }

    panel.layout(ctx, Rect(0.0, 0.0, 120.0, 60.0))

    @Expect(panel.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(panel.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0)))
    @Expect(pressed.value)
}

@Test
func iconButtonSupportsTrailingLambdaAction(): Unit {
    let ctx = testContext()
    let pressed = State<Bool>(false)
    let button = IconButton(IconName.Save, label: Some("Save"), role: ButtonRole.Primary) {
        => pressed.value = true
    }

    button.layout(ctx, Rect(0.0, 0.0, 100.0, 34.0))

    @Expect(button.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 12.0, 12.0)))
    @Expect(button.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 12.0, 12.0)))
    @Expect(pressed.value)
}

/*
 * Regression: two icon-only buttons in one row used to share the "IconButton" identity.
 * The later button then swallowed the release meant for the earlier one, so a calendar's
 * previous-month chevron never fired. Build-order identities keep them separate.
 */
@Test
func iconOnlyButtonsInOneRowKeepSeparatePressIdentity(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let leftClicks = State<Int64>(0)
    let rightClicks = State<Int64>(0)
    let view = buildRoot({
        => HStack {
            IconButton(IconName.ChevronLeft) {
                => leftClicks.value += 1
            }
            IconButton(IconName.ChevronRight) {
                => rightClicks.value += 1
            }
        }
    }, store)

    view.layout(ctx, Rect(0.0, 0.0, 200.0, 40.0))

    @Expect(view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0)))
    @Expect(view.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0)))
    @Expect(leftClicks.value, Int64(1))
    @Expect(rightClicks.value, Int64(0))
}

/*
 * Desktop blur convention: a primary press that no control claims clears focus, so a
 * focused text field loses its active style when the user clicks empty space.
 */
@Test
func unclaimedPressClearsFocusAndClaimedPressKeepsIt(): Unit {
    let store = StateStore()
    let ctx = testContext()
    let view = buildRoot({
        => VStack {
            Button("确定", {=> ()})
            Spacer()
        }
    }, store)
    view.layout(ctx, Rect(0.0, 0.0, 200.0, 200.0))

    ctx.beginPointerPress()
    let _ = view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 10.0, 10.0))
    ctx.settleFocusAfterPress()
    @Expect(ctx.focusId != "")

    ctx.beginPointerPress()
    let _ = view.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 150.0))
    ctx.settleFocusAfterPress()
    @Expect(ctx.focusId, "")
}

@Test
func multiClickCountsRapidPressesAndResetsWhenSlowOrFar(): Unit {
    let ctx = testContext()

    ctx.frame = FrameInfo(UInt64(100), UInt64(0))
    ctx.recordPress(10.0, 10.0)
    @Expect(ctx.clickCount, 1)

    ctx.frame = FrameInfo(UInt64(300), UInt64(0)) // 200ms later, same spot
    ctx.recordPress(10.0, 10.0)
    @Expect(ctx.clickCount, 2)

    ctx.frame = FrameInfo(UInt64(500), UInt64(0))
    ctx.recordPress(11.0, 11.0) // still within the distance threshold
    @Expect(ctx.clickCount, 3)

    ctx.frame = FrameInfo(UInt64(700), UInt64(0)) // a 4th rapid press cycles back to single
    ctx.recordPress(11.0, 11.0)
    @Expect(ctx.clickCount, 1)

    ctx.frame = FrameInfo(UInt64(5000), UInt64(0)) // too slow: resets
    ctx.recordPress(11.0, 11.0)
    @Expect(ctx.clickCount, 1)

    ctx.frame = FrameInfo(UInt64(5100), UInt64(0)) // near in time but far in space: resets
    ctx.recordPress(200.0, 200.0)
    @Expect(ctx.clickCount, 1)
}

@Test
func tooltipRegistersAfterHoverDwellAndClearsOnLeave(): Unit {
    let ctx = testContext()
    let inner = SizedLayoutProbe(Size(80.0, 24.0))
    let tip = Tooltip(text: "保存文档") {
        emit(inner)
    }
    tip.layout(ctx, Rect(10.0, 10.0, 80.0, 24.0))
    ctx.mouseX = 40.0
    ctx.mouseY = 20.0 // inside the frame

    // First frame only arms the dwell timer.
    ctx.frame = FrameInfo(UInt64(0), UInt64(0))
    ctx.clearTooltip()
    tip.draw(ctx)
    @Expect(ctx.tooltipText, "")

    // Past the dwell delay the tooltip registers into the overlay slot.
    ctx.frame = FrameInfo(UInt64(600), UInt64(600))
    ctx.clearTooltip()
    tip.draw(ctx)
    @Expect(ctx.tooltipText, "保存文档")

    // Moving the pointer away resets the timer, so nothing shows.
    ctx.mouseX = 500.0
    ctx.frame = FrameInfo(UInt64(1200), UInt64(600))
    ctx.clearTooltip()
    tip.draw(ctx)
    @Expect(ctx.tooltipText, "")
}

@Test
func eventHandlerConsumesMatchingEvents(): Unit {
    let ctx = testContext()
    let handler = EventHandler(onEvent: {
        event => match (event) {
            case UiEvent.DropFile(path, _, _) => path == "note.txt"
            case _ => false
        }
    }) {
        Spacer()
    }

    @Expect(handler.handle(ctx, UiEvent.DropFile("note.txt", 0.0, 0.0)))
    @Expect(!handler.handle(ctx, UiEvent.DropText("text", 0.0, 0.0)))
}

// Records the rect a stack hands it, so layout math can be asserted directly.
@Test
func disabledControlLeavesFocusRing(): Unit {
    let store = StateStore()
    let _ = buildRoot({
        =>
        Button("甲", {=> ()}).key("a")
        Button("乙", {=> ()}).key("b").enabled(false)
        Button("丙", {=> ()}).key("c").enabled(true)
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 2)
    @Expect(ring[0], "a")
    @Expect(ring[1], "c")
}

// A pointer press focuses without a ring; keyboard focus (autofocus/Tab) shows one — the
// :focus-visible convention. `hasFocus` is unaffected: only the ring gates on the source.
@Test
func focusRingShowsForKeyboardNotPointer(): Unit {
    let ctx = testContext()

    ctx.focus("a") // pointer press
    @Expect(ctx.hasFocus("a"))
    @Expect(!ctx.showFocusRing("a"))

    ctx.focus("b", viaKeyboard: true) // autofocus-style
    @Expect(ctx.hasFocus("b"))
    @Expect(ctx.showFocusRing("b"))
    @Expect(!ctx.showFocusRing("a")) // only the currently focused control

    ctx.focus("c") // pointer again clears the ring
    @Expect(ctx.hasFocus("c"))
    @Expect(!ctx.showFocusRing("c"))

    ctx.clearFocus()
    @Expect(!ctx.hasFocus("c"))
    @Expect(!ctx.showFocusRing("c"))
}

// Tab traversal is keyboard, so the control it lands on shows a ring even if focus started from
// a pointer press.
@Test
func tabTraversalShowsFocusRing(): Unit {
    let ctx = testContext()
    ctx.adoptFocusRing(["one", "two", "three"])

    ctx.focus("one") // pointer: no ring
    @Expect(!ctx.showFocusRing("one"))

    ctx.focusNext()
    @Expect(ctx.hasFocus("two"))
    @Expect(ctx.showFocusRing("two"))

    ctx.focusPrevious()
    @Expect(ctx.hasFocus("one"))
    @Expect(ctx.showFocusRing("one")) // now reached by keyboard
}

@Test
func uiContextProtocolPropertiesNormalizeUnsafeHostValues(): Unit {
    let ctx = testContext()

    ctx.displayScale = 0.0
    ctx.fontScale = -2.0
    ctx.viewportWidth = -100.0
    ctx.viewportHeight = -50.0
    ctx.clickCount = 99

    @Expect(ctx.displayScale, Float32(0.001))
    @Expect(ctx.fontScale, Float32(0.1))
    @Expect(ctx.viewportWidth, Float32(0.0))
    @Expect(ctx.viewportHeight, Float32(0.0))
    @Expect(ctx.clickCount, Int64(3))
}

// Overlays stack: events walk the layers top-most first with unconsumed events falling
// through; drawing walks bottom-up; removing by owner leaves the other layers open.
@Test
func overlayStackDispatchesTopDownAndRemovesByOwner(): Unit {
    let ctx = testContext()
    let trace = State<String>("")
    ctx.setOverlay(Overlay(
        handleEvent: {
            _, _ =>
            trace.value = trace.value + "(base:consume)"
            true
        },
        render: {_ => trace.value = trace.value + "(base:draw)"},
        owner: "base"
    ))
    ctx.setOverlay(Overlay(
        handleEvent: {
            _, _ =>
            trace.value = trace.value + "(top:decline)"
            false
        },
        render: {_ => trace.value = trace.value + "(top:draw)"},
        owner: "top"
    ))
    @Expect(ctx.overlayCount(), Int64(2))

    // The top-most layer sees the event first; declining lets it fall to the one beneath.
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(trace.value, "(top:decline)(base:consume)")

    // Drawing goes bottom-up, so the top-most layer paints last (on top).
    trace.value = ""
    ctx.drawActiveOverlay()
    @Expect(trace.value, "(base:draw)(top:draw)")

    // Removal by owner takes out exactly that layer; the rest stay open.
    ctx.removeOverlay("top")
    @Expect(ctx.overlayCount(), Int64(1))
    trace.value = ""
    @Expect(ctx.dispatchOverlay(UiEvent.KeyDown(Key.Enter, false)))
    @Expect(trace.value, "(base:consume)")

    ctx.clearActiveOverlay()
    @Expect(!ctx.hasOverlay())
}

// Re-registering under an owner already on the stack replaces that entry in place, so a
// control that draws twice within one frame never stacks duplicate popups.
@Test
func overlayReregistrationReplacesInPlace(): Unit {
    let ctx = testContext()
    let painted = State<String>("")
    ctx.setOverlay(Overlay(handleEvent: {_, _ => true},
        render: {_ => painted.value = painted.value + "stale"}, owner: "menu"))
    ctx.setOverlay(Overlay(handleEvent: {_, _ => true},
        render: {_ => painted.value = painted.value + "fresh"}, owner: "menu"))
    @Expect(ctx.overlayCount(), Int64(1))
    ctx.drawActiveOverlay()
    @Expect(painted.value, "fresh")
}

@Test
func overlayOwnerIndexTracksRemovalShiftsAndLaterReplacement(): Unit {
    let ctx = testContext()
    let painted = State<String>("")
    let layer = {
        owner: String, text: String => Overlay(handleEvent: {_, _ => false},
            render: {_ => painted.value = painted.value + text}, owner: owner)
    }
    ctx.setOverlay(layer("base", "base"))
    ctx.setOverlay(layer("middle", "middle-stale"))
    ctx.setOverlay(layer("top", "top-stale"))

    ctx.removeOverlay("middle")
    ctx.setOverlay(layer("top", "top-fresh"))
    ctx.setOverlay(layer("middle", "middle-fresh"))
    ctx.drawActiveOverlay()

    @Expect(ctx.overlayCount(), Int64(3))
    @Expect(painted.value, "basetop-freshmiddle-fresh")
}

@Test
func overlayRemovedDuringDispatchIsSkippedFromTheEventSnapshot(): Unit {
    let ctx = testContext()
    let trace = State<String>("")
    let base = Overlay(handleEvent: {
        _, _ =>
            trace.value = trace.value + "base"
            true
    }, render: {_ => ()}, owner: "base")
    let top = Overlay(handleEvent: {
        context, _ =>
            trace.value = trace.value + "top"
            context.removeOverlay("base")
            false
    }, render: {_ => ()}, owner: "top")
    ctx.registerOverlayFragment(overlaySnapshotFromRegistrations([base, top]))

    @Expect(!ctx.dispatchOverlay(UiEvent.Unknown(UInt32(0))))
    @Expect(trace.value, "top")
    @Expect(ctx.overlayCount(), Int64(1))
}

// Rendering a layer may register further overlays — a popup opened inside a dialog
// registers while the dialog's body draws — and the draw pass picks them up within the
// same frame, painting them above the layer that spawned them.
@Test
func overlayRegisteredDuringRenderPaintsSameFrame(): Unit {
    let ctx = testContext()
    let trace = State<String>("")
    let dialog = Overlay(
        handleEvent: {_, _ => true},
        render: {
            c =>
            trace.value = trace.value + "(dialog)"
            c.setOverlay(Overlay(handleEvent: {_, _ => true},
                render: {_ => trace.value = trace.value + "(popup)"}, owner: "popup"))
        },
        owner: "dialog"
    )
    ctx.registerOverlayFragment(overlaySnapshotFromRegistrations([dialog]))
    ctx.drawActiveOverlay()
    @Expect(trace.value, "(dialog)(popup)")
    @Expect(ctx.overlayCount(), Int64(2))
}

// `.enabled(false)` on a container removes every focus stop in its subtree — a disabled
// form row cannot be Tab-reached — while sibling stops stay in the ring.
@Test
func disabledContainerRemovesSubtreeFocusStops(): Unit {
    let store = StateStore()
    let _ = buildRoot({
        =>
        Button("先", {=> ()}).key("head")
        HStack {
            Button("甲", {=> ()}).key("row.a")
            Button("乙", {=> ()}).key("row.b")
        }.enabled(false)
        Button("后", {=> ()}).key("tail")
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, 2)
    @Expect(ring[0], "head")
    @Expect(ring[1], "tail")
}

@Test
func hiddenControlLeavesFocusRing(): Unit {
    let store = StateStore()
    let _ = buildRoot({
        =>
        Button("甲", {=> ()}).key("a")
        Button("乙", {=> ()}).key("b").visible(false)
        Button("丙", {=> ()}).key("c").visible(true)
    }, store)
    // A hidden control cannot paint a ring or act on Enter/Space, so — like `enabled(false)` —
    // it must leave Tab traversal instead of becoming an invisible dead stop.
    let ring = store.focusRing()
    @Expect(ring.size, 2)
    @Expect(ring[0], "a")
    @Expect(ring[1], "c")
}
