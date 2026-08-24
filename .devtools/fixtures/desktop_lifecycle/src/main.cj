package cui_desktop_lifecycle_test

import std.collection.ArrayList
import cui.{Color, DesktopApp, EffectCleanup, HStack, Panel, Rect, RetainedScopeDiagnostics, RetainedSubtree, SdlWindow,
    Size, State, UiContext, UiEvent, VStack, Widget, WidgetTestHost, WindowSpec, emit, mountEffect, subscribeFrame}

private let DAMAGE_INCREMENTAL_PATH = "retained-damage.bmp"
private let DAMAGE_FULL_PATH = "retained-full.bmp"
private let DAMAGE_VIEW_WIDTH: Int32 = 160
private let DAMAGE_VIEW_HEIGHT: Int32 = 64
private let DAMAGE_REGION_WIDTH: Float32 = 80.0
private let DAMAGE_TEXT_INSET: Float32 = 8.0
private let AUTOMATIC_PROBE_WIDTH: Float32 = 40.0
private let AUTOMATIC_PROBE_HEIGHT: Float32 = 48.0
private let AUTOMATIC_PAINT_SIZE: Float32 = 32.0
private let AUTOMATIC_COMPLEXITY_ROWS: Int64 = 8
private let DAMAGE_TEXT_COLOR = Color.rgb(245, 245, 245)
private let AUTOMATIC_PROBE_COLOR = Color.rgb(40, 80, 130)
private let STABLE_REGION_COLOR = Color.rgb(40, 115, 70)
private let LEFT_INITIAL_COLOR = Color.rgb(110, 45, 55)
private let LEFT_CHANGED_COLOR = Color.rgb(35, 90, 145)

private class LifecycleObservation {
    var diagnosticsSeen = false
    var effectMounted = false
    var effectClosed = false
}

private class AutomaticDamageObservation {
    var partialSeen = false
}

private enum DamageExpectation {
    | Partial
    | Full
}

private class ManagedResourceProbe <: Resource {
    private let name: String
    private let order: ArrayList<String>
    private let fail: Bool
    private var closed = false

    init(name: String, order: ArrayList<String>, fail!: Bool = false) {
        this.name = name
        this.order = order
        this.fail = fail
    }

    /** Whether this lifecycle probe has already been closed. */
    public func isClosed(): Bool {
        closed
    }

    /** Records cleanup order and optionally raises the configured probe failure. */
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        order.add(name)
        if (fail) {
            throw IllegalStateException("managed resource close probe")
        }
    }
}

private class CloseOnFrame <: Widget {
    init(app: DesktopApp, observation: LifecycleObservation) {
        subscribeFrame(
            {
                ctx, _ =>
                    observation.diagnosticsSeen = app.retainedDiagnostics().scopes.size == 1
                    ctx.requestClose()
            }
        )
        emit(this)
    }

    /** Occupies the tiny fixture viewport without imposing a preferred size. */
    public func measure(_: UiContext, available: Size): Size {
        available
    }

    /** Requires no child geometry. */
    public func layout(_: UiContext, _: Rect): Unit {}

    /** Draws no pixels; lifecycle behavior is driven by the frame subscription. */
    public func draw(_: UiContext): Unit {}

