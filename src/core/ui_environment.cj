package cui.core

import std.sync.AtomicUInt64
import std.deriving.*

private let UI_ENVIRONMENT_GENERATION_COUNTER = AtomicUInt64(UInt64(0))

/* Process-unique generation interned for one complete ambient UI environment. */
func allocateUiEnvironmentGeneration(): UInt64 {
    UI_ENVIRONMENT_GENERATION_COUNTER.fetchAdd(UInt64(1))
}

/*
 * Interned key for ambient inputs that may change phase output without changing explicit geometry:
 * UiContext identity, renderer/theme identity, display and font scale, and the frame-stable font
 * registry snapshot, actual raster scale and inherited typography. Value equality also protects
 * layout caches when a renderer scale or a subtree font scope changes without a new frame.
 */
@Derive[Equatable, Hashable]
protected struct UiEnvironmentKey {
    let generation: UInt64
    let rasterScaleX: UInt32
    let rasterScaleY: UInt32
    let fontRevision: UInt64
    let fontFamily: String
    let textSize: UInt32
    let textStyle: Int32
    let fontVariations: String
    let fontWeight: Int64

    init(generation: UInt64, rasterScaleX!: UInt32 = UInt32(0), rasterScaleY!: UInt32 = UInt32(0),
        fontRevision!: UInt64 = UInt64(0), fontFamily!: String = "", textSize!: UInt32 = UInt32(0),
        textStyle!: Int32 = 0, fontWeight!: Int64 = 400, fontVariations!: String = "") {
        this.generation = generation
        this.rasterScaleX = rasterScaleX
        this.rasterScaleY = rasterScaleY
        this.fontRevision = fontRevision
        this.fontFamily = fontFamily
        this.textSize = textSize
        this.textStyle = textStyle
        this.fontWeight = fontWeight
        this.fontVariations = fontVariations
    }
}

protected func sameUiEnvironment(left: UiEnvironmentKey, right: UiEnvironmentKey): Bool {
    left == right
}
