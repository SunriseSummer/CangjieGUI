package cui.desktop

import std.collection.ArrayList
import std.env.getCommandLine
import sdl.{FrameInfo, Key, MouseButton, Rect, SdlWindow, UiEvent, WindowSpec}
import sdl.input.{Cursor, Keyboard, SystemCursor}
import sdl.dialogs.FileDialogOptions
import sdl.dialogs.FileDialogRequest
import sdl.dialogs.FileDialogs
import sdl.system.AppMetadata
import sdl.system.ApplicationMetadata
import sdl.system.SdlHintSetting
import sdl.system.SdlHints
import cui.core.{CursorShape, StateStore, Theme, UiContext, Widget, buildRoot, drawTooltip}

// Long enough for the first paint to settle and for background work started at launch
// (dialog-free examples fetch data on worker threads) to land in the frame.
private let SNAPSHOT_SETTLE_FRAMES: UInt64 = 48

public class DesktopApp {
    private let window: SdlWindow
    private let ctx: UiContext
    private let frameDelay: UInt32
    private let resources = ArrayList<Resource>()
    private let stateStore = StateStore()
    private let snapshotPath: ?String
    // Per-phase frame timing, enabled with `--profile`; None (and zero cost) in a normal run.
    private let profiler: ?FrameProfiler
    private var frames: UInt64 = 0
    private var baseCursor: ?Cursor = None
    private var pointerCursor: ?Cursor = None
    private var textCursor: ?Cursor = None
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
        this.ctx.displayScale = window.scale
        this.ctx.fontScale = max(0.1, fontScale)
        this.frameDelay = frameDelay
        this.snapshotPath = snapshotArgument()
        this.profiler = if (profileEnabled()) {
            Some(FrameProfiler(60))
        } else {
            None
        }
    }

    public func manage(resource: Resource): Unit {
        resources.add(resource)
    }

    /**
     * Prevents the user from shrinking the window below `width` x `height` logical
     * pixels. Layouts do not reflow below their design minimum, so resizable windows
     * should set one to keep content from being squeezed off screen.
     */
    public func setMinimumSize(width: Int32, height: Int32): Unit {
        window.setMinimumSize(width, height)
    }

    /**
     * Sets the window's resting cursor — the shape shown wherever no control asks for a
     * different one. Applications wanting a themed base pointer (for example a crosshair
     * over a drawing canvas) call this instead of activating a cursor directly, so the
     * hover-driven shapes (a hand over buttons, an I-beam over text) still layer on top.
     */
    public func useBaseCursor(kind: SystemCursor): Unit {
        match (baseCursor) {
            case Some(existing) => existing.close()
            case None => ()
        }
        baseCursor = createCursor(kind)
        appliedShape = None
        applyDesiredCursor()
    }

    /** Drops all local values created by `rememberState` before the next rebuild. */
    public func clearRememberedState(): Unit {
        stateStore.clear()
    }

    public func openFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        FileDialogs.openFile(options: options, window: Some(window))
    }

    public func saveFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        FileDialogs.saveFile(options: options, window: Some(window))
    }

    public func openFolderDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        FileDialogs.openFolder(options: options, window: Some(window))
    }

    public func run(body: () -> Unit): Unit {
        // The finally block keeps shutdown deterministic even when a widget throws out of
        // the frame loop: managed resources close in reverse order, then the window.
        try {
            match (profiler) {
                case Some(_) =>
                    println("[profile] 渲染后端 ${ctx.renderer.driverName()}｜超采样 ${ctx.renderer.supersampleFactor()}x｜视口 ${window.width}x${window.height} @ ${window.scale}x")
                case None => ()
            }
            var previousTick = window.ticks()
            while (!ctx.shouldClose) {
                let frame = nextFrame(previousTick)
                previousTick = frame.elapsedMs
                ctx.frame = frame
                ctx.viewportWidth = Float32(window.width)
                ctx.viewportHeight = Float32(window.height)
                let tBuild = FrameProfiler.now()
                let widget = buildRoot(body, stateStore)
                let tLayout = FrameProfiler.now()
                ctx.adoptFocusRing(stateStore.focusRing())
                widget.layout(ctx, Rect(0.0, 0.0, Float32(window.width), Float32(window.height)))
                let tEvents = FrameProfiler.now()
                drainEvents(widget)
                dispatchEvent(widget, UiEvent.Frame(frame))
                let tDraw = FrameProfiler.now()
                frames += 1
                let (beginNs, treeNs, resolveNs, presentNs) = draw(widget)
                window.delay(frameDelay)
                match (profiler) {
                    case Some(p) => p.record(tLayout - tBuild, tEvents - tLayout, tDraw - tEvents, beginNs, treeNs,
                        resolveNs, presentNs)
                    case None => ()
                }
            }
        } finally {
            closeManagedResources()
            window.close()
        }
    }

    private func drainEvents(widget: Widget): Unit {
        var current = window.pollEvent()
        while (let Some(event) <- current) {
            preparePointer(event)
            routeEvent(widget, event)
            completePointer(event)
            current = window.pollEvent()
        }
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
        match (event) {
            case UiEvent.Quit => ctx.requestClose()
            case UiEvent.WindowResized(w, h) =>
                window.width = Int32(Float32(w) / window.scale)
                window.height = Int32(Float32(h) / window.scale)
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
                if (Keyboard.modifiers().shift) {
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

    // Draws one frame, returning the nanosecond durations of its sub-phases (scene begin, tree draw,
    // supersample resolve, present) for the profiler. The timestamps are a handful of clock reads —
    // negligible against a frame — so they run unconditionally and only the profiler, when enabled,
    // records them.
    private func draw(widget: Widget): (UInt64, UInt64, UInt64, UInt64) {
        let t0 = FrameProfiler.now()
        ctx.renderer.beginScene(Float32(window.width), Float32(window.height), ctx.theme.bg)
        let t1 = FrameProfiler.now()
        // Cleared before the tree so only a control hovered this frame shows a tooltip; the
        // tree registers into the slot during draw, and the overlay is painted last, on top.
        ctx.clearTooltip()
        // Cleared before the tree so a closed popup leaves no overlay; each open control
        // re-registers during draw, and the stack is painted last, above the tree —
        // bottom-up, so a popup opened inside a dialog paints above the dialog.
        ctx.clearActiveOverlay()
        // Cleared before the tree so only this frame's focused caret (re-reported during
        // draw, including inside dialog overlays) anchors the IME candidate window.
        ctx.clearTextInputAnchor()
        widget.draw(ctx)
        // Tooltips yield to an open popup or dialog — standard desktop behaviour, and it
        // stops a background control's bubble from ghosting through the modal backdrop.
        if (!ctx.hasOverlay()) {
            drawTooltip(ctx, Float32(window.width), Float32(window.height))
        }
        ctx.drawActiveOverlay()
        applyTextInputAnchor()
        let t2 = FrameProfiler.now()
        ctx.renderer.endScene()
        let t3 = FrameProfiler.now()
        maybeSnapshot()
        ctx.renderer.present()
        let t4 = FrameProfiler.now()
        (t1 - t0, t2 - t1, t3 - t2, t4 - t3)
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
                    } catch (_: Exception) {
                        ()
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

    private func dispatchEvent(widget: Widget, event: UiEvent): Unit {
        let _ = widget.handle(ctx, event)
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
            } catch (_: Exception) {
                ()
            }
            case None => ()
        }
    }

    private func cursorForShape(shape: CursorShape): ?Cursor {
        match (shape) {
            case CursorShape.Default => ensureCursor(SystemCursor.Default)
            case CursorShape.Interactive => ensurePointerCursor()
            case CursorShape.Text => ensureTextCursor()
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
        var i = resources.size - 1
        while (i >= 0) {
            resources[i].close()
            i -= 1
        }
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

private func configuredWindow(spec: WindowSpec, metadata: ?AppMetadata, hints: Array<SdlHintSetting>): SdlWindow {
    match (metadata) {
        case Some(value) => ApplicationMetadata.apply(value)
        case None => ()
    }
    SdlHints.apply(hints)
    SdlWindow(spec)
}
