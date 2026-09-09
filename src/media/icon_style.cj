package cui.media

import cui.core.{Length, LengthUnit}
import sdl.{Color, TextureFlip, TextureScaleMode}

/** Immutable icon appearance shared by Icon and IconButton; backgrounds belong to the container. */
public struct IconStyle {
    public let size: Length
    public let color: ?Color
    public let opacity: Float32
    public let sampling: TextureScaleMode
    public let flip: TextureFlip

    /**
     * Size defaults to 18 vp. Color inherits the theme and only affects Template sources. Throws
     * `IllegalArgumentException` for non-finite/negative size or opacity outside finite 0..1.
     */
    public init(size!: Length = Length(18.0, LengthUnit.Vp), color!: ?Color = None, opacity!: Float32 = 1.0,
        sampling!: TextureScaleMode = TextureScaleMode.Linear, flip!: TextureFlip = TextureFlip.None) {
        checkedImageLength(size.value)
        if (opacity.isNaN() || opacity.isInf() || opacity < 0.0 || opacity > 1.0) {
            throw IllegalArgumentException("Icon opacity must be finite and in 0..1")
        }
        this.size = size
        this.color = color
        this.opacity = opacity
        this.sampling = sampling
        this.flip = flip
    }
}
