/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.displays

import std.collection.ArrayList
import sdl.{CuiException, ensureSdl, lastSdlError, Point, Rect, SDL_INIT_VIDEO, SdlDisplayMode}

public struct FullscreenModeRequest {
    public let width: Int32
    public let height: Int32
    public let refreshRate: Float32
    public let includeHighDensityModes: Bool

    public init(
        width: Int32,
        height: Int32,
        refreshRate!: Float32 = 0.0,
        includeHighDensityModes!: Bool = true
    ) {
        this.width = width
        this.height = height
        this.refreshRate = refreshRate
        this.includeHighDensityModes = includeHighDensityModes
    }
}

/**
 * Throws `CuiException` when SDL cannot enumerate displays.
 */
public func displayIds(): Array<UInt32> {
    ensureDisplayVideoReady()
    var count: Int32 = 0
    let ids = unsafe { SDL_GetDisplays(inout count) }
    if (ids.isNull()) {
        throw CuiException("SDL_GetDisplays failed: ${lastSdlError()}")
    }

    try {
        displayIdsFromPointer(ids, count)
    } finally {
        unsafe { SDL_free(CPointer<UInt8>(ids)) }
    }
}

/**
 * Throws `CuiException` when SDL cannot query one of the connected displays.
 */
public func allDisplayInfos(): Array<DisplayInfo> {
    let ids = displayIds()
    let displays = ArrayList<DisplayInfo>()
    for (id in ids) {
        displays.add(displayInfo(id))
    }
    displays.toArray()
}

/**
 * Throws `CuiException` when SDL cannot enumerate fullscreen modes for the display.
 */
public func fullscreenDisplayModes(id: UInt32): Array<DisplayMode> {
    ensureDisplayId(id)
    var count: Int32 = 0
    let modes = unsafe { SDL_GetFullscreenDisplayModes(id, inout count) }
    if (modes.isNull()) {
        throw CuiException("SDL_GetFullscreenDisplayModes failed: ${lastSdlError()}")
    }

    try {
        displayModesFromPointers(modes, count)
    } finally {
        unsafe { SDL_free(CPointer<UInt8>(modes)) }
    }
}

/**
 * Throws `CuiException` when SDL cannot scan fullscreen modes for the display.
 */
public func closestFullscreenDisplayMode(id: UInt32, request: FullscreenModeRequest): ?DisplayMode {
    ensureDisplayId(id)
    var raw = SdlDisplayMode()
    let found = unsafe {
        SDL_GetClosestFullscreenDisplayMode(id, request.width, request.height, request.refreshRate,
            request.includeHighDensityModes, inout raw)
    }
    if (!found) {
        return None
    }
    Some(displayModeFromRaw(raw))
}

/**
 * Throws `CuiException` when SDL cannot identify or query the display containing the point.
 */
public func displayInfoForPoint(point: Point): DisplayInfo {
    var raw = point.toSdlPoint()
    let id = unsafe { SDL_GetDisplayForPoint(inout raw) }
    if (id == UInt32(0)) {
        throw CuiException("SDL_GetDisplayForPoint failed: ${lastSdlError()}")
    }
    displayInfo(id)
}

/**
 * Throws `CuiException` when SDL cannot identify or query the display containing the rectangle.
 */
public func displayInfoForRect(rect: Rect): DisplayInfo {
    var raw = rect.toSdlRect()
    let id = unsafe { SDL_GetDisplayForRect(inout raw) }
    if (id == UInt32(0)) {
        throw CuiException("SDL_GetDisplayForRect failed: ${lastSdlError()}")
    }
    displayInfo(id)
}

internal func displayIdsFromPointer(ids: CPointer<UInt32>, count: Int32): Array<UInt32> {
    let results = ArrayList<UInt32>()
    for (i in 0..Int64(count)) {
        results.add(unsafe { ids.read(i) })
    }
    results.toArray()
}

internal func displayModesFromPointers(
    modes: CPointer<CPointer<SdlDisplayMode>>,
    count: Int32
): Array<DisplayMode> {
    let results = ArrayList<DisplayMode>()
    for (i in 0..Int64(count)) {
        let mode = unsafe { modes.read(i) }
        match (displayModeFromPointer(mode)) {
            case Some(value) => results.add(value)
            case None => ()
        }
    }
    results.toArray()
}

/**
 * Throws `CuiException` when display id is zero.
 */
internal func ensureDisplayId(id: UInt32): Unit {
    if (id == UInt32(0)) {
        throw CuiException("Display id must not be zero.")
    }
}

/**
 * Throws `CuiException` when SDL cannot initialize video support.
 */
private func ensureDisplayVideoReady(): Unit {
    ensureSdl(unsafe { SDL_Init(SDL_INIT_VIDEO) }, "SDL_Init")
}
