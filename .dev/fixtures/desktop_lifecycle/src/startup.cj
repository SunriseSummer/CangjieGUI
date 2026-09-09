package cui_desktop_lifecycle_test

import cui.{Color, DesktopApp, Rect, Size, Theme, UiContext, UiEvent, Widget, WindowSpec, emit}

// Observe native visibility without adding a window-handle escape hatch to DesktopApp.
foreign {
    func SDL_GetWindows(count: CPointer<Int32>): CPointer<CPointer<Unit>>

    func SDL_GetWindowFlags(window: CPointer<Unit>): UInt64

    func SDL_free(value: CPointer<Unit>): Unit
}

func onlyWindowHidden(): Bool {
    var count: Int32 = 0
    let windows = unsafe { SDL_GetWindows(inout count) }
    if (windows.isNull()) {
        throw IllegalStateException("Cannot enumerate startup window")
    }
    try {
        if (count != 1) {
            throw IllegalStateException("Expected one startup window")
        }
        let window = unsafe { windows.read() }
        (unsafe { SDL_GetWindowFlags(window) } & UInt64(8)) != UInt64(0)
    } finally {
        unsafe { SDL_free(CPointer<Unit>(windows)) }
    }
}

private class StartupObservation {
    var correct = true
    var draws: Int64 = 0
}

private class StartupProbe <: Widget {
    private let observation: StartupObservation
    private let failDraw: Bool

    init(observation: StartupObservation, failDraw!: Bool = false) {
        this.observation = observation
        this.failDraw = failDraw
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        observation.correct = observation.correct && (onlyWindowHidden() == (observation.draws == 0))
        available
    }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
    public func draw(ctx: UiContext): Unit {
        observation.correct = observation.correct && (onlyWindowHidden() == (observation.draws == 0))
        if (failDraw) {
            throw IllegalStateException("startup draw failure")
        }
        ctx.renderer.fill(Rect(18.0, 18.0, 120.0, 45.0), Color.rgb(70, 110, 160))
        ctx.renderer.text("首帧 Ready", 22.0, 24.0, Color.rgb(255, 255, 255))
        observation.draws += 1
        if (observation.draws >= 2) {
            ctx.requestClose()
        } else {
            ctx.requestFrame()
        }
    }
}

func verifyStartup(): Bool {
    for (sampling in [Int32(1), Int32(2)]) {
        let observation = StartupObservation()
        let app = DesktopApp(WindowSpec("Startup visibility E2E", 240, 140, vsync: false, supersample: sampling),
            theme: Theme.light())
        observation.correct = onlyWindowHidden()
        app.run {StartupProbe(observation)}
        if (!observation.correct || observation.draws != 2) {
            return false
        }
    }
    let failed = StartupObservation()
    let app = DesktopApp(WindowSpec("Startup failure E2E", 240, 140, vsync: false))
    failed.correct = onlyWindowHidden()
    try {
        app.run {StartupProbe(failed, failDraw: true)}
        return false
    } catch (_: IllegalStateException) {
        return failed.correct && failed.draws == 0
    }
}
