/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

internal let SDL_PIXELFORMAT_RGBA32: UInt32 = UInt32(0x16762004)

foreign {
    func SDL_CreateSurface(width: Int32, height: Int32, format: UInt32): CPointer<Unit>

    func SDL_DestroySurface(surface: CPointer<Unit>): Unit

    func SDL_LoadBMP(file: CString): CPointer<Unit>

    func SDL_LoadPNG(file: CString): CPointer<Unit>

    func SDL_SaveBMP(surface: CPointer<Unit>, file: CString): Bool

    func SDL_WriteSurfacePixel(
        surface: CPointer<Unit>,
        x: Int32,
        y: Int32,
        r: UInt8,
        g: UInt8,
        b: UInt8,
        a: UInt8
    ): Bool

    func SDL_ClearSurface(surface: CPointer<Unit>, r: Float32, g: Float32, b: Float32, a: Float32): Bool
}
