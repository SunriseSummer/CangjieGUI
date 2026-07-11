/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

foreign {
    func SDL_GetPlatform(): CString

    func SDL_OpenURL(url: CString): Bool

    func SDL_GetPowerInfo(seconds: CPointer<Int32>, percent: CPointer<Int32>): Int32

    func SDL_GetNumLogicalCPUCores(): Int32

    func SDL_GetCPUCacheLineSize(): Int32

    func SDL_HasAltiVec(): Bool

    func SDL_HasMMX(): Bool

    func SDL_HasSSE(): Bool

    func SDL_HasSSE2(): Bool

    func SDL_HasSSE3(): Bool

    func SDL_HasSSE41(): Bool

    func SDL_HasSSE42(): Bool

    func SDL_HasAVX(): Bool

    func SDL_HasAVX2(): Bool

    func SDL_HasAVX512F(): Bool

    func SDL_HasARMSIMD(): Bool

    func SDL_HasNEON(): Bool

    func SDL_HasLSX(): Bool

    func SDL_HasLASX(): Bool

    func SDL_GetSystemRAM(): Int32

    func SDL_GetSystemPageSize(): Int32
}
