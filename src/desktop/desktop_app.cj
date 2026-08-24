package cui.desktop

import std.collection.ArrayList
import std.collection.concurrent.ConcurrentLinkedQueue
import std.env.getCommandLine
import std.sync.Mutex
import sdl.{FrameInfo, Key, MouseButton, Rect, RenderPass, SdlWindow, UiEvent, UiEventRecord, WindowSpec, SdlException}
import sdl.input.{Cursor, SystemCursor}
import sdl.dialogs.FileDialogOptions
import sdl.dialogs.FileDialogRequest
import sdl.dialogs.FileDialogs
import sdl.system.AppMetadata
import sdl.system.ApplicationMetadata
import sdl.system.SdlHintSetting
import sdl.system.SdlHints
import cui.core.{CursorShape, FrameSchedule, FrameScheduler, RetainedFrameDamage, RetainedGraphDiagnostics, StateStore,
    Theme, UiContext, Widget, broadcastEvent, buildRoot, collectRootLayoutStateReads, collectRootPaintStateReads,
    dispatchEventRecordSequence, dispatchFrameSubscribers, drawTooltip, frameSubscriberCount, retainedGraphDiagnostics,
    takeRetainedFrameDamage, enableAutomaticComposition, useFullRetainedExecution, useIncrementalRetainedExecution,
    withFrameScheduler}

// Long enough for the first paint to settle and for background work started at launch
// (dialog-free examples fetch data on worker threads) to land in the frame.
private let SNAPSHOT_SETTLE_FRAMES: UInt64 = 48
private let MAX_STABILIZATION_PASSES: Int64 = 3
// SDL_WaitEventTimeout is a blocking foreign call. Bounding it avoids occupying a Cangjie M:N
// carrier indefinitely and also drains posted work eventually if SDL rejects a rare wake event.
private let MAX_EVENT_WAIT_MS: Int32 = 250

private enum DesktopAppLifecycle {
    | Ready
    | Running
    | Stopped
}

private class LayoutAttempt {
    let widget: Widget
    let buildNs: UInt64
    let layoutNs: UInt64
    let startGeneration: UInt64
    let endGeneration: UInt64

    init(widget: Widget, buildNs: UInt64, layoutNs: UInt64, startGeneration: UInt64, endGeneration: UInt64) {
        this.widget = widget
        this.buildNs = buildNs
        this.layoutNs = layoutNs
        this.startGeneration = startGeneration
        this.endGeneration = endGeneration
    }
}

private class StableLayout {
    let widget: Widget
    let buildNs: UInt64
    let layoutNs: UInt64
    let passes: Int64
    let generation: UInt64

    init(widget: Widget, buildNs: UInt64, layoutNs: UInt64, passes: Int64, generation: UInt64) {
        this.widget = widget
        this.buildNs = buildNs
        this.layoutNs = layoutNs
        this.passes = passes
        this.generation = generation
    }
}

/*
 * The desktop shell: owns the SDL window and runs the frame loop that incrementally rebuilds dirty
 * declarative scopes from `run`'s body, lays out, dispatches input, and draws. Idle frames are skipped — a frame is only
 * rendered on input, a `State` write, a resize, or a widget's `ctx.requestFrame()`, so time-driven
 * animation must request frames or it freezes. The loop brackets pointer dispatch with the context's
 * focus/hover/click-count protocols, routes events to open overlays before the tree, and paints the
 * tooltip and overlay passes above the tree. Resources registered with `manage` are closed in reverse
 * order, then the window — even when a widget throws out of the loop.
 */
