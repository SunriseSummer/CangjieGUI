package cui.testing

import cui.core.{EffectCleanup, Spacer, mountEffect}
import sdl.Rect

@Test
func resetClearsInteractionStateEvenWhenAnEffectCleanupFails(): Unit {
    let host = WidgetTestHost()
    let _ = host.frame(Rect(0.0, 0.0, 120.0, 80.0)) {
        mountEffect("failing", {=> EffectCleanup({=> throw IllegalStateException("cleanup")})})
        Spacer()
    }
    host.context.leftMouseDown = true
    host.context.beginDrag("old")
    host.context.press("old")
    var failed = false
    try { host.reset() } catch (_: IllegalStateException) { failed = true }
    @Expect(failed)
    @Expect(!host.context.leftMouseDown)
    @Expect(host.context.dragId.isEmpty())
    @Expect(host.context.pressedId.isEmpty())
}
