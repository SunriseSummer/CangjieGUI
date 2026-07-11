/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

public class Surface <: Resource {
    internal let ptr: CPointer<Unit>
    private var closed = false

    internal init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    /**
     * Throws `CuiException` when SDL cannot allocate an RGBA surface.
     */
    public static func create(width: Int32, height: Int32): Surface {
        let surface = unsafe { SDL_CreateSurface(width, height, SDL_PIXELFORMAT_RGBA32) }
        if (surface.isNull()) {
            throw CuiException("SDL_CreateSurface failed: ${lastSdlError()}")
        }
        Surface(surface)
    }

    public static func load(path: String): Surface {
        match (imageFormatFromPath(path)) {
            case ImageFileFormat.Png => return loadPng(path)
            case ImageFileFormat.Bmp => return loadBmp(path)
        }
    }

    public static func loadBmp(path: String): Surface {
        loadWith(path, ImageFileFormat.Bmp)
    }

    public static func loadPng(path: String): Surface {
        loadWith(path, ImageFileFormat.Png)
    }

    public func clear(color: Color): Unit {
        ensureOpen()
        ensureSdl(unsafe {
            SDL_ClearSurface(
                ptr,
                Float32(color.r) / 255.0,
                Float32(color.g) / 255.0,
                Float32(color.b) / 255.0,
                Float32(color.a) / 255.0
            )
        }, "SDL_ClearSurface")
    }

    public func writePixel(x: Int32, y: Int32, color: Color): Unit {
        ensureOpen()
        ensureSdl(unsafe { SDL_WriteSurfacePixel(ptr, x, y, color.r, color.g, color.b, color.a) },
            "SDL_WriteSurfacePixel")
    }

    public func saveBmp(path: String): Unit {
        ensureOpen()
        let cPath = unsafe { LibC.mallocCString(path) }
        try (pathResource = cPath.asResource()) {
            ensureSdl(unsafe { SDL_SaveBMP(ptr, pathResource.value) }, "SDL_SaveBMP")
        }
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        unsafe {
            if (ptr.isNotNull()) {
                SDL_DestroySurface(ptr)
            }
        }
    }

    /**
     * Throws `CuiException` when a closed surface is reused.
     */
    private func ensureOpen(): Unit {
        if (closed) {
            throw CuiException("Surface is already closed.")
        }
    }
}

public enum ImageFileFormat {
    | Bmp
    | Png
}

public func imageFormatFromPath(path: String): ImageFileFormat {
    if (path.endsWith(".png") || path.endsWith(".PNG")) {
        ImageFileFormat.Png
    } else {
        ImageFileFormat.Bmp
    }
}

/**
 * Throws `CuiException` when SDL cannot load the requested image file.
 */
private func loadWith(path: String, format: ImageFileFormat): Surface {
    let cPath = unsafe { LibC.mallocCString(path) }
    var surface = CPointer<Unit>()
    try (pathResource = cPath.asResource()) {
        surface = match (format) {
            case ImageFileFormat.Png => unsafe { SDL_LoadPNG(pathResource.value) }
            case ImageFileFormat.Bmp => unsafe { SDL_LoadBMP(pathResource.value) }
        }
    }
    if (surface.isNull()) {
        throw CuiException("Image load failed for '${path}': ${lastSdlError()}")
    }
    Surface(surface)
}
