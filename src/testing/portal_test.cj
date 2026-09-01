package cui.testing

import sdl.{MouseButton, Rect, UiEvent}
import cui.core.{Button, Portal, Spacer, State, VStack}

@Test
func portalRoutesEventsAndSemanticsToOverlaySubtree(): Unit {
    let host = WidgetTestHost()
    let activations = State<Int64>(0)
    let rect = Rect(0.0, 0.0, 240.0, 160.0)

    let _ = host.frame(rect,
        events: [UiEvent.MouseDown(MouseButton.Left, 60.0, 30.0),
            UiEvent.MouseUp(MouseButton.Left, 60.0, 30.0)]) {
        VStack {
            Spacer()
            Portal("save.portal", true, { _ => Rect(40.0, 10.0, 120.0, 40.0) }) {
                Button("浮层保存", {=> activations.value += 1}).key("portal.save")
            }
        }
    }

    @Expect(activations.value, Int64(1))
    @Expect(host.context.overlayCount(), Int64(1))
    let node = host.context.semanticsSnapshot()[0]
    @Expect(node.id, "portal.save")
    @Expect(isButtonRole(node.properties.role))
}

@Test
func closedPortalBuildsNoBodyAndRegistersNothing(): Unit {
    let host = WidgetTestHost()
    let bodyBuilds = State<Int64>(0)

    let _ = host.frame(Rect(0.0, 0.0, 200.0, 100.0)) {
        Portal("closed.portal", false, {_ => Rect.zero()}) {
            bodyBuilds.value += 1
            Button("hidden", {=> ()})
        }
    }

    @Expect(bodyBuilds.value, Int64(0))
    @Expect(host.context.overlayCount(), Int64(0))
    @Expect(host.context.semanticsSnapshot().isEmpty())
}

@Test
func blockingPortalPreventsEventsFallingThrough(): Unit {
    let host = WidgetTestHost()
    let underlying = State<Int64>(0)
    let rect = Rect(0.0, 0.0, 200.0, 80.0)

    let _ = host.frame(rect,
        events: [UiEvent.MouseDown(MouseButton.Left, 20.0, 20.0),
            UiEvent.MouseUp(MouseButton.Left, 20.0, 20.0)]) {
        Button("under", {=> underlying.value += 1})
        Portal("blocking.portal", true, {_ => rect}, blocksInput: true) {Spacer()}
    }

    @Expect(underlying.value, Int64(0))
}
