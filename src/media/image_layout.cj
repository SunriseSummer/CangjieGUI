package cui.media

import sdl.{Rect, Size}
import cui.core.Alignment

/** How image pixels fit the view: fill, contain, cover, original size, or contain without enlarging. */
public enum ImageFit {
    | Stretch
    | Contain
    | Cover
    | Original
    | ScaleDown
}

internal struct ImagePlacement {
    let source: Rect
    let destination: Rect
    init(source: Rect, destination: Rect) {
        this.source = source
        this.destination = destination
    }
}

// Crop in source pixels instead of painting an oversized image under a second scissor.
internal func placeImage(source: Rect, frame: Rect, fit: ImageFit, alignment: Alignment): ImagePlacement {
    if (source.w <= 0.0 || source.h <= 0.0 || frame.w <= 0.0 || frame.h <= 0.0) {
        return ImagePlacement(Rect.zero(), Rect.zero())
    }
    let factors = imageAlignmentFactors(alignment)
    let scale = match (fit) {
        case ImageFit.Stretch => return ImagePlacement(source, frame)
        case ImageFit.Contain => min(frame.w / source.w, frame.h / source.h)
        case ImageFit.Cover => max(frame.w / source.w, frame.h / source.h)
        case ImageFit.Original => Float32(1.0)
        case ImageFit.ScaleDown => min(1.0, min(frame.w / source.w, frame.h / source.h))
    }
    let width = min(frame.w, source.w * scale)
    let height = min(frame.h, source.h * scale)
    let sourceWidth = min(source.w, width / scale)
    let sourceHeight = min(source.h, height / scale)
    ImagePlacement(
        Rect(source.x + (source.w - sourceWidth) * factors.w, source.y + (source.h - sourceHeight) * factors.h,
            sourceWidth, sourceHeight),
        Rect(frame.x + (frame.w - width) * factors.w, frame.y + (frame.h - height) * factors.h, width, height)
    )
}

private func imageAlignmentFactors(alignment: Alignment): Size {
    match (alignment) {
        case Alignment.TopLeading => Size(0.0, 0.0)
        case Alignment.Top => Size(0.5, 0.0)
        case Alignment.TopTrailing => Size(1.0, 0.0)
        case Alignment.Leading => Size(0.0, 0.5)
        case Alignment.Center => Size(0.5, 0.5)
        case Alignment.Trailing => Size(1.0, 0.5)
        case Alignment.BottomLeading => Size(0.0, 1.0)
        case Alignment.Bottom => Size(0.5, 1.0)
        case Alignment.BottomTrailing => Size(1.0, 1.0)
    }
}

/** Rejects a non-finite or negative length with `IllegalArgumentException`. */
internal func checkedImageLength(value: Float32): Unit {
    if (value.isNaN() || value.isInf() || value < 0.0) {
        throw IllegalArgumentException("Image lengths must be finite and non-negative")
    }
}
