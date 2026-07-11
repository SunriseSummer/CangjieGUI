/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

foreign {
    func SDL_GetDisplays(count: CPointer<Int32>): CPointer<UInt32>

    func SDL_GetPrimaryDisplay(): UInt32

    func SDL_GetDisplayName(displayId: UInt32): CString

    func SDL_GetDisplayBounds(displayId: UInt32, rect: CPointer<SdlRect>): Bool

    func SDL_GetDisplayUsableBounds(displayId: UInt32, rect: CPointer<SdlRect>): Bool

    func SDL_GetNaturalDisplayOrientation(displayId: UInt32): Int32

    func SDL_GetCurrentDisplayOrientation(displayId: UInt32): Int32

    func SDL_GetDisplayContentScale(displayId: UInt32): Float32

    func SDL_GetFullscreenDisplayModes(displayId: UInt32, count: CPointer<Int32>): CPointer<CPointer<SdlDisplayMode>>

    func SDL_GetClosestFullscreenDisplayMode(
        displayId: UInt32,
        w: Int32,
        h: Int32,
        refreshRate: Float32,
        includeHighDensityModes: Bool,
        closest: CPointer<SdlDisplayMode>
    ): Bool

    func SDL_GetDesktopDisplayMode(displayId: UInt32): CPointer<SdlDisplayMode>

    func SDL_GetCurrentDisplayMode(displayId: UInt32): CPointer<SdlDisplayMode>

    func SDL_GetDisplayForPoint(point: CPointer<SdlPoint>): UInt32

    func SDL_GetDisplayForRect(rect: CPointer<SdlRect>): UInt32

    func SDL_GetDisplayForWindow(window: CPointer<Unit>): UInt32
}
