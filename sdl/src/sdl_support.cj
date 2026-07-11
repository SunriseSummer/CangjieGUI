/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

/**
 * Throws `CuiException` when an SDL boolean result reports failure.
 */
internal func ensureSdl(ok: Bool, api: String): Unit {
    if (!ok) {
        throw CuiException("${api} failed: ${lastSdlError()}")
    }
}

public func sdlVersion(): Int32 {
    unsafe { SDL_GetVersion() }
}

public func sdlRevision(): String {
    let revision = unsafe { SDL_GetRevision() }
    if (revision.isNull()) {
        ""
    } else {
        revision.toString()
    }
}

internal func lastSdlError(): String {
    unsafe {
        let err = SDL_GetError()
        if (err.isNull()) {
            return "unknown SDL error"
        }
        return err.toString()
    }
}

/**
 * Throws `CuiException` when renderer defaults cannot be applied after window creation.
 */
internal func configureRenderer(window: CPointer<Unit>, renderer: CPointer<Unit>, scale: Float32): Unit {
    if (!unsafe { SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND) }) {
        destroyCreatedResources(window, renderer)
        throw CuiException("SDL_SetRenderDrawBlendMode failed: ${lastSdlError()}")
    }
    if (!unsafe { SDL_SetRenderScale(renderer, scale, scale) }) {
        destroyCreatedResources(window, renderer)
        throw CuiException("SDL_SetRenderScale failed: ${lastSdlError()}")
    }
    let _ = unsafe { SDL_SetRenderVSync(renderer, 1) }
}

/**
 * Releases partially-created SDL resources before propagating a setup failure.
 */
internal func destroyCreatedResources(window: CPointer<Unit>, renderer: CPointer<Unit>): Unit {
    unsafe {
        if (renderer.isNotNull()) {
            SDL_DestroyRenderer(renderer)
        }
        if (window.isNotNull()) {
            SDL_DestroyWindow(window)
        }
        SDL_Quit()
    }
}

internal func normalizedScale(scale: Float32): Float32 {
    if (scale <= 0.0) {
        1.0
    } else {
        scale
    }
}

internal func scaledDimension(value: Int32, scale: Float32): Int32 {
    Int32(Float32(value) * scale)
}
