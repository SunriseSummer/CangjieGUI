package cui.media

import sdl.{Rect, Renderer, Size, Texture, UiEvent}
import cui.core.{Length, LengthUnit, UiContext, Widget, emit}

/*
 * How an image resolves a frame whose aspect ratio differs from its own: `Stretch` fills
 * both axes ignoring aspect, `Contain` letterboxes to show the whole image, and `Cover`
 * fills the frame and crops the overflow.
 */
public enum ImageFit {
    | Stretch
    | Contain
    | Cover
}

/*
 * Displays an image loaded from a file. Decoded textures live in the thread- and renderer-scoped,
 * bounded path cache (see texture_cache.cj), so an ImageView is declared inline like any other
 * widget — the per-frame rebuild costs one cache lookup, not a disk load. A stable view also keeps
 * its resolved entry until the global invalidation revision changes. After overwriting an image
 * file, call `invalidateImage(path)` to refresh it.
 *
 * The class still implements `Resource` for source compatibility with the earlier
 * hoist-and-`manage` pattern; `close()` only retires this view (the cache owns the texture).
 */
public class ImageView <: Widget & Resource {
    private let path: String
    private var imageFit: ImageFit
    private let preferredWidth: ?Length
    private let preferredHeight: Length
    private var frame = Rect.zero()
    private var closed = false
    private var resolvedSlot: ?ImageCacheFastSlot = None

    public init(
        path: String,
        fit!: ImageFit = ImageFit.Contain,
        preferredWidth!: ?Length = None,
        preferredHeight!: Length = Length(96.0, LengthUnit.Vp)
    ) {
        this.path = path
        this.imageFit = fit
        this.preferredWidth = preferredWidth
        this.preferredHeight = preferredHeight
        emit(this)
    }

    /** Selects how image pixels are fitted into the assigned frame. */
    public func fit(value: ImageFit): ImageView {
        imageFit = value
        this
    }

    // Without a preferred width an image fills the space it is offered (a full-width block);
    // with one it hugs that box, which is what lets it sit inline beside other controls.
    public func measure(ctx: UiContext, available: Size): Size {
        let width = match (preferredWidth) {
            case Some(value) => min(available.w, max(0.0, ctx.resolve(value)))
            case None => available.w
        }
        Size(width, min(available.h, max(0.0, ctx.resolve(preferredHeight))))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (closed) {
            return
        }
        match (textureForDraw(ctx.renderer)) {
            case Some(image) =>
                let destination = fittedRect(Size(image.width, image.height), frame, imageFit)
                match (imageFit) {
                    case ImageFit.Cover =>
                        ctx.renderer.pushClip(frame)
                        ctx.renderer.texture(image, destination)
                        ctx.renderer.popClip()
                    case _ => ctx.renderer.texture(image, destination)
                }
            case None => () // missing/undecodable image: draw nothing rather than crash the frame loop
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    /** Whether `close` has been called; a closed view stops drawing its texture. */
    public func isClosed(): Bool {
        closed
    }

    /** Releases the view's claim on its texture; the shared cache owns the actual texture. */
    public func close(): Unit {
        closed = true
    }

    private func textureForDraw(renderer: Renderer): ?Texture {
        let revision = currentImageCacheRevision()
        match (resolvedSlot) {
            case Some(slot) =>
                if (slot.revision == revision && refEq(slot.renderer, renderer) && slot.entry.active) {
                    match (slot.entry.cached) {
                        case Some(texture) =>
                            if (!texture.isClosed()) {
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
        let slot = sharedImageSlotAtRevision(renderer, path, revision)
        resolvedSlot = Some(slot)
        slot.entry.cached
    }
}

private func fittedRect(image: Size, frame: Rect, fit: ImageFit): Rect {
    if (image.w <= 0.0 || image.h <= 0.0 || frame.w <= 0.0 || frame.h <= 0.0) {
        return Rect(frame.x, frame.y, 0.0, 0.0)
    }
    match (fit) {
        case ImageFit.Stretch => frame
        case ImageFit.Contain => scaledRect(image, frame, min(frame.w / image.w, frame.h / image.h))
        case ImageFit.Cover => scaledRect(image, frame, max(frame.w / image.w, frame.h / image.h))
    }
}

private func scaledRect(image: Size, frame: Rect, scale: Float32): Rect {
    let w = image.w * scale
    let h = image.h * scale
    Rect(frame.centerX() - w / 2.0, frame.centerY() - h / 2.0, w, h)
}