    /** Does not consume native input. */
    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class DamagePaintProbe <: Widget {
    private let text: String
    private let color: Color
    private var frame = Rect.zero()

    init(text: String, color: Color) {
        this.text = text
        this.color = color
        emit(this)
    }

    /** Uses a fixed half-window size so the two retained regions never overlap. */
    public func measure(_: UiContext, available: Size): Size {
        Size(min(DAMAGE_REGION_WIDTH, available.w), min(Float32(DAMAGE_VIEW_HEIGHT), available.h))
    }

    /** Stores the region that both paint commands cover. */
    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    /** Emits a solid background plus text, making skipped/replayed regions pixel-observable. */
    public func draw(ctx: UiContext): Unit {
        ctx.renderer.fill(frame, color)
        ctx.renderer.text(text, frame.x + DAMAGE_TEXT_INSET, frame.y + DAMAGE_TEXT_INSET, DAMAGE_TEXT_COLOR)
    }

    /** This paint-only fixture consumes no input. */
    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

private class AutomaticDamageCloseProbe <: Widget {
    private let app: DesktopApp
    private let observation: AutomaticDamageObservation
    private let close: Bool
    private var frame = Rect.zero()

    init(app: DesktopApp, observation: AutomaticDamageObservation, close: Bool) {
        this.app = app
        this.observation = observation
        this.close = close
        emit(this)
    }

    /** Uses the available retained-region size. */
    public func measure(_: UiContext, available: Size): Size {
        Size(min(AUTOMATIC_PROBE_WIDTH, available.w), min(AUTOMATIC_PROBE_HEIGHT, available.h))
    }

    /** Requires no child geometry. */
    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    /** Observes the shell's selected damage path from inside the frame, then closes on update. */
    public func draw(ctx: UiContext): Unit {
        ctx
            .renderer
            .fill(Rect(frame.x, frame.y, min(AUTOMATIC_PAINT_SIZE, frame.w), min(AUTOMATIC_PAINT_SIZE, frame.h)),
                AUTOMATIC_PROBE_COLOR)
        if (close) {
            observation.partialSeen = app.lastFrameUsedPartialDamage()
            ctx.requestClose()
        }
    }

    /** This lifecycle probe consumes no native input. */
    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}

main(args: Array<String>): Int64 {
    if (args.size != 1) {
        return fail("expected exactly one isolated scenario argument")
    }
    let scenario = args[0]
    if (scenario == "retained-damage") {
        runRetainedDamageScenario()
    } else if (scenario == "automatic-partial") {
        runAutomaticDamageScenario(2, DamageExpectation.Partial)
    } else if (scenario == "automatic-fallback") {
        runAutomaticDamageScenario(1, DamageExpectation.Full)
    } else if (scenario == "lifecycle") {
        runLifecycleScenario()
    } else {
        fail("unknown isolated scenario '${scenario}'")
    }
}

private func runRetainedDamageScenario(): Int64 {
    stage("retained-damage:start")
    if (!verifyRetainedDamage()) {
        return fail("retained damage pixel fixture failed")
    }
    stage("retained-damage:passed")
    pass()
}

private func runAutomaticDamageScenario(supersample: Int32, expected: DamageExpectation): Int64 {
    let name = match (expected) {
        case DamageExpectation.Partial => "automatic-partial"
        case DamageExpectation.Full => "automatic-fallback"
    }
    stage("${name}:start")
    if (!verifyDesktopAutomaticDamage(supersample, expected)) {
        return fail("DesktopApp ${name} contract failed")
    }
    stage("${name}:passed")
    pass()
}

private func runLifecycleScenario(): Int64 {
    stage("lifecycle:start")
    let order = ArrayList<String>()
    let first = ManagedResourceProbe("first", order)
    let failing = ManagedResourceProbe("failing", order, fail: true)
    let last = ManagedResourceProbe("last", order)
    let observation = LifecycleObservation()
    let app = DesktopApp(
        WindowSpec("CUI lifecycle E2E", DAMAGE_VIEW_HEIGHT, DAMAGE_VIEW_HEIGHT, vsync: false, supersample: 1))
    app.manage(first)
    app.manage(failing)
    app.manage(last)

    stage("lifecycle:background-manage:start")
    if (!backgroundManageIsRejected(app, order)) {
        return fail("background manage was not rejected")
    }
    stage("lifecycle:background-manage:passed")
    stage("lifecycle:run:start")
    if (!runEndsWithCleanupFailure(app, observation) || !correctCleanup(order, first, failing, last)) {
        return fail("managed resource cleanup contract failed")
    }
    stage("lifecycle:run:passed")
    if (!observation.diagnosticsSeen || !observation.effectMounted || !observation.effectClosed) {
        return fail("retained diagnostics or effect lifecycle contract failed")
    }
    if (app.post({=> ()})) {
        return fail("post was accepted after shutdown")
    }
    stage("lifecycle:reuse:start")
    if (!reuseIsRejected(app, observation)) {
        return fail("DesktopApp instance was reusable after shutdown")
    }
    stage("lifecycle:reuse:passed")

    stage("lifecycle:passed")
    pass()
}

private func pass(): Int64 {
    println("@@DESKTOP_LIFECYCLE|passed") // cjcheck-ignore: no-println # machine-readable E2E success protocol consumed by test_desktop_lifecycle.py
    0
}

private func verifyDesktopAutomaticDamage(supersample: Int32, expected: DamageExpectation): Bool {
    let observation = AutomaticDamageObservation()
    let changed = State<Int64>(0)
    let app = DesktopApp(
        WindowSpec("CUI automatic damage E2E", DAMAGE_VIEW_WIDTH, DAMAGE_VIEW_HEIGHT, vsync: false,
            supersample: supersample))
    app.run {
        mountEffect(
            "publish-update",
            {
                =>
                    let update = spawn {=> app.post({=> changed.value = 1})}
                    EffectCleanup({=> let _ = update.get()})
            }
        )
        HStack {
            Panel(flexible: false) {
                VStack {
                    for (index in 0..AUTOMATIC_COMPLEXITY_ROWS) {
                        Panel(flexible: false) {
                            AutomaticDamageCloseProbe(app, observation, index == 0 && changed.value == 1)
                        }
                    }
                }.spacing(0.0)
            }.width(48.0)
            DamagePaintProbe("stable", STABLE_REGION_COLOR)
        }
    }
    match (expected) {
        case DamageExpectation.Partial => observation.partialSeen
        case DamageExpectation.Full => !observation.partialSeen
    }
}

private func verifyRetainedDamage(): Bool {
    let window = SdlWindow(
        WindowSpec("CUI retained damage E2E", DAMAGE_VIEW_WIDTH, DAMAGE_VIEW_HEIGHT, vsync: false, supersample: 2))
    let host = WidgetTestHost(renderer: window.renderer)
    let changed = State<Int64>(0)
    let viewport = Rect(0.0, 0.0, Float32(DAMAGE_VIEW_WIDTH), Float32(DAMAGE_VIEW_HEIGHT))
    let body: () -> Unit = {=> damageView(changed)}
    try {
        let initial = host.frame(viewport, body: body)
        if (initial.metrics.textDraws != UInt64(2)) {
            return false
        }
        let damage = scopeBounds(host.retainedDiagnostics().scopes, "left")
        changed.value = 1
        let incremental = host.frame(viewport, damage: Some(damage), body: body)
        window.renderer.captureBmp(DAMAGE_INCREMENTAL_PATH)
        let full = host.frame(viewport, body: body)
        window.renderer.captureBmp(DAMAGE_FULL_PATH)
        incremental.metrics.textDraws == UInt64(1) && full.metrics.textDraws == UInt64(2)
    } finally {
        host.reset()
        window.close()
    }
}

private func damageView(changed: State<Int64>): Unit {
    HStack {
        RetainedSubtree("left", cachePaint: true) {
            let value = changed.value
            DamagePaintProbe("left ${value}", if (value == 0) {
                LEFT_INITIAL_COLOR
            } else {
                LEFT_CHANGED_COLOR
            })
        }
        RetainedSubtree("right", cachePaint: true) {
            DamagePaintProbe("right", STABLE_REGION_COLOR)
        }
    }
}

private func scopeBounds(scopes: Array<RetainedScopeDiagnostics>, path: String): Rect {
    for (scope in scopes) {
        if (scope.path == path) {
            return scope.bounds
        }
    }
    throw IllegalStateException("Missing retained scope '${path}'")
}

private func backgroundManageIsRejected(app: DesktopApp, order: ArrayList<String>): Bool {
    let rejectedResource = ManagedResourceProbe("background", order)
    let result = spawn {
        => try {
            app.manage(rejectedResource)
            false
        } catch (_: IllegalStateException) {
            true
        }
    }
    result.get() && !rejectedResource.isClosed()
}

private func runEndsWithCleanupFailure(app: DesktopApp, observation: LifecycleObservation): Bool {
    try {
        app.run(
            {
                =>
                    mountEffect(
                        "desktop-lifecycle",
                        {
                            =>
                                observation.effectMounted = true
                                EffectCleanup({=> observation.effectClosed = true})
                        }
                    )
                    CloseOnFrame(app, observation)
            }
        )
        false
    } catch (_: IllegalStateException) {
        true
    }
}

private func reuseIsRejected(app: DesktopApp, observation: LifecycleObservation): Bool {
    try {
        app.run({=> CloseOnFrame(app, observation)})
        false
    } catch (_: IllegalStateException) {
        true
    }
}

private func correctCleanup(
    order: ArrayList<String>,
    first: ManagedResourceProbe,
    failing: ManagedResourceProbe,
    last: ManagedResourceProbe
): Bool {
    order.size == 3 && order[0] == "last" && order[1] == "failing" && order[2] == "first" && first.isClosed() &&
        failing.isClosed() && last.isClosed()
}

private func fail(message: String): Int64 {
    println("@@DESKTOP_LIFECYCLE|failed|${message}") // cjcheck-ignore: no-println # machine-readable E2E failure protocol consumed by test_desktop_lifecycle.py
    1
}

private func stage(message: String): Unit {
    print("@@DESKTOP_STAGE|${message}\n", flush: true) // cjcheck-ignore: no-println # flushed stage protocol attributes E2E timeouts to the exact real-window scenario
}
