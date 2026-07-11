/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.input

foreign {
    func SDL_CaptureMouse(enabled: Bool): Bool

    func SDL_ClearClipboardData(): Bool

    func SDL_CreateSystemCursor(id: Int32): CPointer<Unit>

    func SDL_CursorVisible(): Bool

    func SDL_DestroyCursor(cursor: CPointer<Unit>): Unit

    func SDL_free(mem: CPointer<UInt8>): Unit

    func SDL_GetClipboardData(mimeType: CString, size: CPointer<UIntNative>): CPointer<UInt8>

    func SDL_GetClipboardMimeTypes(numMimeTypes: CPointer<UIntNative>): CPointer<CPointer<UInt8>>

    func SDL_GetClipboardText(): CString

    func SDL_GetDefaultCursor(): CPointer<Unit>

    func SDL_GetModState(): UInt16

    func SDL_GetMouseState(x: CPointer<Float32>, y: CPointer<Float32>): UInt32

    func SDL_GetPrimarySelectionText(): CString

    func SDL_HasClipboardData(mimeType: CString): Bool

    func SDL_HasClipboardText(): Bool

    func SDL_HasPrimarySelectionText(): Bool

    func SDL_HideCursor(): Bool

    func SDL_SetClipboardData(
        callback: CFunc<(CPointer<Unit>, CPointer<UInt8>, CPointer<UIntNative>) -> CPointer<Unit>>,
        cleanup: CFunc<(CPointer<Unit>) -> Unit>,
        userdata: CPointer<Unit>,
        mimeTypes: CPointer<CPointer<UInt8>>,
        numMimeTypes: UIntNative
    ): Bool

    func SDL_SetClipboardText(text: CString): Bool

    func SDL_SetCursor(cursor: CPointer<Unit>): Bool

    func SDL_SetPrimarySelectionText(text: CString): Bool

    func SDL_ShowCursor(): Bool
}
