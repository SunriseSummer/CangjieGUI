package cui.media

import cui.core.{Alignment, UiContext}
import sdl.{Color, ImageLoadOptions, Rect, Renderer, TextureStyle}
import std.math.ceil

// Icon decodes are bounded separately from photographs. Raster codecs still decode their input
// before shrinking; this budget limits the decoded surface, not a codec's transient allocations.
private let ICON_MAX_PIXELS: Int64 = 4194304
private let ICON_MAX_EXTENT: Float32 = 2048.0

internal func iconPixels(renderer: Renderer, extent: Float32): Int32 {
    let raster = renderer.textMeasurementScale()
    let requested = extent * max(raster.w, raster.h)
    if (requested.isNaN() || requested <= 0.0) {
        return 1
    }
    // Clamp before converting to an integer, including overflow to infinity.
    Int32(ceil(min(ICON_MAX_EXTENT, requested)))
}

private func iconMask(source: IconSource): Bool {
    match (source.renderingMode) {
        case IconRenderingMode.Template => true;
        case _ => false
    }
}

private func iconSlot(renderer: Renderer, source: IconSource, pixels: Int32, revision: UInt64): ImageCacheFastSlot {
    let image = source.select(pixels)
    let options = ImageLoadOptions(width: pixels, height: pixels, maxPixels: ICON_MAX_PIXELS)
    let mask = iconMask(source)
    let key = if (mask) {
        "\0mask:${image.identity.size}:${image.identity}:${pixels}:${ICON_MAX_PIXELS}"
    } else {
        image.cacheKey(options)
    }
    sharedImageSlot(renderer, image, options, key, revision, mask: mask)
}

/** Warms the icon at an explicit raster extent (1..2048); invalid extents throw `IllegalArgumentException`. */
public func preloadIcon(renderer: Renderer, source: IconSource, pixels!: Int32): Bool {
    if (pixels <= 0 || pixels > Int32(ICON_MAX_EXTENT)) {
        throw IllegalArgumentException("Preloaded icon extent must be in 1..2048")
    }
    iconSlot(renderer, source, pixels, currentImageCacheRevision()).entry.cached.isSome()
}

/**
 * Paints caller-supplied icon media in a custom widget without constructing/emitting a child widget.
 * Fits inside bounds; color applies only to Template. Cache failures are recoverable blank output.
 * The caller owns clipping and accessibility. Use Icon/IconButton for retained per-instance slots.
 */
public func paintIcon(ctx: UiContext, source: IconSource, bounds: Rect, color: Color, style!: IconStyle = IconStyle()): Unit {
    if (!iconHasArea(bounds)) {
        return
    }
    let slot = iconSlot(ctx.renderer, source, iconPixels(ctx.renderer, max(bounds.w, bounds.h)),
        currentImageCacheRevision())
    paintIconSlot(ctx, slot, source, bounds, color, style)
}

internal func iconHasArea(bounds: Rect): Bool {
    bounds.w > 0.0 && bounds.h > 0.0 && !bounds.x.isNaN() && !bounds.y.isNaN() && !bounds.w.isInf() && !bounds
        .h
        .isInf() && !bounds.right().isInf() && !bounds.bottom().isInf()
}

private func paintIconSlot(ctx: UiContext, slot: ImageCacheFastSlot, source: IconSource, bounds: Rect, color: Color,
    style: IconStyle): Unit {
    if (ctx.tracksResourceReads()) {
        ctx.observeResource(slot.owner.invalidation)
    }
    if (let Some(texture) <- slot.entry.cached) {
        let placement = placeImage(Rect(0.0, 0.0, texture.width, texture.height), bounds, ImageFit.Contain,
            Alignment.Center)
        let tint = if (iconMask(source)) {
            style.color ?? color
        } else {
            Color.rgb(255, 255, 255)
        }
        ctx
            .renderer
            .textureStyled(texture, placement.destination, source: Some(placement.source),
                style: TextureStyle(tint: tint, opacity: style.opacity, sampling: style.sampling, flip: style.flip))
    }
}

internal class IconPainter {
    var source: IconSource
    var style = IconStyle()
    var fallback: ?IconSource = None
    private var slot: ?ImageCacheFastSlot = None
    private var fallbackSlot: ?ImageCacheFastSlot = None
    private var resolvedPixels: Int32 = 0
    var closed = false

    init(source: IconSource) {
        this.source = source
    }

    func reset(): Unit {
        slot = None
        fallbackSlot = None
        resolvedPixels = 0
    }

    func extent(ctx: UiContext): Float32 {
        let value = ctx.resolve(style.size)
        if (value.isNaN() || value.isInf()) {
            return 0.0
        }
        max(0.0, value)
    }

    func draw(ctx: UiContext, bounds: Rect, color: Color): Unit {
        if (closed || !iconHasArea(bounds)) {
            return
        }
        let pixels = iconPixels(ctx.renderer, max(bounds.w, bounds.h))
        let revision = currentImageCacheRevision()
        if (pixels != resolvedPixels) {
            reset();
            resolvedPixels = pixels
        }
        let primary = resolve(ctx.renderer, source, slot, pixels, revision)
        slot = Some(primary)
        // Observe the primary even when a fallback succeeds, so replacing a missing asset repaints.
        paintIconSlot(ctx, primary, source, bounds, color, style)
        if (primary.entry.cached.isNone()) {
            if (let Some(other) <- fallback) {
                let resolved = resolve(ctx.renderer, other, fallbackSlot, pixels, revision)
                fallbackSlot = Some(resolved)
                paintIconSlot(ctx, resolved, other, bounds, color, style)
            }
        }
    }

    private func resolve(renderer: Renderer, image: IconSource, previous: ?ImageCacheFastSlot, pixels: Int32,
        revision: UInt64): ImageCacheFastSlot {
        if (let Some(value) <- previous) {
            if (value.revision == revision && refEq(value.renderer, renderer)) {
                let live = match (value.entry.cached) {
                    case Some(texture) => value.entry.active && !texture.isClosed()
                    case None => true // retain a negative resolution even after global eviction
                }
                if (live) {
                    value.entry.recentlyUsed = true
                    return value
                }
            }
        }
        iconSlot(renderer, image, pixels, revision)
    }

    func status(): ImageStatus {
        if (closed) {
            return ImageStatus.Closed
        }
        if (let Some(value) <- slot) {
            if (value.revision == currentImageCacheRevision()) {
                if (let Some(texture) <- value.entry.cached) {
                    if (value.entry.active && !texture.isClosed()) {
                        return ImageStatus.Ready
                    }
                } else {
                    return ImageStatus.Failed
                }
            }
        }
        ImageStatus.Idle
    }

    func loadError(): ?String {
        if (!closed) {
            if (let Some(value) <- slot) {
                if (value.revision == currentImageCacheRevision() && value.entry.cached.isNone()) {
                    return value.entry.failure
                }
            }
        }
        None
    }
}
