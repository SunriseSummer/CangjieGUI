/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

@C
internal struct SdlDialogFileFilter {
    var name = CString(CPointer<UInt8>())
    var pattern = CString(CPointer<UInt8>())
}

foreign {
    func SDL_ShowOpenFileDialog(
        callback: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt8>>, Int32) -> Unit>,
        userdata: CPointer<Unit>,
        window: CPointer<Unit>,
        filters: CPointer<SdlDialogFileFilter>,
        nfilters: Int32,
        defaultLocation: CString,
        allowMany: Bool
    ): Unit

    func SDL_ShowSaveFileDialog(
        callback: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt8>>, Int32) -> Unit>,
        userdata: CPointer<Unit>,
        window: CPointer<Unit>,
        filters: CPointer<SdlDialogFileFilter>,
        nfilters: Int32,
        defaultLocation: CString
    ): Unit

    func SDL_ShowOpenFolderDialog(
        callback: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt8>>, Int32) -> Unit>,
        userdata: CPointer<Unit>,
        window: CPointer<Unit>,
        defaultLocation: CString,
        allowMany: Bool
    ): Unit
}
