package cui.media

import cui.core.{Alignment, Length, UiContext}
import sdl.{ImageLoadOptions, Color, Pen, Rect, TextureFlip, TextureScaleMode, TextureStyle}

// Optional styling lives off the default ImageView hot path and is only allocated on customization.
internal class ImageAppearance {
    var source: ?ImageSource = None
    var options = ImageLoadOptions()
    var cacheKey = ""
    var alignment = Alignment.Center
    var crop: ?Rect = None
    var tint = Color.rgb(255, 255, 255)
    var opacity: Float32 = 1.0
    var radius = Length.zero()
    var sampling = TextureScaleMode.Linear
    var flip = TextureFlip.None
    var background: ?Color = None
    var border: ?Pen = None
    var errorPainter: ?(UiContext, Rect, String) -> Unit = None
    var fallback: ?ImageSource = None
    var semanticLabel = ""
    var semanticId = ""
    var aspectRatio: ?Float32 = None
    var intrinsic = false

    func needsTextureStyle(): Bool {
        let filtered = match (sampling) {
            case TextureScaleMode.Nearest => true;
            case _ => false
        }
        let mirrored = match (flip) {
            case TextureFlip.None => false;
            case _ => true
        }
        radius.value > 0.0 || opacity != 1.0 || tint.r != UInt8(255) || tint.g != UInt8(255) || tint.b != UInt8(255) ||
            tint.a != UInt8(255) || filtered || mirrored
    }

    func textureStyle(ctx: UiContext): TextureStyle {
        TextureStyle(tint: tint, opacity: opacity, radius: ctx.resolve(radius), sampling: sampling, flip: flip)
    }
}

/** The state of the primary image after its latest resolution, independent of any fallback image. */
public enum ImageStatus {
    | Idle
    | Ready
    | Failed
    | Closed
}
