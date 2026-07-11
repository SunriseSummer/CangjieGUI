/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

public enum TextureBlendMode {
    | None
    | Blend
    | Add
    | Mod
    | Mul
}

public enum TextureFlip {
    | None
    | Horizontal
    | Vertical
    | Both
}

public struct TextureRenderOptions {
    public let source: ?Rect
    public let center: ?Point
    public let flip: TextureFlip

    public init(source!: ?Rect = None, center!: ?Point = None, flip!: TextureFlip = TextureFlip.None) {
        this.source = source
        this.center = center
        this.flip = flip
    }
}

public class Texture <: Resource {
    internal let ptr: CPointer<Unit>
    private var closed = false

    public let width: Float32
    public let height: Float32

    internal init(ptr: CPointer<Unit>) {
        this.ptr = ptr
        var w: Float32 = 0.0
        var h: Float32 = 0.0
        ensureSdl(unsafe { SDL_GetTextureSize(ptr, inout w, inout h) }, "SDL_GetTextureSize")
        this.width = w
        this.height = h
    }

    public func size(): Size {
        Size(width, height)
    }

    public func setColorMod(color: Color): Unit {
        ensureOpen()
        ensureSdl(unsafe { SDL_SetTextureColorMod(ptr, color.r, color.g, color.b) }, "SDL_SetTextureColorMod")
    }

    public func setAlpha(alpha: Int64): Unit {
        ensureOpen()
        ensureSdl(unsafe { SDL_SetTextureAlphaMod(ptr, toChannel(alpha)) }, "SDL_SetTextureAlphaMod")
    }

    public func setBlendMode(mode: TextureBlendMode): Unit {
        ensureOpen()
        ensureSdl(unsafe { SDL_SetTextureBlendMode(ptr, blendModeCode(mode)) }, "SDL_SetTextureBlendMode")
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
                SDL_DestroyTexture(ptr)
            }
        }
    }

    /**
     * Throws `CuiException` when a closed texture is reused.
     */
    private func ensureOpen(): Unit {
        if (closed) {
            throw CuiException("Texture is already closed.")
        }
    }
}

extend Renderer {
    /**
     * Throws `CuiException` when the source surface is closed or SDL cannot create a texture.
     */
    public func textureFromSurface(surface: Surface): Texture {
        if (surface.isClosed()) {
            throw CuiException("Cannot create texture from a closed surface.")
        }
        let texture = unsafe { SDL_CreateTextureFromSurface(ptr, surface.ptr) }
        if (texture.isNull()) {
            throw CuiException("SDL_CreateTextureFromSurface failed: ${lastSdlError()}")
        }
        Texture(texture)
    }

    /**
     * Throws `CuiException` when SDL cannot load the image or create a texture from it.
     */
    public func loadTexture(path: String): Texture {
        var texture = CPointer<Unit>()
        try (surface = Surface.load(path)) {
            texture = unsafe { SDL_CreateTextureFromSurface(ptr, surface.ptr) }
        }
        if (texture.isNull()) {
            throw CuiException("SDL_CreateTextureFromSurface failed: ${lastSdlError()}")
        }
        Texture(texture)
    }

    /**
     * Throws `CuiException` when the texture is closed or SDL cannot render it.
     */
    public func texture(texture: Texture, destination: Rect, source!: ?Rect = None): Unit {
        if (texture.isClosed()) {
            throw CuiException("Cannot render a closed texture.")
        }
        var dst = destination.toSdlFRect()
        match (source) {
            case Some(rect) =>
                var src = rect.toSdlFRect()
                ensureSdl(unsafe { SDL_RenderTexture(ptr, texture.ptr, inout src, inout dst) }, "SDL_RenderTexture")
            case None => ensureSdl(unsafe { SDL_RenderTexture(ptr, texture.ptr, CPointer<SdlFRect>(), inout dst) },
                "SDL_RenderTexture")
        }
    }

    /**
     * Throws `CuiException` when the texture is closed or SDL cannot render it.
     */
    public func textureRotated(
        texture: Texture,
        destination: Rect,
        angle: Float64,
        options!: TextureRenderOptions = TextureRenderOptions()
    ): Unit {
        if (texture.isClosed()) {
            throw CuiException("Cannot render a closed texture.")
        }
        var dst = destination.toSdlFRect()
        match ((options.source, options.center)) {
            case (Some(srcRect), Some(centerPoint)) =>
                var src = srcRect.toSdlFRect()
                var pivot = centerPoint.toSdlFPoint()
                ensureSdl(unsafe {
                    SDL_RenderTextureRotated(ptr, texture.ptr, inout src, inout dst, angle, inout pivot,
                        flipCode(options.flip))
                }, "SDL_RenderTextureRotated")
            case (Some(srcRect), None) =>
                var src = srcRect.toSdlFRect()
                ensureSdl(unsafe {
                    SDL_RenderTextureRotated(ptr, texture.ptr, inout src, inout dst, angle, CPointer<SdlFPoint>(),
                        flipCode(options.flip))
                }, "SDL_RenderTextureRotated")
            case (None, Some(centerPoint)) =>
                var pivot = centerPoint.toSdlFPoint()
                ensureSdl(unsafe {
                    SDL_RenderTextureRotated(ptr, texture.ptr, CPointer<SdlFRect>(), inout dst, angle, inout pivot,
                        flipCode(options.flip))
                }, "SDL_RenderTextureRotated")
            case (None, None) => ensureSdl(unsafe {
                SDL_RenderTextureRotated(
                    ptr,
                    texture.ptr,
                    CPointer<SdlFRect>(),
                    inout dst,
                    angle,
                    CPointer<SdlFPoint>(),
                    flipCode(options.flip)
                )
            }, "SDL_RenderTextureRotated")
        }
    }
}

private func blendModeCode(mode: TextureBlendMode): UInt32 {
    match (mode) {
        case TextureBlendMode.None => UInt32(0)
        case TextureBlendMode.Blend => UInt32(1)
        case TextureBlendMode.Add => UInt32(2)
        case TextureBlendMode.Mod => UInt32(4)
        case TextureBlendMode.Mul => UInt32(8)
    }
}

private func flipCode(flip: TextureFlip): Int32 {
    match (flip) {
        case TextureFlip.None => 0
        case TextureFlip.Horizontal => 1
        case TextureFlip.Vertical => 2
        case TextureFlip.Both => 3
    }
}

private func toChannel(value: Int64): UInt8 {
    if (value < 0) {
        UInt8(0)
    } else if (value > 255) {
        UInt8(255)
    } else {
        UInt8(value)
    }
}
