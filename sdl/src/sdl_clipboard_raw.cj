/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

foreign {
    func SDL_SetClipboardText(text: CString): Bool

    func SDL_GetClipboardText(): CString

    func SDL_HasClipboardText(): Bool

    func SDL_SetPrimarySelectionText(text: CString): Bool

    func SDL_GetPrimarySelectionText(): CString

    func SDL_HasPrimarySelectionText(): Bool

    func SDL_SetClipboardData(
        callback: CFunc<(CPointer<Unit>, CPointer<UInt8>, CPointer<UIntNative>) -> CPointer<Unit>>,
        cleanup: CFunc<(CPointer<Unit>) -> Unit>,
        userdata: CPointer<Unit>,
        mimeTypes: CPointer<CPointer<UInt8>>,
        numMimeTypes: UIntNative
    ): Bool

    func SDL_ClearClipboardData(): Bool

    func SDL_GetClipboardData(mimeType: CString, size: CPointer<UIntNative>): CPointer<UInt8>

    func SDL_HasClipboardData(mimeType: CString): Bool

    func SDL_GetClipboardMimeTypes(numMimeTypes: CPointer<UIntNative>): CPointer<CPointer<UInt8>>
}
