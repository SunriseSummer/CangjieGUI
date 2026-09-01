package cui.testing

import sdl.{Rect, Size, UiEvent}
import cui.core.{Spacer, State, UiContext, Widget, emit}

private class RootCompositionValueProbe {
    var latest: Int64 = -1
}

private class RootCompositionValueWidget <: Widget {
    private let value: Int64
    private let probe: RootCompositionValueProbe

    init(value: Int64, probe: RootCompositionValueProbe) {
        this.value = value
        this.probe = probe
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {
        probe.latest = value
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private func sameRootCompositionWidget(left: Widget, right: Widget): Bool {
    let leftObject = left as Object
    let rightObject = right as Object
    match ((leftObject, rightObject)) {
        case (Some(leftValue), Some(rightValue)) => refEq(leftValue, rightValue)
        case _ => false
    }
}

@Test
func automaticRootReusesImplicitMultiChildBoundaryWhenClean(): Unit {
    let host = WidgetTestHost()
    let body: () -> Unit = {
        =>
            Spacer()
            Spacer()
    }

    let first = host.frame(Rect(0.0, 0.0, 100.0, 40.0), body: body)
    let second = host.frame(Rect(0.0, 0.0, 100.0, 40.0), body: body)

    @Expect(sameRootCompositionWidget(first.widget, second.widget))
}

@Test
func automaticRootKeepsBoundaryIdentityButCommitsDirtyMultiChildContent(): Unit {
    let host = WidgetTestHost()
    let revision = State<Int64>(0)
    let probe = RootCompositionValueProbe()
    let body: () -> Unit = {
        =>
            let value = revision.value
            RootCompositionValueWidget(value, probe)
            if (value == 0) {
                Spacer()
            }
    }

    let first = host.frame(Rect(0.0, 0.0, 100.0, 40.0), body: body)
    @Expect(probe.latest, Int64(0))
    revision.value = 1
    let second = host.frame(Rect(0.0, 0.0, 100.0, 40.0), body: body)

    @Expect(sameRootCompositionWidget(first.widget, second.widget))
    @Expect(probe.latest, Int64(1))
}
