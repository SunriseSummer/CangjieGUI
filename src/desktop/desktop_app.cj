/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.desktop

import std.collection.ArrayList
import std.env.getCommandLine
import sdl.{FrameInfo, MouseButton, Rect, SdlWindow, UiEvent, WindowSpec}
import sdl.dialogs.FileDialogOptions
import sdl.dialogs.FileDialogRequest
import sdl.dialogs.FileDialogs
import sdl.system.AppMetadata
import sdl.system.ApplicationMetadata
import sdl.system.SdlHintSetting
import sdl.system.SdlHints
import cui.core.{Theme, UiContext, Widget, buildChild}

// Long enough for the first paint to settle and for background work started at launch
// (dialog-free examples fetch data on worker threads) to land in the frame.
private let SNAPSHOT_SETTLE_FRAMES: UInt64 = 48

public class DesktopApp {
    private let window: SdlWindow
    private let ctx: UiContext
    private let frameDelay: UInt32
    private let resources = ArrayList<Resource>()
    private let snapshotPath: ?String
    private var frames: UInt64 = 0

    public init(
        spec: WindowSpec,
        theme!: Theme = Theme.light(),
        frameDelay!: UInt32 = UInt32(16),
        metadata!: ?AppMetadata = None,
        hints!: Array<SdlHintSetting> = []
    ) {
        this.window = configuredWindow(spec, metadata, hints)
        this.ctx = UiContext(window.renderer, theme)
        this.frameDelay = frameDelay
        this.snapshotPath = snapshotArgument()
    }

    public func manage(resource: Resource): Unit {
        resources.add(resource)
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
        var previousTick = window.ticks()
        while (!ctx.shouldClose) {
            let frame = nextFrame(previousTick)
            previousTick = frame.elapsedMs
            ctx.frame = frame
            let widget = buildChild(body)
            widget.layout(ctx, Rect(0.0, 0.0, Float32(window.width), Float32(window.height)))
            drainEvents(widget)
            dispatchEvent(widget, UiEvent.Frame(frame))
            frames += 1
            draw(widget)
            window.delay(frameDelay)
        }
        closeManagedResources()
        window.close()
    }

    private func drainEvents(widget: Widget): Unit {
        var current = window.pollEvent()
        while (let Some(event) <- current) {
            preparePointer(event)
            match (event) {
                case UiEvent.Quit => ctx.requestClose()
                case UiEvent.WindowResized(w, h) =>
                    window.width = Int32(Float32(w) / window.scale)
                    window.height = Int32(Float32(h) / window.scale)
                case _ => dispatchEvent(widget, event)
            }
            completePointer(event)
            current = window.pollEvent()
        }
    }

    private func draw(widget: Widget): Unit {
        ctx.renderer.beginScene(Float32(window.width), Float32(window.height), ctx.theme.bg)
        widget.draw(ctx)
        ctx.renderer.endScene()
        maybeSnapshot()
        ctx.renderer.present()
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

private func configuredWindow(spec: WindowSpec, metadata: ?AppMetadata, hints: Array<SdlHintSetting>): SdlWindow {
    match (metadata) {
        case Some(value) => ApplicationMetadata.apply(value)
        case None => ()
    }
    SdlHints.apply(hints)
    SdlWindow(spec)
}
