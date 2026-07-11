/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

foreign {
    func SDL_GetMouseState(x: CPointer<Float32>, y: CPointer<Float32>): UInt32

    func SDL_CaptureMouse(enabled: Bool): Bool

    func SDL_SetWindowRelativeMouseMode(window: CPointer<Unit>, enabled: Bool): Bool

    func SDL_GetModState(): UInt16

    func SDL_CreateSystemCursor(id: Int32): CPointer<Unit>

    func SDL_SetCursor(cursor: CPointer<Unit>): Bool

    func SDL_GetDefaultCursor(): CPointer<Unit>

    func SDL_DestroyCursor(cursor: CPointer<Unit>): Unit

    func SDL_ShowCursor(): Bool

    func SDL_HideCursor(): Bool

    func SDL_CursorVisible(): Bool
}
