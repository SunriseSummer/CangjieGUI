/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

internal let SDL_NS_PER_MS: UInt64 = UInt64(1000000)

foreign {
    func SDL_GetTicksNS(): UInt64

    func SDL_GetPerformanceCounter(): UInt64

    func SDL_GetPerformanceFrequency(): UInt64

    func SDL_DelayNS(ns: UInt64): Unit

    func SDL_DelayPrecise(ns: UInt64): Unit
}