public class DesktopApp {
    private let window: SdlWindow
    private let ctx: UiContext
    private let frameDelay: UInt32
    private let vsync: Bool
    private let resources = ArrayList<Resource>()
    private let stateStore = StateStore()
    private let scheduler = FrameScheduler()
    private let postedActions = ConcurrentLinkedQueue<() -> Unit>()
    private let lifecycleLock = Mutex()
    private var lifecycle = DesktopAppLifecycle.Ready
    private let waitedEvents = ArrayList<UiEventRecord>()
    private let snapshotPath: ?String
    // Per-phase frame timing, enabled with `--profile`; None (and zero cost) in a normal run.
    private let profiler: ?FrameProfiler
    private let retainedDamageEnabled: Bool
    private var lastPartialDamage = false
    private var frames: UInt64 = 0
    private var baseCursor: ?Cursor = None
    private var pointerCursor: ?Cursor = None
    private var textCursor: ?Cursor = None
    private var resizeHCursor: ?Cursor = None
    private var resizeVCursor: ?Cursor = None
    private var appliedShape: ?CursorShape = None
    // The caret rectangle last forwarded to the OS for IME anchoring (logical pixels).
    private var appliedInputAnchor: ?Rect = None

    public init(
        spec: WindowSpec,
        theme!: Theme = Theme.light(),
        frameDelay!: UInt32 = UInt32(16),
        fontScale!: Float32 = 1.0,
        metadata!: ?AppMetadata = None,
        hints!: Array<SdlHintSetting> = []
    ) {
        this.window = configuredWindow(spec, metadata, hints)
        this.ctx = UiContext(window.renderer, theme)
        this.ctx.displayScale = window.scale * window.currentPixelDensity
        this.ctx.fontScale = max(0.1, fontScale)
        this.frameDelay = frameDelay
        this.vsync = spec.vsync
        this.snapshotPath = snapshotArgument()
        enableAutomaticComposition(stateStore)
        let forceFullRetained = fullRetainedExecutionEnabled()
        if (forceFullRetained) {
            useFullRetainedExecution(stateStore)
        } else {
            useIncrementalRetainedExecution(stateStore)
        }
        this.retainedDamageEnabled = !forceFullRetained && !retainedDamageDisabled()
        this.profiler = if (profileEnabled()) {
            Some(FrameProfiler(60))
        } else {
            None
        }
    }

    /** Registers a resource to be closed on shutdown, in reverse registration order. */
    public func manage(resource: Resource): Unit {
        ensureUiAccess("manage resources")
        resources.add(resource)
    }

    /**
     * Prevents the user from shrinking the window below `width` x `height` logical
     * pixels. Layouts do not reflow below their design minimum, so resizable windows
     * should set one to keep content from being squeezed off screen.
     */
    public func setMinimumSize(width: Int32, height: Int32): Unit {
        ensureUiAccess("set the minimum window size")
        window.setMinimumSize(width, height)
    }

    /**
     * Sets the window's resting cursor — the shape shown wherever no control asks for a
     * different one. Applications wanting a themed base pointer (for example a crosshair
     * over a drawing canvas) call this instead of activating a cursor directly, so the
     * hover-driven shapes (a hand over buttons, an I-beam over text) still layer on top.
     */
    public func useBaseCursor(kind: SystemCursor): Unit {
        ensureUiAccess("change the base cursor")
        match (baseCursor) {
            case Some(existing) => existing.close()
            case None => ()
        }
        baseCursor = createCursor(kind)
        appliedShape = None
        applyDesiredCursor()
    }

    /** Runs several UI-state writes as one visual invalidation. Must be called on the UI thread. */
    public func batch(action: () -> Unit): Unit {
        ensureUiAccess("batch UI state")
        withFrameScheduler(scheduler, {=> scheduler.transaction(action)})
    }

    /** Captures the last committed retained execution graph for profiling and bug reports. */
    public func retainedDiagnostics(): RetainedGraphDiagnostics {
        ensureUiAccess("inspect retained diagnostics")
        retainedGraphDiagnostics(stateStore)
    }

    /** Whether the current/most recently drawn frame used automatic retained partial damage. */
    public func lastFrameUsedPartialDamage(): Bool {
        ensureUiAccess("inspect retained frame damage")
        lastPartialDamage
    }

    /**
     * Queues an action from any thread for execution on the UI thread. Returns false after shutdown
     * or when SDL rejects the wake event; while running, bounded event waits still drain queued work.
     */
    public func post(action: () -> Unit): Bool {
        var accepted = false
        synchronized(lifecycleLock) {
            match (lifecycle) {
                case DesktopAppLifecycle.Stopped => ()
                case _ => accepted = postedActions.add(action)
            }
        }
        accepted && window.wake()
    }

