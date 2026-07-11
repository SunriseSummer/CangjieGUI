/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

public struct WindowSpec {
    public let title: String
    public let width: Int32
    public let height: Int32
    public let resizable: Bool
    public let highDpi: Bool
    public let scale: Float32

    public init(
        title: String,
        width: Int32,
        height: Int32,
        resizable!: Bool = true,
        highDpi!: Bool = true,
        scale!: Float32 = 1.0
    ) {
        this.title = title
        this.width = width
        this.height = height
        this.resizable = resizable
        this.highDpi = highDpi
        this.scale = normalizedScale(scale)
    }
}

public class SdlWindow <: Resource {
    internal let windowPtr: CPointer<Unit>
    private let rendererPtr: CPointer<Unit>
    private var closed = false

    public var width: Int32
    public var height: Int32
    public let scale: Float32
    public let renderer: Renderer

    /**
     * Throws `CuiException` when SDL cannot create or initialize the window, renderer, or text input.
     */
    public init(spec: WindowSpec) {
        this.width = spec.width
        this.height = spec.height
        this.scale = spec.scale

        if (!unsafe { SDL_Init(SDL_INIT_VIDEO) }) {
            throw CuiException("SDL_Init failed: ${lastSdlError()}")
        }

        var flags = UInt64(0)
        if (spec.resizable) {
            flags = flags | SDL_WINDOW_RESIZABLE
        }
        if (spec.highDpi) {
            flags = flags | SDL_WINDOW_HIGH_PIXEL_DENSITY
        }

        var window = CPointer<Unit>()
        var createdRenderer = CPointer<Unit>()
        let titleText = unsafe { LibC.mallocCString(spec.title) }
        try (titleResource = titleText.asResource()) {
            let pixelWidth = scaledDimension(spec.width, spec.scale)
            let pixelHeight = scaledDimension(spec.height, spec.scale)
            let ok = unsafe {
                SDL_CreateWindowAndRenderer(titleResource.value, pixelWidth, pixelHeight, flags, inout window,
                    inout createdRenderer)
            }
            if (!ok || window.isNull() || createdRenderer.isNull()) {
                destroyCreatedResources(window, createdRenderer)
                throw CuiException("SDL_CreateWindowAndRenderer failed: ${lastSdlError()}")
            }
            configureRenderer(window, createdRenderer, spec.scale)
            if (!unsafe { SDL_StartTextInput(window) }) {
                destroyCreatedResources(window, createdRenderer)
                throw CuiException("SDL_StartTextInput failed: ${lastSdlError()}")
            }
        }

        this.windowPtr = window
        this.rendererPtr = createdRenderer
        this.renderer = Renderer(createdRenderer, contentScale: spec.scale)
    }

    public func setTitle(title: String): Unit {
        let cTitle = unsafe { LibC.mallocCString(title) }
        try (titleResource = cTitle.asResource()) {
            ensureSdl(unsafe { SDL_SetWindowTitle(windowPtr, titleResource.value) }, "SDL_SetWindowTitle")
        }
    }

    public func setSize(width: Int32, height: Int32): Unit {
        let pixelWidth = scaledDimension(width, scale)
        let pixelHeight = scaledDimension(height, scale)
        ensureSdl(unsafe { SDL_SetWindowSize(windowPtr, pixelWidth, pixelHeight) }, "SDL_SetWindowSize")
        this.width = width
        this.height = height
    }

    public func refreshSize(): Size {
        var w: Int32 = 0
        var h: Int32 = 0
        ensureSdl(unsafe { SDL_GetWindowSize(windowPtr, inout w, inout h) }, "SDL_GetWindowSize")
        width = Int32(Float32(w) / scale)
        height = Int32(Float32(h) / scale)
        Size(Float32(width), Float32(height))
    }

    public func setTextInputArea(rect: Rect): Unit {
        var raw = rect.toSdlRect()
        ensureSdl(unsafe { SDL_SetTextInputArea(windowPtr, inout raw, 0) }, "SDL_SetTextInputArea")
    }

    public func pollEvent(): ?UiEvent {
        var raw = SdlEvent()
        if (!unsafe { SDL_PollEvent(inout raw) }) {
            return None
        }
        return Some(scaleEventCoordinates(decodeEvent(raw), scale))
    }

    public func ticks(): UInt64 {
        unsafe { SDL_GetTicks() }
    }

    public func delay(ms: UInt32): Unit {
        unsafe { SDL_Delay(ms) }
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        renderer.releaseResources()
        unsafe {
            if (windowPtr.isNotNull()) {
                let _ = SDL_StopTextInput(windowPtr)
            }
            if (rendererPtr.isNotNull()) {
                SDL_DestroyRenderer(rendererPtr)
            }
            if (windowPtr.isNotNull()) {
                SDL_DestroyWindow(windowPtr)
            }
            SDL_Quit()
        }
    }
}
