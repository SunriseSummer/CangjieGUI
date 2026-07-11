/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

foreign {
    func SDL_CreateTextureFromSurface(renderer: CPointer<Unit>, surface: CPointer<Unit>): CPointer<Unit>

    func SDL_DestroyTexture(texture: CPointer<Unit>): Unit

    func SDL_GetTextureSize(texture: CPointer<Unit>, w: CPointer<Float32>, h: CPointer<Float32>): Bool

    func SDL_SetTextureColorMod(texture: CPointer<Unit>, r: UInt8, g: UInt8, b: UInt8): Bool

    func SDL_SetTextureAlphaMod(texture: CPointer<Unit>, alpha: UInt8): Bool

    func SDL_SetTextureBlendMode(texture: CPointer<Unit>, blendMode: UInt32): Bool

    func SDL_SetTextureScaleMode(texture: CPointer<Unit>, scaleMode: Int32): Bool

    func SDL_RenderTexture(
        renderer: CPointer<Unit>,
        texture: CPointer<Unit>,
        source: CPointer<SdlFRect>,
        destination: CPointer<SdlFRect>
    ): Bool

    func SDL_RenderTextureRotated(
        renderer: CPointer<Unit>,
        texture: CPointer<Unit>,
        source: CPointer<SdlFRect>,
        destination: CPointer<SdlFRect>,
        angle: Float64,
        center: CPointer<SdlFPoint>,
        flip: Int32
    ): Bool
}