    /** Drops all local values created by `rememberState` before the next rebuild. */
    public func clearRememberedState(): Unit {
        batch(
            {
                =>
                    stateStore.clear()
                    scheduler.invalidate()
            }
        )
    }

    /** Opens the native open-file dialog; poll the returned request each frame for the result. */
    public func openFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        ensureUiAccess("open a file dialog")
        FileDialogs.openFile(options: options, window: Some(window))
    }

    /** Opens the native save-file dialog; poll the returned request each frame for the result. */
    public func saveFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        ensureUiAccess("open a save dialog")
        FileDialogs.saveFile(options: options, window: Some(window))
    }

    /** Opens the native pick-folder dialog; poll the returned request each frame for the result. */
    public func openFolderDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        ensureUiAccess("open a folder dialog")
        FileDialogs.openFolder(options: options, window: Some(window))
    }

    /*
     * Runs the frame loop until close: each rendered frame reuses clean declarative scopes and rebuilds
     * dirty paths from `body`, then lays out, dispatches input, and draws. Blocks until the window closes; managed resources
     * and the window are released deterministically even when a widget throws out of the loop. One
     * DesktopApp owns one window lifecycle, so run may be called only once.
     */
    public func run(body: () -> Unit): Unit {
        beginRun()
        // The finally block keeps shutdown deterministic even when a widget throws out of
        // the frame loop: managed resources close in reverse order, then the window.
        try {
            withFrameScheduler(scheduler, {=> runLoop(body)})
        } finally {
            markStoppedAndDiscardPosts()
            try {
                closeManagedResources()
            } finally {
                try {
                    stateStore.clear()
                } finally {
                    window.close()
                }
            }
        }
    }

    private func runLoop(body: () -> Unit): Unit { // cjcheck-ignore: long-function # one visible frame transaction; helpers own waiting and stabilization details
        match (profiler) {
            case Some(_) => println(
                "[profile] 渲染后端 ${ctx.renderer.driverName()}｜超采样 ${ctx.renderer.supersampleFactor()}x｜视口 ${window.width}x${window.height} @ ${window.scale}x")
            case None => ()
        }
        var previousTick = window.ticks()
        var lastRenderedGen = scheduler.generation
        var schedule = FrameSchedule(immediate: true, deadlineMs: None)
        var renderedWidth: Int32 = -1
        var renderedHeight: Int32 = -1
        while (!ctx.shouldClose) {
            let frame = nextFrame(previousTick)
            previousTick = frame.elapsedMs
            ctx.frame = frame
            let events = collectPendingEvents()
            let viewportW = window.width
            let viewportH = window.height
            ctx.viewportWidth = Float32(viewportW)
            ctx.viewportHeight = Float32(viewportH)
            scheduler.transaction({=> drainPostedActions()})
            let stateGen = scheduler.generation
            let forced = snapshotPath.isSome() || profiler.isSome()
            let timerTriggered = schedule.isDue(frame.elapsedMs)
            let stateTriggered = stateGen != lastRenderedGen
            let resized = viewportW != renderedWidth || viewportH != renderedHeight
            let mustRender = timerTriggered || !events.isEmpty() || stateTriggered || resized || forced

            if (mustRender) {
                match (profiler) {
                    case Some(_) => ctx.renderer.resetTextMeasureCount()
                    case None => ()
                }
                var stable = buildAndLayoutStable(body, viewportW, viewportH)
                let eventWidget = stable.widget
                let eventStart = frameProfileTimestamp(profiler)
                scheduler.transaction(
                    {
                        =>
                            dispatchEventRecordSequence(events, ctx, {event => preparePointer(event)}, {
                                event => routeEvent(eventWidget, event)
                            }, {event => completePointer(event)})
                            dispatchFrameSubscribers(stateStore, ctx, frame)
                    }
                )
                let eventEnd = frameProfileTimestamp(profiler)
                if (scheduler.generation != stable.generation) {
                    let reflected = buildAndLayoutStable(body, viewportW, viewportH)
                    stable = StableLayout(reflected.widget, stable.buildNs + reflected.buildNs,
                        stable.layoutNs + reflected.layoutNs, stable.passes + reflected.passes, reflected.generation)
                }
                frames += 1
                lastRenderedGen = stable.generation // writes made during draw intentionally schedule the next frame
                let allowPartialDamage = retainedDamageEnabled && stateTriggered && events.isEmpty() && !timerTriggered &&
                    !resized && snapshotPath.isNone() && frameSubscriberCount(stateStore) == 0 && !ctx.hasOverlay() &&
                    ctx.hoverId.isEmpty() && ctx.focusId.isEmpty() && ctx.dragId.isEmpty() && ctx.pressedId.isEmpty()
                let frameDamage = takeRetainedFrameDamage(stateStore,
                    Rect(0.0, 0.0, Float32(viewportW), Float32(viewportH)), allowPartialDamage)
                let (beginNs, treeNs, resolveNs, presentNs) = draw(stable.widget, frameDamage)
                schedule = ctx.takeFrameSchedule()
                renderedWidth = viewportW
                renderedHeight = viewportH
                match (profiler) {
                    case Some(p) => p.record(
                        FrameProfileSample(
                            FramePhaseTimes(stable.buildNs, stable.layoutNs, eventEnd - eventStart, beginNs, treeNs,
                                resolveNs, presentNs),
                            FrameProfileSignals(stable.passes, !events.isEmpty(), stateTriggered, timerTriggered,
                                resized, forced, frameSubscriberCount(stateStore), lastPartialDamage),
                            FrameTextCounts(ctx.renderer.textMeasureCount(), ctx.renderer.textComputeCount(),
                                ctx.renderer.textShapeCount(), ctx.renderer.textDrawCount())
                        )
                    )
                    case None => ()
                }
            }
            waitForWork(schedule, frame.elapsedMs, scheduler.generation != lastRenderedGen)
        }
    }

    private func buildAndLayoutStable(body: () -> Unit, viewportW: Int32, viewportH: Int32): StableLayout {
        var attempt = buildAndLayoutOnce(body, viewportW, viewportH)
        var buildNs = attempt.buildNs
        var layoutNs = attempt.layoutNs
        var passes: Int64 = 1
        while (attempt.startGeneration != attempt.endGeneration && passes < MAX_STABILIZATION_PASSES) {
            attempt = buildAndLayoutOnce(body, viewportW, viewportH)
            buildNs += attempt.buildNs
            layoutNs += attempt.layoutNs
            passes += 1
        }
        if (attempt.startGeneration != attempt.endGeneration) {
            // A build/layout side effect that never stabilizes must not spin forever. Keep the
            // newest complete tree and ask for another frame; profiling exposes the extra passes.
            ctx.requestFrame()
        }
        StableLayout(attempt.widget, buildNs, layoutNs, passes, attempt.endGeneration)
    }

    private func buildAndLayoutOnce(body: () -> Unit, viewportW: Int32, viewportH: Int32): LayoutAttempt {
        let startGeneration = scheduler.generation
        ctx.clearActiveOverlay()
        let buildStart = frameProfileTimestamp(profiler)
        let widget = buildRoot(body, stateStore)
        let layoutStart = frameProfileTimestamp(profiler)
        ctx.adoptFocusRing(stateStore.focusRing())
        collectRootLayoutStateReads(stateStore, {
            => widget.layout(ctx, Rect(0.0, 0.0, Float32(viewportW), Float32(viewportH)))
        })
        let layoutEnd = frameProfileTimestamp(profiler)
        LayoutAttempt(widget, layoutStart - buildStart, layoutEnd - layoutStart, startGeneration, scheduler.generation)
    }

    private func drainPostedActions(): Unit {
        var next = postedActions.remove()
        while (let Some(action) <- next) {
            action()
            next = postedActions.remove()
        }
    }

    private func waitForWork(schedule: FrameSchedule, frameStartedMs: UInt64, dirtyState: Bool): Unit {
        if (ctx.shouldClose) {
            return
        }
        let forced = snapshotPath.isSome() || profiler.isSome()
        if (schedule.immediate || dirtyState || forced) {
            // Present already blocks on vertical blank when vsync is enabled. Adding the legacy
            // 16ms delay there roughly halves the refresh rate, so only pace an un-synchronised loop.
            if (!vsync && frameDelay > UInt32(0)) {
                let elapsed = tickDelta(frameStartedMs, window.ticks())
                if (elapsed < UInt64(frameDelay)) {
                    window.delay(UInt32(UInt64(frameDelay) - elapsed))
                }
            }
            return
        }

        let now = window.ticks()
        let timeout = eventWaitTimeout(schedule, now)
        match (window.waitEventRecordTimeout(timeout)) {
            case Some(record) => match (record.event) {
                case UiEvent.Wake => ()
                case _ => waitedEvents.add(record)
            }
            case None => () // timer deadline elapsed
        }
    }

    // Polls every event SDL has queued into a buffer, so the render decision can tell whether any input
    // arrived before deciding whether to build a frame at all. Dispatch is deferred (see below).
    private func collectPendingEvents(): ArrayList<UiEventRecord> {
        let events = ArrayList<UiEventRecord>()
        for (event in waitedEvents) {
            events.add(event)
        }
        waitedEvents.clear()
        var current = window.pollEventRecord()
        while (let Some(record) <- current) {
            match (record.event) {
                case UiEvent.Wake => ()
                case _ => events.add(record)
            }
            current = window.pollEventRecord()
        }
        events
    }

    /*
     * Routes one input event. Window-level events belong to the shell and are handled
     * before the overlays, so a modal dialog can neither swallow a quit request nor keep
     * the logical size stale through a resize. The open overlays (dropdowns, menus,
     * dialogs) then see the event before the tree, top-most first — a click inside a
     * popup is not stolen by the dialog or control drawn underneath it, and a dialog
     * consumes whatever its popups decline, protecting the backdrop tree. Pointer
     * bookkeeping brackets BOTH paths: click counting and hover resolution run for
     * overlay-hosted controls (a Modal's fields) exactly as for tree controls, keeping
     * double-clicks and cursor shapes alive there.
     */
    private func routeEvent(widget: Widget, event: UiEvent): Unit {
        if (handleWindowEvent(event)) {
            return
        }
        match (event) {
            case UiEvent.MouseMove(_, _) =>
                // Resolve which control the pointer is over, then reflect its requested
                // shape in the system cursor. Bracketing keeps hover single-winner.
                ctx.beginHoverTest()
                if (!ctx.dispatchOverlay(event)) {
                    dispatchEvent(widget, event)
                }
                ctx.settleHover()
                applyDesiredCursor()
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                // Click counting runs before any dispatch so controls can read it while
                // handling the press, wherever the press lands.
                ctx.recordPress(x, y)
                if (ctx.dispatchOverlay(event)) {
                    return // popups and dialogs manage focus themselves
                }
                // A primary press in the tree either moves focus to the claiming control
                // or blurs the current one, matching desktop conventions.
                ctx.beginPointerPress()
                dispatchEvent(widget, event)
                ctx.settleFocusAfterPress()
            case UiEvent.KeyDown(Key.Tab, _) =>
                if (ctx.dispatchOverlay(event)) {
                    return
                }
                // Tab traversal is a shell responsibility: it walks the build-order
                // focus ring and is not forwarded to the focused control, so a text
                // field cannot swallow it. Shift reverses direction.
                if (ctx.eventModifiers().shift) {
                    ctx.focusPrevious()
                } else {
                    ctx.focusNext()
                }
            case _ =>
                if (!ctx.dispatchOverlay(event)) {
                    dispatchEvent(widget, event)
                }
        }
    }

    private func handleWindowEvent(event: UiEvent): Bool {
        match (event) {
            case UiEvent.Quit => ctx.requestClose()
            case UiEvent.WindowCloseRequested => ctx.requestClose()
            case UiEvent.WindowResized(_, _) =>
                // The SDL wrapper already refreshed while decoding; query once more so custom
                // injected events preserve the same authoritative-size contract.
                let _ = window.refreshSize() // cjcheck-ignore: ignore-result # width/height are consumed at the next loop boundary
                scheduler.invalidate()
            case UiEvent.WindowDisplayScaleChanged => refreshGuiDisplayScale()
            case UiEvent.WindowPixelSizeChanged(_, _) => refreshGuiDisplayScale()
            case UiEvent.WindowExposed => scheduler.invalidate()
            case UiEvent.WindowRestored => scheduler.invalidate()
            case UiEvent.RenderTargetsReset => scheduler.invalidate()
            case UiEvent.RenderDeviceReset => scheduler.invalidate()
            case UiEvent.RenderDeviceLost => scheduler.invalidate()
            case UiEvent.WindowFocusLost => ctx.cancelTransientInput()
            case _ => return false
        }
        true
    }

    private func refreshGuiDisplayScale(): Unit {
        ctx.displayScale = window.scale * window.currentPixelDensity
        scheduler.invalidate()
    }

    // Draws one frame, returning the nanosecond durations of its sub-phases (scene begin, tree draw,
    // supersample resolve, present) for the profiler. The timestamps are a handful of clock reads —
    // negligible against a frame — so they run unconditionally and only the profiler, when enabled,
    // records them.
    private func draw(widget: Widget, damage: RetainedFrameDamage): (UInt64, UInt64, UInt64, UInt64) {
        let t0 = frameProfileTimestamp(profiler)
        let (pass, activeDamage) = beginFramePass(damage)
        // Report the backend decision, not merely the framework's damage plan. A renderer
        // may safely fall back to a full frame when its persistent target is unavailable.
        lastPartialDamage = activeDamage.isSome()
        ctx.setRetainedDamage(activeDamage)
        let t1 = frameProfileTimestamp(profiler)
        var t2 = t1
        try {
            drawFrameContents(widget)
            t2 = frameProfileTimestamp(profiler)
        } finally {
            ctx.setRetainedDamage(None)
            pass.close()
        }
        let t3 = frameProfileTimestamp(profiler)
        maybeSnapshot()
        ctx.renderer.present()
        let t4 = frameProfileTimestamp(profiler)
        (t1 - t0, t2 - t1, t3 - t2, t4 - t3)
    }

    private func beginFramePass(damage: RetainedFrameDamage): (RenderPass, ?Rect) {
        match (damage) {
            case RetainedFrameDamage.Region(rect) =>
                let pass = ctx
                    .renderer
                    .beginRenderPassDamage(Float32(window.width), Float32(window.height), ctx.theme.bg, rect)
                (pass, if (pass.damagePreserved) {
                        Some(rect)
                    } else {
                        None
                    })
            case RetainedFrameDamage.FullFrame => (ctx
                    .renderer
                    .beginRenderPass(Float32(window.width), Float32(window.height), ctx.theme.bg), None)
        }
    }

    private func drawFrameContents(widget: Widget): Unit {
        ctx.clearTooltip()
        ctx.clearTextInputAnchor()
        collectRootPaintStateReads(stateStore, {=> widget.draw(ctx)})
        if (!ctx.hasOverlay()) {
            drawTooltip(ctx, Float32(window.width), Float32(window.height))
        }
        ctx.drawActiveOverlay()
        applyTextInputAnchor()
    }

    /*
     * Forwards the focused caret rectangle to the OS whenever it moves, so the IME
     * composition UI (candidate window) follows typing instead of sitting in a screen
     * corner. Unchanged rectangles are skipped to avoid a per-frame system call, and a
     * platform refusal is ignored — IME anchoring is polish, not frame-critical.
     */
    private func applyTextInputAnchor(): Unit {
        match (ctx.textInputAnchorRect()) {
            case Some(anchor) =>
                if (!sameAnchorRect(appliedInputAnchor, anchor)) {
                    appliedInputAnchor = Some(anchor)
                    try {
                        window.setTextInputArea(anchor)
                    } catch (_: SdlException) {
                        // A refused anchor must not stay cached as applied, or a transient
                        // platform failure would silence IME anchoring for the whole session.
                        appliedInputAnchor = None
                    }
                }
            case None => ()
        }
    }

    // Snapshot mode: `main.exe --snapshot <path.bmp>` renders a few frames so the UI
    // settles, writes the frame to a BMP, then quits. Handy for visual tests and docs.
    private func maybeSnapshot(): Unit {
        match (snapshotPath) {
            case Some(path) where frames >= SNAPSHOT_SETTLE_FRAMES =>
                ctx.renderer.captureBmp(path)
                ctx.requestClose()
            case _ => ()
        }
    }

    // Root dispatch: there is no widget behind the tree root, so the consumed flag has no
    // further recipient and the broadcast form documents that intentionally dropped result.
    private func dispatchEvent(widget: Widget, event: UiEvent): Unit {
        broadcastEvent(widget, ctx, event)
    }

    // Applies the hovered control's requested shape, skipping the SDL call when it is
    // already active. Cursor feedback is non-critical polish: a platform that refuses a
    // shape simply keeps the current cursor rather than failing the frame.
    private func applyDesiredCursor(): Unit {
        let shape = ctx.desiredCursor()
        match (appliedShape) {
            case Some(current) where current == shape => return
            case _ => ()
        }
        appliedShape = Some(shape)
        match (cursorForShape(shape)) {
            case Some(cursor) => try {
                cursor.setActive()
            } catch (_: SdlException) {
                // A refused shape must not stay cached as applied, or the same shape could
                // never be retried; the platform simply keeps the current cursor this frame.
                appliedShape = None
            }
            case None => ()
        }
    }

    private func cursorForShape(shape: CursorShape): ?Cursor {
        match (shape) {
            case CursorShape.Default => ensureCursor(SystemCursor.Default)
            case CursorShape.Interactive => ensurePointerCursor()
            case CursorShape.Text => ensureTextCursor()
            case CursorShape.ResizeH => ensureResizeHCursor()
            case CursorShape.ResizeV => ensureResizeVCursor()
        }
    }

    private func ensureCursor(kind: SystemCursor): ?Cursor {
        match (baseCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                baseCursor = createCursor(kind)
                baseCursor
        }
    }

    private func ensurePointerCursor(): ?Cursor {
        match (pointerCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                pointerCursor = createCursor(SystemCursor.Pointer)
                pointerCursor
        }
    }

    private func ensureTextCursor(): ?Cursor {
        match (textCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                textCursor = createCursor(SystemCursor.Text)
                textCursor
        }
    }

    private func ensureResizeHCursor(): ?Cursor {
        match (resizeHCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                resizeHCursor = createCursor(SystemCursor.EwResize)
                resizeHCursor
        }
    }

    private func ensureResizeVCursor(): ?Cursor {
        match (resizeVCursor) {
            case Some(cursor) => Some(cursor)
            case None =>
                resizeVCursor = createCursor(SystemCursor.NsResize)
                resizeVCursor
        }
    }

    private func createCursor(kind: SystemCursor): ?Cursor {
        try {
            let cursor = Cursor.system(kind)
            resources.add(cursor)
            Some(cursor)
        } catch (_: Exception) {
            None
        }
    }

    private func nextFrame(previousTick: UInt64): FrameInfo {
        let currentTick = window.ticks()
        FrameInfo(currentTick, tickDelta(previousTick, currentTick))
    }

    private func preparePointer(event: UiEvent): Unit {
        match (event) {
            case UiEvent.MouseMove(x, y) => rememberMouse(x, y)
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                rememberMouse(x, y)
                ctx.leftMouseDown = true
            case UiEvent.MouseUp(MouseButton.Left, x, y) => rememberMouse(x, y)
            case UiEvent.DropFile(_, x, y) => rememberMouse(x, y)
            case UiEvent.DropText(_, x, y) => rememberMouse(x, y)
            case UiEvent.DropPosition(x, y) => rememberMouse(x, y)
            case _ => ()
        }
    }

    private func completePointer(event: UiEvent): Unit {
        match (event) {
            case UiEvent.MouseUp(MouseButton.Left, _, _) =>
                ctx.leftMouseDown = false
                ctx.clearDrag()
                ctx.clearPress()
            case _ => ()
        }
    }

    private func rememberMouse(x: Float32, y: Float32): Unit {
        ctx.mouseX = x
        ctx.mouseY = y
    }

    private func closeManagedResources(): Unit {
        closeResourcesInReverse(resources)
    }

    private func beginRun(): Unit {
        var accepted = false
        synchronized(lifecycleLock) {
            match (lifecycle) {
                case DesktopAppLifecycle.Ready =>
                    lifecycle = DesktopAppLifecycle.Running
                    accepted = true
                case _ => ()
            }
        }
        if (!accepted) {
            throw IllegalStateException("DesktopApp.run may only be called once")
        }
    }

    private func ensureUiAccess(operation: String): Unit {
        var stopped = false
        synchronized(lifecycleLock) {
            match (lifecycle) {
                case DesktopAppLifecycle.Stopped => stopped = true
                case _ => ()
            }
        }
        if (stopped) {
            throw IllegalStateException("DesktopApp cannot ${operation} after run has stopped")
        }
        scheduler.assertOwnerThread()
    }

    private func markStoppedAndDiscardPosts(): Unit {
        synchronized(lifecycleLock) {
            lifecycle = DesktopAppLifecycle.Stopped
        }
        var pending = postedActions.remove()
        while (pending.isSome()) {
            pending = postedActions.remove()
        }
    }
}

