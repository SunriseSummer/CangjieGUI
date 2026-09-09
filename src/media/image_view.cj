package cui.media

import sdl.{Color, ImageLoadOptions, Pen, Rect, Renderer, Size, Texture, TextureFlip, TextureScaleMode, UiEvent}
import cui.core.{Alignment, Length, LengthUnit, PaintOutset, Semantics, SemanticsNode, SemanticsRole}
import cui.core.{UiContext, Widget, controlIdentity, emit}

/**
 * A cached static image from a file or immutable memory source. Declare inline; warm draws never
 * decode again. The compatibility layout fills the offered width with a 96 vp height; use `size`,
 * `aspectRatio` or opt-in `intrinsicSize` for other layouts. `close` retires only this view.
 */
public class ImageView <: Widget & Resource {
    private var path: String
    private var imageFit: ImageFit
    private var preferredWidth: ?Length
    private var preferredHeight: Length
    private var appearance: ?ImageAppearance = None
    private var frame = Rect.zero()
    private var closed = false
    private var resolvedSlot: ?ImageCacheFastSlot = None

    /** Creates a file image; named legacy size parameters remain supported. */
    public init(path: String, fit!: ImageFit = ImageFit.Contain, preferredWidth!: ?Length = None,
        preferredHeight!: Length = Length(96.0, LengthUnit.Vp)) {
        this.path = path
        this.imageFit = fit
        this.preferredWidth = preferredWidth
        this.preferredHeight = preferredHeight
        emit(this)
    }

    /** Creates an image from a reusable source with the same compatibility sizing as file images. */
    public init(source: ImageSource, fit!: ImageFit = ImageFit.Contain, preferredWidth!: ?Length = None,
        preferredHeight!: Length = Length(96.0, LengthUnit.Vp)) {
        this("", fit: fit, preferredWidth: preferredWidth, preferredHeight: preferredHeight)
        path = source.identity
        styling().source = Some(source)
    }

    /** Selects the image's fit within its frame. */
    public func fit(value: ImageFit): ImageView {
        imageFit = value
        this
    }

    /** Sets both preferred lengths without Option wrappers; invalid lengths throw `IllegalArgumentException`. */
    public func size(width: Length, height: Length): ImageView {
        checkedImageLength(width.value)
        checkedImageLength(height.value)
        preferredWidth = Some(width)
        preferredHeight = height
        this
    }

    /** Controls which part stays visible when cropped, or where a smaller image sits. */
    public func imageAlignment(value: Alignment): ImageView {
        styling().alignment = value
        this
    }

    /** Reserves width / height without decoding during measurement; invalid ratios throw `IllegalArgumentException`. */
    public func aspectRatio(value: Float32): ImageView {
        checkedImageLength(value)
        if (value == 0.0) {
            throw IllegalArgumentException("Image aspect ratio must be positive")
        }
        styling().aspectRatio = Some(value)
        this
    }

    /** Opts into loading during measure and fitting the decoded pixel size within the available logical size. */
    public func intrinsicSize(): ImageView {
        styling().intrinsic = true
        this
    }

    /**
     * Bounds cached pixels independently from layout. SVG rasterizes at these bounds; raster images
     * shrink after decode. Zero leaves an axis unconstrained. Invalid sizes throw `IllegalArgumentException`.
     */
    public func decodeSize(width: Int32, height: Int32): ImageView {
        decodeOptions(ImageLoadOptions(width: width, height: height))
    }

    /** Sets the complete decode policy, including a custom pixel budget, independently from layout. */
    public func decodeOptions(value: ImageLoadOptions): ImageView {
        let style = styling()
        style.options = value
        let source = style.source ?? ImageSource(path)
        style.cacheKey = source.cacheKey(style.options)
        resolvedSlot = None
        this
    }

    /** Bounds cached width while preserving the source aspect ratio. */
    public func decodeSize(width: Int32): ImageView {
        decodeSize(width, 0)
    }

    /** Selects a region in decoded pixels, intersected with the image; invalid coordinates throw `IllegalArgumentException`. */
    public func sourceRect(value: Rect): ImageView {
        for (coordinate in [value.x, value.y]) {
            if (coordinate.isNaN() || coordinate.isInf()) {
                throw IllegalArgumentException("Image crop must be finite")
            }
        }
        checkedImageLength(value.w)
        checkedImageLength(value.h)
        styling().crop = Some(value)
        this
    }

    /** Multiplies image RGB and alpha without changing other views of the same texture. */
    public func tint(value: Color): ImageView {
        styling().tint = value
        this
    }

    /** Sets image opacity in 0..1; invalid values throw `IllegalArgumentException`. Decorations remain independent. */
    public func imageOpacity(value: Float32): ImageView {
        checkedImageLength(value)
        if (value > 1.0) {
            throw IllegalArgumentException("Image opacity must be in 0..1")
        }
        styling().opacity = value
        this
    }

