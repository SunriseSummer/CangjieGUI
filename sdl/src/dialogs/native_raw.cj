/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import sdl.{SdlDialogFileFilter, SdlMessageBoxData}

foreign {
    func SDL_ShowMessageBox(messageboxdata: CPointer<SdlMessageBoxData>, buttonid: CPointer<Int32>): Bool

    func SDL_ShowOpenFileDialog(
        callback: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt8>>, Int32) -> Unit>,
        userdata: CPointer<Unit>,
        window: CPointer<Unit>,
        filters: CPointer<SdlDialogFileFilter>,
        nfilters: Int32,
        defaultLocation: CString,
        allowMany: Bool
    ): Unit

    func SDL_ShowOpenFolderDialog(
        callback: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt8>>, Int32) -> Unit>,
        userdata: CPointer<Unit>,
        window: CPointer<Unit>,
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

    func SDL_ShowSimpleMessageBox(flags: UInt32, title: CString, message: CString, window: CPointer<Unit>): Bool
}
