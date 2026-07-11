/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.displays

import sdl.{CuiException, ensureSdl, lastSdlError, Rect, SDL_INIT_VIDEO, SDL_ORIENTATION_LANDSCAPE, 
    SDL_ORIENTATION_LANDSCAPE_FLIPPED, SDL_ORIENTATION_PORTRAIT, SDL_ORIENTATION_PORTRAIT_FLIPPED, 
    SDL_ORIENTATION_UNKNOWN, SdlDisplayMode, SdlRect}

public enum DisplayOrientation {
    | Unknown
    | Landscape
    | LandscapeFlipped
    | Portrait
    | PortraitFlipped
}

public struct DisplayMode {
    public let width: Int32
    public let height: Int32
    public let pixelDensity: Float32
    public let refreshRate: Float32

    public init(width: Int32, height: Int32, pixelDensity: Float32, refreshRate: Float32) {
        this.width = width
        this.height = height
        this.pixelDensity = pixelDensity
        this.refreshRate = refreshRate
    }
}

public struct DisplayGeometry {
    public let bounds: Rect
    public let usableBounds: Rect
    public let contentScale: Float32

    public init(bounds: Rect, usableBounds: Rect, contentScale: Float32) {
        this.bounds = bounds
        this.usableBounds = usableBounds
        this.contentScale = contentScale
    }
}

public struct DisplayOrientations {
    public let natural: DisplayOrientation
    public let current: DisplayOrientation

    public init(natural: DisplayOrientation, current: DisplayOrientation) {
        this.natural = natural
        this.current = current
    }
}

public struct DisplayModes {
    public let desktop: ?DisplayMode
    public let current: ?DisplayMode

    public init(desktop: ?DisplayMode, current: ?DisplayMode) {
        this.desktop = desktop
        this.current = current
    }
}

public struct DisplayInfo {
    public let id: UInt32
    public let name: String
    public let geometry: DisplayGeometry
    public let orientations: DisplayOrientations
    public let modes: DisplayModes

    public init(
        id: UInt32,
        name: String,
        geometry: DisplayGeometry,
        orientations: DisplayOrientations,
        modes: DisplayModes
    ) {
        this.id = id
        this.name = name
        this.geometry = geometry
        this.orientations = orientations
        this.modes = modes
    }
}

/**
 * Throws `CuiException` when SDL cannot initialize video or query the primary display.
 */
public func primaryDisplayInfo(): DisplayInfo {
    ensureVideo()
    let id = unsafe { SDL_GetPrimaryDisplay() }
    if (id == UInt32(0)) {
        throw CuiException("SDL_GetPrimaryDisplay failed: ${lastSdlError()}")
    }
    displayInfo(id)
}

/**
 * Throws `CuiException` when SDL cannot query the requested display.
 */
public func displayInfo(id: UInt32): DisplayInfo {
    ensureDisplayId(id)
    let name = displayName(id)
    let geometry = DisplayGeometry(displayBounds(id), displayUsableBounds(id), displayContentScale(id))
    let orientations = DisplayOrientations(
        displayOrientationFromCode(unsafe { SDL_GetNaturalDisplayOrientation(id) }),
        displayOrientationFromCode(unsafe { SDL_GetCurrentDisplayOrientation(id) })
    )
    let modes = DisplayModes(
        displayModeFromPointer(unsafe { SDL_GetDesktopDisplayMode(id) }),
        displayModeFromPointer(unsafe { SDL_GetCurrentDisplayMode(id) })
    )
    DisplayInfo(id, name, geometry, orientations, modes)
}

internal func displayOrientationFromCode(code: Int32): DisplayOrientation {
    if (code == SDL_ORIENTATION_UNKNOWN) {
        DisplayOrientation.Unknown
    } else if (code == SDL_ORIENTATION_LANDSCAPE) {
        DisplayOrientation.Landscape
    } else if (code == SDL_ORIENTATION_LANDSCAPE_FLIPPED) {
        DisplayOrientation.LandscapeFlipped
    } else if (code == SDL_ORIENTATION_PORTRAIT) {
        DisplayOrientation.Portrait
    } else if (code == SDL_ORIENTATION_PORTRAIT_FLIPPED) {
        DisplayOrientation.PortraitFlipped
    } else {
        DisplayOrientation.Unknown
    }
}

internal func displayModeFromRaw(raw: SdlDisplayMode): DisplayMode {
    DisplayMode(raw.w, raw.h, normalizedDisplayScale(raw.pixelDensity), raw.refreshRate)
}

private func ensureVideo(): Unit {
    ensureSdl(unsafe { SDL_Init(SDL_INIT_VIDEO) }, "SDL_Init")
}

/**
 * Throws `CuiException` when SDL cannot resolve the display name.
 */
private func displayName(id: UInt32): String {
    let name = unsafe { SDL_GetDisplayName(id) }
    if (name.isNull()) {
        throw CuiException("SDL_GetDisplayName failed: ${lastSdlError()}")
    }
    name.toString()
}

private func displayBounds(id: UInt32): Rect {
    var raw = SdlRect()
    ensureSdl(unsafe { SDL_GetDisplayBounds(id, inout raw) }, "SDL_GetDisplayBounds")
    rectFromRaw(raw)
}

private func displayUsableBounds(id: UInt32): Rect {
    var raw = SdlRect()
    ensureSdl(unsafe { SDL_GetDisplayUsableBounds(id, inout raw) }, "SDL_GetDisplayUsableBounds")
    rectFromRaw(raw)
}

/**
 * Throws `CuiException` when SDL cannot resolve the display scale.
 */
private func displayContentScale(id: UInt32): Float32 {
    let scale = unsafe { SDL_GetDisplayContentScale(id) }
    if (scale <= 0.0) {
        throw CuiException("SDL_GetDisplayContentScale failed: ${lastSdlError()}")
    }
    scale
}

internal func displayModeFromPointer(mode: CPointer<SdlDisplayMode>): ?DisplayMode {
    if (mode.isNull()) {
        return None
    }
    Some(displayModeFromRaw(unsafe { mode.read() }))
}

private func rectFromRaw(raw: SdlRect): Rect {
    Rect(Float32(raw.x), Float32(raw.y), Float32(raw.w), Float32(raw.h))
}

private func normalizedDisplayScale(scale: Float32): Float32 {
    if (scale <= 0.0) {
        1.0
    } else {
        scale
    }
}
