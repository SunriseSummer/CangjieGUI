/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

/*
 * Mirrors SDL_Vertex: position, straight-alpha float colour, and texture coordinates.
 * Kept as eight flat Float32 fields so the layout matches the C struct exactly.
 */
@C
internal struct SdlVertex {
    var px: Float32 = 0.0
    var py: Float32 = 0.0
    var colR: Float32 = 0.0
    var colG: Float32 = 0.0
    var colB: Float32 = 0.0
    var colA: Float32 = 0.0
    var tu: Float32 = 0.0
    var tv: Float32 = 0.0
}

foreign {
    func SDL_DestroyRenderer(renderer: CPointer<Unit>): Unit

    func SDL_SetRenderVSync(renderer: CPointer<Unit>, vsync: Int32): Bool

    func SDL_GetRenderVSync(renderer: CPointer<Unit>, vsync: CPointer<Int32>): Bool

    func SDL_SetRenderDrawBlendMode(renderer: CPointer<Unit>, blendMode: UInt32): Bool

    func SDL_SetRenderScale(renderer: CPointer<Unit>, scaleX: Float32, scaleY: Float32): Bool

    func SDL_SetRenderViewport(renderer: CPointer<Unit>, rect: CPointer<SdlRect>): Bool

    func SDL_GetRenderViewport(renderer: CPointer<Unit>, rect: CPointer<SdlRect>): Bool

    func SDL_SetRenderClipRect(renderer: CPointer<Unit>, rect: CPointer<SdlRect>): Bool

    func SDL_GetRenderClipRect(renderer: CPointer<Unit>, rect: CPointer<SdlRect>): Bool

    func SDL_RenderClipEnabled(renderer: CPointer<Unit>): Bool

    func SDL_SetRenderColorScale(renderer: CPointer<Unit>, scale: Float32): Bool

    func SDL_GetRenderColorScale(renderer: CPointer<Unit>, scale: CPointer<Float32>): Bool

    func SDL_SetRenderDrawColor(renderer: CPointer<Unit>, r: UInt8, g: UInt8, b: UInt8, a: UInt8): Bool

    func SDL_SetRenderDrawColorFloat(
        renderer: CPointer<Unit>,
        r: Float32,
        g: Float32,
        b: Float32,
        a: Float32
    ): Bool

    func SDL_GetRenderDrawColorFloat(
        renderer: CPointer<Unit>,
        r: CPointer<Float32>,
        g: CPointer<Float32>,
        b: CPointer<Float32>,
        a: CPointer<Float32>
    ): Bool

    func SDL_RenderClear(renderer: CPointer<Unit>): Bool

    func SDL_RenderPresent(renderer: CPointer<Unit>): Bool

    func SDL_RenderPoint(renderer: CPointer<Unit>, x: Float32, y: Float32): Bool

    func SDL_RenderLine(renderer: CPointer<Unit>, x1: Float32, y1: Float32, x2: Float32, y2: Float32): Bool

    func SDL_RenderRect(renderer: CPointer<Unit>, rect: CPointer<SdlFRect>): Bool

    func SDL_RenderFillRect(renderer: CPointer<Unit>, rect: CPointer<SdlFRect>): Bool

    func SDL_RenderDebugText(renderer: CPointer<Unit>, x: Float32, y: Float32, text: CString): Bool

    func SDL_RenderReadPixels(renderer: CPointer<Unit>, rect: CPointer<SdlRect>): CPointer<Unit>

    func SDL_GetRenderOutputSize(renderer: CPointer<Unit>, w: CPointer<Int32>, h: CPointer<Int32>): Bool

    func SDL_CreateTexture(
        renderer: CPointer<Unit>,
        format: UInt32,
        access: Int32,
        w: Int32,
        h: Int32
    ): CPointer<Unit>

    func SDL_SetRenderTarget(renderer: CPointer<Unit>, texture: CPointer<Unit>): Bool

    func SDL_RenderGeometry(
        renderer: CPointer<Unit>,
        texture: CPointer<Unit>,
        vertices: CPointer<SdlVertex>,
        numVertices: Int32,
        indices: CPointer<Int32>,
        numIndices: Int32
    ): Bool
}
