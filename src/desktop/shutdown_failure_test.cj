package cui.desktop

import std.collection.ArrayList
import sdl.WindowSpec

private class ShutdownFailureProbe <: Resource {
    let failure: String
    var closed = false
    init(failure: String) { this.failure = failure }
    /** Reports whether the resource's close callback ran. */
    public func isClosed(): Bool { closed }
    /** Records release before injecting a cleanup failure. */
    public func close(): Unit {
        closed = true
        throw IllegalStateException(failure)
    }
}

@Test
func shutdownKeepsTheRunFailureAndAllResourceFailures(): Unit {
    let app = DesktopApp(WindowSpec("Shutdown failure regression", 160, 100))
    let first = ShutdownFailureProbe("first-resource")
    let last = ShutdownFailureProbe("last-resource")
    app.manage(first)
    app.manage(last)
    var message = ""
    try { app.run {=> throw IllegalArgumentException("original-run-failure") } }
    catch (error: Exception) { message = error.message }
    @Expect(message.contains("original-run-failure"))
    @Expect(message.contains("first-resource"))
    @Expect(message.contains("last-resource"))
    @Expect(first.closed && last.closed)
    @Expect(!app.post({=> ()}))
}

@Test
func managedCleanupReportsEveryFailureAndReleasesItsOwnershipList(): Unit {
    let resources = ArrayList<Resource>()
    resources.add(ShutdownFailureProbe("first-resource"))
    resources.add(ShutdownFailureProbe("last-resource"))
    var message = ""
    try { closeResourcesInReverse(resources) }
    catch (error: Exception) { message = error.message }
    @Expect(message.contains("first-resource") && message.contains("last-resource"))
    @Expect(resources.isEmpty())
}
