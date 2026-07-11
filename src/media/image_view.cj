/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.media

import sdl.{Rect, Renderer, Size, Texture, TextureBlendMode, UiEvent}
import cui.core.{UiContext, Widget, emit}

public enum ImageFit {
    | Stretch
    | Contain
    | Cover
}

public class ImageView <: Widget & Resource {
    private let path: String
    private let fit: ImageFit
    private let preferredWidth: ?Float32
    private let preferredHeight: Float32
    private var frame = Rect.zero()
    private var texture: ?Texture = None
    private var closed = false

    public init(
        path: String,
        fit!: ImageFit = ImageFit.Contain,
        preferredWidth!: ?Float32 = None,
        preferredHeight!: Float32 = 96.0
    ) {
        this.path = path
        this.fit = fit
        this.preferredWidth = preferredWidth
        this.preferredHeight = preferredHeight
        emit(this)
    }

    // Without a preferred width an image fills the space it is offered (a full-width block);
    // with one it hugs that box, which is what lets it sit inline beside other controls.
    public func measure(_: UiContext, available: Size): Size {
        let width = match (preferredWidth) {
            case Some(value) => min(available.w, value)
            case None => available.w
        }
        Size(width, min(available.h, preferredHeight))
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (closed) {
            return
        }
        let image = textureFor(ctx.renderer)
        let destination = fittedRect(Size(image.width, image.height), frame, fit)
        match (fit) {
            case ImageFit.Cover =>
                ctx.renderer.setClip(frame)
                ctx.renderer.texture(image, destination)
                ctx.renderer.resetClip()
            case _ => ctx.renderer.texture(image, destination)
        }
    }

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        match (texture) {
            case Some(image) => image.close()
            case None => ()
        }
        texture = None
    }

    private func textureFor(renderer: Renderer): Texture {
        match (texture) {
            case Some(image) => image
            case None =>
                let loaded = renderer.loadTexture(path)
                loaded.setBlendMode(TextureBlendMode.Blend)
                texture = Some(loaded)
                loaded
        }
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
