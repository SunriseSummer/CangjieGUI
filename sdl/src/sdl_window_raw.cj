/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

foreign {
    func SDL_CreateWindowAndRenderer(
        title: CString,
        width: Int32,
        height: Int32,
        windowFlags: UInt64,
        window: CPointer<CPointer<Unit>>,
        renderer: CPointer<CPointer<Unit>>
    ): Bool

    func SDL_DestroyWindow(window: CPointer<Unit>): Unit

    func SDL_SetWindowTitle(window: CPointer<Unit>, title: CString): Bool

    func SDL_GetWindowTitle(window: CPointer<Unit>): CString

    func SDL_GetWindowFlags(window: CPointer<Unit>): UInt64

    func SDL_GetWindowSize(window: CPointer<Unit>, w: CPointer<Int32>, h: CPointer<Int32>): Bool

    func SDL_SetWindowSize(window: CPointer<Unit>, w: Int32, h: Int32): Bool

    func SDL_GetWindowSizeInPixels(window: CPointer<Unit>, w: CPointer<Int32>, h: CPointer<Int32>): Bool

    func SDL_GetWindowSafeArea(window: CPointer<Unit>, rect: CPointer<SdlRect>): Bool

    func SDL_SetWindowPosition(window: CPointer<Unit>, x: Int32, y: Int32): Bool

    func SDL_GetWindowPosition(window: CPointer<Unit>, x: CPointer<Int32>, y: CPointer<Int32>): Bool

    func SDL_SetWindowMinimumSize(window: CPointer<Unit>, minW: Int32, minH: Int32): Bool

    func SDL_GetWindowMinimumSize(window: CPointer<Unit>, w: CPointer<Int32>, h: CPointer<Int32>): Bool

    func SDL_SetWindowMaximumSize(window: CPointer<Unit>, maxW: Int32, maxH: Int32): Bool

    func SDL_GetWindowMaximumSize(window: CPointer<Unit>, w: CPointer<Int32>, h: CPointer<Int32>): Bool

    func SDL_GetWindowBordersSize(
        window: CPointer<Unit>,
        top: CPointer<Int32>,
        left: CPointer<Int32>,
        bottom: CPointer<Int32>,
        right: CPointer<Int32>
    ): Bool

    func SDL_SetWindowAspectRatio(window: CPointer<Unit>, minAspect: Float32, maxAspect: Float32): Bool

    func SDL_GetWindowAspectRatio(
        window: CPointer<Unit>,
        minAspect: CPointer<Float32>,
        maxAspect: CPointer<Float32>
    ): Bool

    func SDL_SetWindowBordered(window: CPointer<Unit>, bordered: Bool): Bool

    func SDL_SetWindowResizable(window: CPointer<Unit>, resizable: Bool): Bool

    func SDL_SetWindowAlwaysOnTop(window: CPointer<Unit>, onTop: Bool): Bool

    func SDL_SetWindowOpacity(window: CPointer<Unit>, opacity: Float32): Bool

    func SDL_GetWindowOpacity(window: CPointer<Unit>): Float32

    func SDL_GetWindowPixelDensity(window: CPointer<Unit>): Float32

    func SDL_GetWindowDisplayScale(window: CPointer<Unit>): Float32

    func SDL_ShowWindow(window: CPointer<Unit>): Bool

    func SDL_HideWindow(window: CPointer<Unit>): Bool

    func SDL_RaiseWindow(window: CPointer<Unit>): Bool

    func SDL_MaximizeWindow(window: CPointer<Unit>): Bool

    func SDL_MinimizeWindow(window: CPointer<Unit>): Bool

    func SDL_RestoreWindow(window: CPointer<Unit>): Bool

    func SDL_SetWindowFullscreen(window: CPointer<Unit>, fullscreen: Bool): Bool

    func SDL_SyncWindow(window: CPointer<Unit>): Bool

    func SDL_FlashWindow(window: CPointer<Unit>, operation: Int32): Bool

    func SDL_SetWindowFillDocument(window: CPointer<Unit>, fill: Bool): Bool

    func SDL_SetWindowKeyboardGrab(window: CPointer<Unit>, grabbed: Bool): Bool

    func SDL_SetWindowMouseGrab(window: CPointer<Unit>, grabbed: Bool): Bool

    func SDL_GetWindowKeyboardGrab(window: CPointer<Unit>): Bool

    func SDL_GetWindowMouseGrab(window: CPointer<Unit>): Bool

    func SDL_SetWindowMouseRect(window: CPointer<Unit>, rect: CPointer<SdlRect>): Bool

    func SDL_GetWindowMouseRect(window: CPointer<Unit>): CPointer<SdlRect>

    func SDL_SetWindowFocusable(window: CPointer<Unit>, focusable: Bool): Bool

    func SDL_ShowWindowSystemMenu(window: CPointer<Unit>, x: Int32, y: Int32): Bool

    func SDL_SetWindowProgressState(window: CPointer<Unit>, state: Int32): Bool

    func SDL_GetWindowProgressState(window: CPointer<Unit>): Int32

    func SDL_SetWindowProgressValue(window: CPointer<Unit>, value: Float32): Bool

    func SDL_GetWindowProgressValue(window: CPointer<Unit>): Float32

    func SDL_StartTextInput(window: CPointer<Unit>): Bool

    func SDL_StopTextInput(window: CPointer<Unit>): Bool

    func SDL_SetTextInputArea(window: CPointer<Unit>, rect: CPointer<SdlRect>, cursor: Int32): Bool
}
