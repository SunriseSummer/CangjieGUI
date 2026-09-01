package cui.testing

import sdl.Rect
import cui.core.{Spacer, State}

private class TransactionFailureBuildProbe {
    var bodies: Int64 = 0
    var didThrow = false

    func visit(): Unit {
        bodies += 1
    }
}

@Test
func transactionObserverFailureCannotLeaveLaterAutomaticDependencyClean(): Unit {
    let host = WidgetTestHost()
    let failing = State<Int64>(0)
    let visible = State<Int64>(0)
    let probe = TransactionFailureBuildProbe()
    let observation = failing.observe({_, _ => throw IllegalStateException("expected business observer failure")})
    let body: () -> Unit = {
        =>
            probe.visit()
            let _ = visible.value
            Spacer()
    }
    let rect = Rect(0.0, 0.0, 200.0, 100.0)
    let _ = host.frame(rect, body: body)

    try {
        host.batch(
            {
                =>
                    failing.value = 1
                    visible.value = 1
            }
        )
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }
    let _ = host.frame(rect, body: body)

    @Expect(probe.didThrow)
    @Expect(visible.value, Int64(1))
    @Expect(probe.bodies, Int64(2))
    observation.close()
}