    /** Clips image corners with anti-aliasing; invalid lengths throw `IllegalArgumentException`. */
    public func cornerRadius(value: Length): ImageView {
        checkedImageLength(value.value)
        styling().radius = value
        this
    }

    /** Chooses smooth scaling or nearest-neighbor pixel art. */
    public func sampling(value: TextureScaleMode): ImageView {
        styling().sampling = value
        this
    }

    /** Mirrors image pixels without affecting the surrounding layout. */
    public func flip(value: TextureFlip): ImageView {
        styling().flip = value
        this
    }

    /** Paints the rounded frame, including transparent pixels and contain-mode letterboxing. */
    public func imageBackground(value: Color): ImageView {
        styling().background = Some(value)
        this
    }

    /** Paints a frame border inside the layout bounds; invalid widths throw `IllegalArgumentException`. */
    public func imageBorder(color: Color, width!: Float32 = 1.0): ImageView {
        checkedImageLength(width)
        styling().border = Some(Pen(color: color, width: width))
        this
    }

    /** Uses another cached source on failure; status/error still describe the primary source. */
    public func fallback(value: ImageSource): ImageView {
        styling().fallback = Some(value)
        this
    }

    /** Records custom failure painting inside the frame; the callback must only draw without mutating application state. */
    public func errorPlaceholder(paint: (UiContext, Rect, String) -> Unit): ImageView {
        styling().errorPainter = Some(paint)
        this
    }

    /** Provides image accessibility text; an empty label leaves this image decorative. */
    public func alt(value: String): ImageView {
        let style = styling()
        style.semanticLabel = value
        style.semanticId = if (value.isEmpty()) {
            ""
        } else {
            controlIdentity("Image:${value}")
        }
        this
    }

    /** Returns the primary image's latest resolution state without performing I/O. */
    public func status(): ImageStatus {
        if (closed) {
            return ImageStatus.Closed
        }
        match (resolvedSlot) {
            case Some(slot) =>
                if ((!slot.entry.active && slot.entry.cached.isSome()) || slot.revision != currentImageCacheRevision()) {
                    return ImageStatus.Idle
                }
                match (slot.entry.cached) {
                    case Some(texture) =>
                        if (texture.isClosed()) {
                            ImageStatus.Idle
                        } else {
                            ImageStatus.Ready
                        }
                    case None => ImageStatus.Failed
                }
            case None => ImageStatus.Idle
        }
    }

    /** Returns cached diagnostics, or None before loading/after invalidation; does not trigger a load. */
    public func loadError(): ?String {
        match (resolvedSlot) {
            case Some(slot) where !closed && (slot.entry.active || slot.entry.cached.isNone()) && slot.revision ==
                currentImageCacheRevision() => slot.entry.failure
            case _ => None
        }
    }

    public func measure(ctx: UiContext, available: Size): Size {
        let width = match (preferredWidth) {
            case Some(value) => min(available.w, max(0.0, ctx.resolve(value)))
            case None => available.w
        }
        if (let Some(style) <- appearance) {
            if (let Some(ratio) <- style.aspectRatio) {
                let height = min(available.h, width / ratio)
                return Size(min(width, height * ratio), height)
            }
            if (style.intrinsic && !closed) {
                let resolved = textureForDraw(ctx.renderer)
                if (let Some(slot) <- resolvedSlot) {
                    let _ = slot.owner.invalidation.value // cjcheck-ignore: ignore-result # intrinsic dimensions are retained layout dependencies, including failed loads
                }
                if (let Some(image) <- resolved) {
                    let scale = min(1.0, min(available.w / image.width, available.h / image.height))
                    return Size(image.width * scale, image.height * scale)
                }
            }
        }
        Size(width, min(available.h, max(0.0, ctx.resolve(preferredHeight))))
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        frame = rect
        if (let Some(style) <- appearance) {
            if (!style.semanticId.isEmpty()) {
                ctx.registerSemantics(
                    SemanticsNode(style.semanticId, Semantics(label: style.semanticLabel, role: SemanticsRole.Image),
                        rect))
            }
        }
    }

    public func draw(ctx: UiContext): Unit {
        if (closed) {
            return
        }
        // Resolve plain first-use misses here as well as stable negative-cache hits.
        if (appearance.isNone() && !ctx.tracksResourceReads()) {
            let revision = currentImageCacheRevision()
            if (resolvedSlot.isNone()) {
                resolvedSlot = Some(sharedImageSlotAtRevision(ctx.renderer, path, revision))
            }
            if (let Some(slot) <- resolvedSlot) {
                if (slot.revision == revision && refEq(slot.renderer, ctx.renderer) && slot.entry.cached.isNone()) {
                    slot.entry.recentlyUsed = true
                    return
                }
            }
        }
        drawResolved(ctx)
    }