internal func closeResourcesInReverse(resources: ArrayList<Resource>): Unit {
    var firstFailure: ?Exception = None
    var i = resources.size - 1
    while (i >= 0) {
        try {
            if (!resources[i].isClosed()) {
                resources[i].close()
            }
        } catch (e: Exception) {
            match (firstFailure) {
                case None => firstFailure = Some(e)
                case Some(_) => ()
            }
        }
        i -= 1
    }
    resources.clear()
    match (firstFailure) {
        case Some(e) => throw e
        case None => ()
    }
}

internal func eventWaitTimeout(schedule: FrameSchedule, now: UInt64): Int32 {
    match (schedule.deadlineMs) {
        case Some(deadline) =>
            if (deadline <= now) {
                Int32(0)
            } else {
                Int32(min(deadline - now, UInt64(MAX_EVENT_WAIT_MS)))
            }
        case None => MAX_EVENT_WAIT_MS
    }
}

internal func frameProfileTimestamp(profiler: ?FrameProfiler): UInt64 {
    match (profiler) {
        case Some(_) => FrameProfiler.now()
        case None => UInt64(0)
    }
}

private func sameAnchorRect(applied: ?Rect, next: Rect): Bool {
    match (applied) {
        case Some(rect) => rect.x == next.x && rect.y == next.y && rect.w == next.w && rect.h == next.h
        case None => false
    }
}

