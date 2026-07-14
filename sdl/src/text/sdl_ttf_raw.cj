package sdl.text

foreign {
    func TTF_Init(): Bool

    func TTF_OpenFont(file: CString, pointSize: Float32): CPointer<Unit>

    func TTF_GetFontFamilyName(font: CPointer<Unit>): CString

    func TTF_GetStringSize(
        font: CPointer<Unit>,
        text: CString,
        length: UIntNative,
        width: CPointer<Int32>,
        height: CPointer<Int32>
    ): Bool

    func TTF_CreateRendererTextEngine(renderer: CPointer<Unit>): CPointer<Unit>

    func TTF_DestroyRendererTextEngine(engine: CPointer<Unit>): Unit

    func TTF_CreateText(
        engine: CPointer<Unit>,
        font: CPointer<Unit>,
        text: CString,
        length: UIntNative
    ): CPointer<Unit>

    func TTF_SetTextString(text: CPointer<Unit>, value: CString, length: UIntNative): Bool

    func TTF_SetTextColor(text: CPointer<Unit>, red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8): Bool

    func TTF_DrawRendererText(text: CPointer<Unit>, x: Float32, y: Float32): Bool

    func TTF_DestroyText(text: CPointer<Unit>): Unit

    func TTF_CloseFont(font: CPointer<Unit>): Unit

    func TTF_Quit(): Unit

    func SDL_GetError(): CString
}
