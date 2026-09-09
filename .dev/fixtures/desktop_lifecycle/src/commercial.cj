package cui_desktop_lifecycle_test

import std.collection.ArrayList
import cui.{CloseRequest, Color, DesktopApp, Rect, Size, UiContext, UiEvent, Widget, WindowSpec, emit}

private class CommercialObservation {
    let requests = ArrayList<CloseRequest>()
    var executed: Int64 = 0
    var chained: Int64 = 0
    var draws: Int64 = 0
    var started = false
    var accepted: ?Int64 = None
    var worker: ?Future<Int64> = None
    var correct = true

    func startWorker(app: DesktopApp): Unit {
        worker = Some(spawn {=>
            try {
                app.run { () }
                return Int64(-1)
            } catch (_: IllegalStateException) { () }
            var admitted: Int64 = 0
            for (_ in 0..10000) {
                if (app.post({=> executed += 1})) { admitted += 1 }
            }
            admitted
        })
    }

    func enqueueNext(app: DesktopApp): Unit {
        chained += 1
        if (chained < 20000) {
            correct = app.post({=> enqueueNext(app)}) && correct
        }
    }
}

private class CommercialProbe <: Widget {
    private let app: DesktopApp
    private let observation: CommercialObservation

    init(app: DesktopApp, observation: CommercialObservation) {
        this.app = app
        this.observation = observation
        emit(this)
    }
    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func handle(_: UiContext, _: UiEvent): Bool { false }
    public func draw(ctx: UiContext): Unit {
        observation.draws += 1
        ctx.renderer.fill(Rect(0.0, 0.0, 100.0, 40.0), Color.rgb(60, 100, 160))
        // Start only after the initial four actions drained: at least one worker action must be admitted.
        if (observation.worker.isNone()) { observation.startWorker(app) }
        if (observation.accepted.isNone()) {
            observation.accepted = observation.worker.getOrThrow().tryGet()
        }
        if (let Some(count) <- observation.accepted) {
            if (!observation.started && app.postStats().pending == 0) {
                observation.correct = observation.correct && count > 0 && observation.executed == count + 4
                observation.started = true
                observation.enqueueNext(app)
                app.requestClose()
                app.requestClose()
                observation.correct = observation.correct && observation.requests.size == 1
                observation.requests[0].cancel()
                app.requestClose()
                observation.correct = observation.correct && observation.requests.size == 2
            }
        }
        if (observation.chained == 20000) {
            observation.correct = observation.correct && observation.draws > 20
            observation.requests[1].accept()
            observation.requests[1].accept()
        } else { ctx.requestFrame() }
    }
}

func verifyCommercialLifecycle(): Bool {
    let app = DesktopApp(WindowSpec("Commercial lifecycle E2E", 240, 120, vsync: false), maxPendingPosts: 4)
    let observation = CommercialObservation()
    app.setCloseRequestHandler({request => observation.requests.add(request)})
    for (_ in 0..4) {
        observation.correct = app.post({=> observation.executed += 1}) && observation.correct
    }
    observation.correct = !app.post({=> observation.correct = false}) && observation.correct
    app.run { CommercialProbe(app, observation) }
    let stats = app.postStats()
    observation.correct && !app.post({=> observation.correct = false}) && stats.pending == 0 &&
        stats.highWatermark <= 4 && stats.rejected > UInt64(0) && !observation.requests[1].isPending()
}