    private func drawResolved(ctx: UiContext): Unit {
        let image = textureForDraw(ctx.renderer)
        if (ctx.tracksResourceReads()) {
            if (let Some(slot) <- resolvedSlot) {
                ctx.observeResource(slot.owner.invalidation)
            }
        }
        match (appearance) {
            case Some(style) => drawStyled(ctx, image, style)
            case None =>
                if (let Some(texture) <- image) {
                    let placed = placeImage(Rect(0.0, 0.0, texture.width, texture.height), frame, imageFit,
                        Alignment.Center)
                    ctx.renderer.texture(texture, placed.destination, source: Some(placed.source))
                }
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func paintOutset(): PaintOutset {
        if (let Some(style) <- appearance) {
            if (style.background.isSome() || style.border.isSome()) {
                return PaintOutset.all(1.0)
            }
        }
        PaintOutset()
    }

    /** Whether this view has been retired. */
    public func isClosed(): Bool {
        closed
    }

    /** Stops drawing this view; its shared texture remains owned by the bounded cache. */
    public func close(): Unit {
        closed = true
    }

    private func styling(): ImageAppearance {
        match (appearance) {
            case Some(value) => value
            case None =>
                let value = ImageAppearance()
                appearance = Some(value)
                value
        }
    }

    // Live views retain negative resolutions independently of the global capacity policy. An
    // explicit invalidation advances revision; a changed decode policy clears resolvedSlot.
    private func textureForDraw(renderer: Renderer): ?Texture {
        let revision = currentImageCacheRevision()
        match (resolvedSlot) {
            case Some(slot) =>
                if (slot.revision == revision && refEq(slot.renderer, renderer)) {
                    match (slot.entry.cached) {
                        case Some(texture) =>
                            if (slot.entry.active && !texture.isClosed()) {
                                slot.entry.recentlyUsed = true
                                return Some(texture)
                            }
                        case None =>
                            slot.entry.recentlyUsed = true
                            return None
                    }
                }
            case None => ()
        }
        resolveTexture(renderer, revision)
    }

    private func resolveTexture(renderer: Renderer, revision: UInt64): ?Texture {
        let slot = match (appearance) {
            case Some(style) =>
                let source = style.source ?? ImageSource(path)
                let key = if (style.cacheKey.isEmpty()) {
                    path
                } else {
                    style.cacheKey
                }
                sharedImageSlot(renderer, source, style.options, key, revision)
            case None => sharedImageSlotAtRevision(renderer, path, revision)
        }
        resolvedSlot = Some(slot)
        slot.entry.cached
    }

    /** Throws `IllegalStateException` if a custom error painter invalidates its recorded resources. */
    private func drawStyled(ctx: UiContext, image: ?Texture, style: ImageAppearance): Unit {
        let radius = min(ctx.resolve(style.radius), min(frame.w, frame.h) / 2.0)
        if (let Some(color) <- style.background) {
            ctx.renderer.fillRoundedRect(frame, radius, color)
        }
        var texture = image
        if (texture.isNone()) {
            if (let Some(fallbackSource) <- style.fallback) {
                let fallbackKey = fallbackSource.cacheKey(style.options)
                texture = sharedImageSlot(ctx.renderer, fallbackSource, style.options, fallbackKey,
                    currentImageCacheRevision()).entry.cached
            }
        }
        if (let Some(value) <- texture) {
            let full = Rect(0.0, 0.0, value.width, value.height)
            let crop = match (style.crop) {
                case Some(rect) => full.intersection(rect);
                case None => full
            }
            let placed = placeImage(crop, frame, imageFit, style.alignment)
            if (style.needsTextureStyle()) {
                ctx
                    .renderer
                    .textureStyled(value, placed.destination, source: Some(placed.source),
                        style: style.textureStyle(ctx))
            } else {
                ctx.renderer.texture(value, placed.destination, source: Some(placed.source))
            }
        } else if (let Some(paint) <- style.errorPainter) {
            // Recording isolates both the native and enclosing recorder's clip stack when
            // custom code throws or returns with unbalanced clips. Only a complete painter is replayed.
            let placeholder = ctx.renderer.recordCommands {
                =>
                    ctx.renderer.pushClip(frame)
                    paint(ctx, frame, loadError() ?? "Image is unavailable")
                    ctx.renderer.popClip()
            }
            if (!placeholder.replay(ctx.renderer)) {
                throw IllegalStateException("Image error painter invalidated its recorded resources")
            }
        }
        if (let Some(pen) <- style.border) {
            let width = min(pen.width, min(frame.w, frame.h))
            ctx
                .renderer
                .strokeRoundedRect(frame.inset(width / 2.0), max(0.0, radius - width / 2.0),
                    Pen(color: pen.color, width: width))
        }
    }
}