internal func tickDelta(previousTick: UInt64, currentTick: UInt64): UInt64 {
    if (currentTick >= previousTick) {
        currentTick - previousTick
    } else {
        UInt64(0)
    }
}

private func snapshotArgument(): ?String {
    let args = getCommandLine()
    var i = 0
    while (i < args.size - 1) {
        if (args[i] == "--snapshot") {
            return Some(args[i + 1])
        }
        i += 1
    }
    None
}

// True when `--profile` is on the command line, turning on per-phase frame timing.
private func profileEnabled(): Bool {
    for (arg in getCommandLine()) {
        if (arg == "--profile") {
            return true
        }
    }
    false
}

// Debug/E2E switch: execute retained bodies and phases every frame for differential comparison.
private func fullRetainedExecutionEnabled(): Bool {
    for (arg in getCommandLine()) {
        if (arg == "--cui-force-full-retained") {
            return true
        }
    }
    false
}

// Diagnostic escape hatch for full-frame A/B checks without disabling other retained phases.
private func retainedDamageDisabled(): Bool {
    for (arg in getCommandLine()) {
        if (arg == "--cui-disable-retained-damage") {
            return true
        }
    }
    false
}

private func configuredWindow(spec: WindowSpec, metadata: ?AppMetadata, hints: Array<SdlHintSetting>): SdlWindow {
    match (metadata) {
        case Some(value) => ApplicationMetadata.apply(value)
        case None => ()
    }
    SdlHints.apply(hints)
    SdlWindow(spec)
}
