package cui.desktop

import std.collection.ArrayList
import sdl.SdlWindow
import cui.core.{AccessibilityAdapter, AccessibilityUpdate}

/*
 * Accessibility consumers form independent effect branches: each revision is offered to every
 * live branch, while one rejection quarantines only that branch. Per-branch revision cursors make
 * installing a new observer a replay to that observer instead of a duplicate native publication.
 */
class DesktopAccessibilityHub <: AccessibilityAdapter {
    private let nativeBridge: ?DesktopAccessibilityBridge
    private var nativeActive: Bool
    private var nativeRevision: ?UInt64 = None
    private var externalAdapter: ?AccessibilityAdapter = None
    private var externalRevision: ?UInt64 = None
    private var externalAwaitingBootstrap: Bool = false
    private var externalBootstrapFailure: ?Exception = None
    private var failureHandler: ?(AccessibilityFailure) -> Unit = None
    private let pendingFailures = ArrayList<AccessibilityFailure>()

    init(window: SdlWindow) {
        nativeBridge = createDesktopAccessibilityBridge(window)
        nativeActive = nativeBridge.isSome()
    }

    init(nativeBridge: ?DesktopAccessibilityBridge) {
        this.nativeBridge = nativeBridge
        nativeActive = nativeBridge.isSome()
    }

    func hasNativeBridge(): Bool {
        nativeBridge.isSome()
    }

    func setExternalAdapter(adapter: AccessibilityAdapter): Unit {
        externalAdapter = Some(adapter)
        externalRevision = None
        externalAwaitingBootstrap = true
        externalBootstrapFailure = None
    }

    func setFailureHandler(handler: (AccessibilityFailure) -> Unit): Unit {
        failureHandler = Some(handler)
    }

    func takeExternalBootstrapFailure(): ?Exception {
        let failure = externalBootstrapFailure
        externalBootstrapFailure = None
        failure
    }

    func takeFailures(): Array<AccessibilityFailure> {
        let failures = pendingFailures.toArray()
        pendingFailures.clear()
        failures
    }

    public func update(value: AccessibilityUpdate): Unit {
        updateNative(value)
        updateExternal(value)
    }

    private func updateNative(value: AccessibilityUpdate): Unit {
        if (!nativeActive || !needsAccessibilityDelivery(nativeRevision, value.snapshot.revision)) {
            return
        }
        match (nativeBridge) {
            case Some(bridge) => try {
                bridge.update(value)
                nativeRevision = Some(value.snapshot.revision)
            } catch (error: Exception) {
                nativeActive = false
                recordFailure(AccessibilityFailureSource.NativeBridge, AccessibilityFailureOperation.Update,
                    value.snapshot.revision, error)
            }
            case None => ()
        }
    }

    private func updateExternal(value: AccessibilityUpdate): Unit {
        if (!needsAccessibilityDelivery(externalRevision, value.snapshot.revision)) {
            return
        }
        match (externalAdapter) {
            case Some(adapter) => try {
                adapter.update(value)
                externalRevision = Some(value.snapshot.revision)
                externalAwaitingBootstrap = false
            } catch (error: Exception) {
                externalAdapter = None
                externalRevision = None
                if (externalAwaitingBootstrap) {
                    externalBootstrapFailure = Some(error)
                }
                externalAwaitingBootstrap = false
                recordFailure(AccessibilityFailureSource.ExternalAdapter, AccessibilityFailureOperation.Update,
                    value.snapshot.revision, error)
            }
            case None => ()
        }
    }

    func drainActions(): Unit {
        if (!nativeActive) {
            return
        }
        match (nativeBridge) {
            case Some(bridge) => try {
                bridge.drainActions()
            } catch (error: Exception) {
                nativeActive = false
                recordFailure(AccessibilityFailureSource.NativeBridge, AccessibilityFailureOperation.DrainActions,
                    deliveredRevision(nativeRevision), error)
            }
            case None => ()
        }
    }

    func close(): Unit {
        match (nativeBridge) {
            case Some(bridge) => bridge.close()
            case None => ()
        }
    }

    private func recordFailure(
        source: AccessibilityFailureSource,
        operation: AccessibilityFailureOperation,
        revision: UInt64,
        cause: Exception
    ): Unit {
        let failure = AccessibilityFailure(source, operation, revision, cause)
        pendingFailures.add(failure)
        match (failureHandler) {
            case Some(handler) => try {
                handler(failure)
            } catch (error: Exception) {
                failureHandler = None
                pendingFailures.add(
                    AccessibilityFailure(AccessibilityFailureSource.FailureHandler,
                        AccessibilityFailureOperation.ReportFailure, revision, error))
            }
            case None => ()
        }
    }
}

interface DesktopAccessibilityBridge <: AccessibilityAdapter {
    func drainActions(): Unit
    func close(): Unit
}

@When[os != "Windows"]
func createDesktopAccessibilityBridge(_: SdlWindow): ?DesktopAccessibilityBridge {
    None
}

private func needsAccessibilityDelivery(previous: ?UInt64, revision: UInt64): Bool {
    match (previous) {
        case Some(value) => value != revision
        case None => true
    }
}

private func deliveredRevision(value: ?UInt64): UInt64 {
    match (value) {
        case Some(revision) => revision
        case None => UInt64(0)
    }
}
