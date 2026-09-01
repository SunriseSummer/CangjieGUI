package cui.desktop

import sdl.{Rect, Size, UiEvent}
import cui.core.{AccessibilityAdapter, AccessibilityUpdate, Semantics, SemanticsNode, SemanticsRole, UiContext, Widget,
    emit}
import cui.testing.WidgetTestHost

private class DesktopAccessibilityBridgeProbe <: DesktopAccessibilityBridge {
    var updates: Int64 = 0
    var drains: Int64 = 0
    var closes: Int64 = 0
    var failUpdate: Bool = false
    var failDrain: Bool = false
    var lastRevision: UInt64 = UInt64(0)

    public func update(value: AccessibilityUpdate): Unit {
        updates += 1
        if (failUpdate) {
            throw IllegalStateException("native accessibility update failed")
        }
        lastRevision = value.snapshot.revision
    }

    /* Exercises the native action-drain boundary. */
    public func drainActions(): Unit {
        drains += 1
        if (failDrain) {
            throw IllegalStateException("native accessibility action drain failed")
        }
    }

    /* Records deterministic native bridge cleanup. */
    public func close(): Unit {
        closes += 1
    }
}

private class DesktopAccessibilityAdapterProbe <: AccessibilityAdapter {
    var updates: Int64 = 0
    var failUpdate: Bool = false
    var lastRevision: UInt64 = UInt64(0)

    public func update(value: AccessibilityUpdate): Unit {
        updates += 1
        if (failUpdate) {
            throw IllegalStateException("external accessibility update failed")
        }
        lastRevision = value.snapshot.revision
    }
}

private class DesktopAccessibilityFailureProbe {
    var reports: Int64 = 0
    var revision: UInt64 = UInt64(0)
    var failReport: Bool = false

    func record(failure: AccessibilityFailure): Unit {
        reports += 1
        revision = failure.revision
        if (failReport) {
            throw IllegalStateException("accessibility failure handler failed")
        }
    }
}

private class DesktopAccessibilitySemanticWidget <: Widget {
    private let semanticId: String
    private let label: String

    init(semanticId: String, label: String) {
        this.semanticId = semanticId
        this.label = label
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(context: UiContext, rect: Rect): Unit {
        context.registerSemantics(
            SemanticsNode(semanticId, Semantics(label: label, role: SemanticsRole.Button), rect))
    }

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

@Test
func desktopAccessibilityHubIsolatesAFailedNativeUpdate(): Unit {
    let bridge = DesktopAccessibilityBridgeProbe()
    bridge.failUpdate = true
    let external = DesktopAccessibilityAdapterProbe()
    let hub = DesktopAccessibilityHub(Some(bridge))
    hub.setExternalAdapter(external)
    let host = WidgetTestHost()

    host.context.setAccessibilityAdapter(hub)
    let _ = host.frame(Rect(0.0, 0.0, 120.0, 40.0), body: {
        => DesktopAccessibilitySemanticWidget("save", "Save")
    })

    @Expect(bridge.updates, Int64(1))
    @Expect(external.updates, Int64(2))
    @Expect(external.lastRevision, UInt64(1))
    let failures = hub.takeFailures()
    @Expect(failures.size, Int64(1))
    @Expect(isNativeUpdateFailure(failures[0]))
    @Expect(failures[0].revision, UInt64(0))
    @Expect(hub.takeFailures().isEmpty())
    hub.close()
    @Expect(bridge.closes, Int64(1))
}

@Test
func desktopAccessibilityHubIsolatesAFailedFailureHandler(): Unit {
    let bridge = DesktopAccessibilityBridgeProbe()
    bridge.failDrain = true
    let hub = DesktopAccessibilityHub(Some(bridge))
    let reports = DesktopAccessibilityFailureProbe()
    reports.failReport = true
    hub.setFailureHandler({failure => reports.record(failure)})

    hub.drainActions()

    @Expect(reports.reports, Int64(1))
    let failures = hub.takeFailures()
    @Expect(failures.size, Int64(2))
    @Expect(isNativeDrainFailure(failures[0]))
    @Expect(isFailureHandlerReportFailure(failures[1]))
    @Expect(failures[1].cause.message, "accessibility failure handler failed")
}

@Test
func desktopAccessibilityHubReplaysOnlyToANewExternalAdapter(): Unit {
    let bridge = DesktopAccessibilityBridgeProbe()
    let failing = DesktopAccessibilityAdapterProbe()
    failing.failUpdate = true
    let hub = DesktopAccessibilityHub(Some(bridge))
    hub.setExternalAdapter(failing)
    let host = WidgetTestHost()

    host.context.setAccessibilityAdapter(hub)
    match (hub.takeExternalBootstrapFailure()) {
        case Some(error) => @Expect(error.message, "external accessibility update failed")
        case None => @Expect(false)
    }
    let _ = host.frame(Rect(0.0, 0.0, 120.0, 40.0), body: {
        => DesktopAccessibilitySemanticWidget("save", "Save")
    })
    @Expect(bridge.updates, Int64(2))
    @Expect(failing.updates, Int64(1))

    let recovered = DesktopAccessibilityAdapterProbe()
    hub.setExternalAdapter(recovered)
    host.context.setAccessibilityAdapter(hub)

    @Expect(bridge.updates, Int64(2))
    @Expect(recovered.updates, Int64(1))
    @Expect(recovered.lastRevision, UInt64(1))
    @Expect(hub.takeExternalBootstrapFailure().isNone())
    let failures = hub.takeFailures()
    @Expect(failures.size, Int64(1))
    @Expect(isExternalUpdateFailure(failures[0]))
}

@Test
func desktopAccessibilityHubQuarantinesAFailedActionDrainButStillCloses(): Unit {
    let bridge = DesktopAccessibilityBridgeProbe()
    bridge.failDrain = true
    let hub = DesktopAccessibilityHub(Some(bridge))
    let reports = DesktopAccessibilityFailureProbe()
    hub.setFailureHandler({failure => reports.record(failure)})

    hub.drainActions()
    hub.drainActions()

    @Expect(bridge.drains, Int64(1))
    @Expect(reports.reports, Int64(1))
    @Expect(reports.revision, UInt64(0))
    let failures = hub.takeFailures()
    @Expect(failures.size, Int64(1))
    @Expect(isNativeDrainFailure(failures[0]))
    hub.close()
    @Expect(bridge.closes, Int64(1))
}

private func isNativeUpdateFailure(failure: AccessibilityFailure): Bool {
    match ((failure.source, failure.operation)) {
        case (AccessibilityFailureSource.NativeBridge, AccessibilityFailureOperation.Update) => true
        case _ => false
    }
}

private func isExternalUpdateFailure(failure: AccessibilityFailure): Bool {
    match ((failure.source, failure.operation)) {
        case (AccessibilityFailureSource.ExternalAdapter, AccessibilityFailureOperation.Update) => true
        case _ => false
    }
}

private func isNativeDrainFailure(failure: AccessibilityFailure): Bool {
    match ((failure.source, failure.operation)) {
        case (AccessibilityFailureSource.NativeBridge, AccessibilityFailureOperation.DrainActions) => true
        case _ => false
    }
}

private func isFailureHandlerReportFailure(failure: AccessibilityFailure): Bool {
    match ((failure.source, failure.operation)) {
        case (AccessibilityFailureSource.FailureHandler, AccessibilityFailureOperation.ReportFailure) => true
        case _ => false
    }
}
