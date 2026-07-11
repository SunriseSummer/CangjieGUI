/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import sdl.SdlWindow

public class FileDialogs {
    /**
     * Throws `CuiException` when dialog options are invalid.
     */
    public static func openFile(
        options!: FileDialogOptions = FileDialogOptions(),
        window!: ?SdlWindow = None
    ): FileDialogRequest {
        let request = createFileDialogRequest(options)
        unsafe {
            SDL_ShowOpenFileDialog(cuiFileDialogCallback, request.userdata(), fileDialogWindow(window),
                request.rawFilters(), request.filterCount(), request.defaultLocation(), options.allowMany)
        }
        request
    }

    /**
     * Throws `CuiException` when dialog options are invalid.
     */
    public static func saveFile(
        options!: FileDialogOptions = FileDialogOptions(),
        window!: ?SdlWindow = None
    ): FileDialogRequest {
        let request = createFileDialogRequest(options)
        unsafe {
            SDL_ShowSaveFileDialog(cuiFileDialogCallback, request.userdata(), fileDialogWindow(window),
                request.rawFilters(), request.filterCount(), request.defaultLocation())
        }
        request
    }

    /**
     * Throws `CuiException` when dialog options are invalid.
     */
    public static func openFolder(
        options!: FileDialogOptions = FileDialogOptions(),
        window!: ?SdlWindow = None
    ): FileDialogRequest {
        let request = createFileDialogRequest(options)
        unsafe {
            SDL_ShowOpenFolderDialog(cuiFileDialogCallback, request.userdata(), fileDialogWindow(window),
                request.defaultLocation(), options.allowMany)
        }
        request
    }
}
