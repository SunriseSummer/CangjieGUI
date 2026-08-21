package cui.media

import std.collection.HashMap
import sdl.{Renderer, Texture, TextureBlendMode}

/*
 * Process-wide image texture cache, keyed by file path and scoped to one renderer (the single
 * window a `DesktopApp` drives). `ImageView` declares images inline in the per-frame rebuild;
 * lookups hit this cache instead of the disk, so no hoisting or manual resource management is
 * needed. Entries live until explicitly invalidated — desktop apps use a small, stable set of
 * images, and an eviction policy would trade a bounded texture pool for disk churn. A failed
 * load is cached as `None` so a missing file is not retried every frame; call `invalidateImage`
 * after (re)writing the file to retry. UI-thread only, like the rest of the framework.
 */
private var cacheRenderer: ?Renderer = None // cjcheck-ignore: global-var # UI-thread-only module cache owner (see file comment)
private let cachedTextures = HashMap<String, ?Texture>()

// Returns the cached texture for `path`, loading and caching it (or the failure) on first use.
protected func sharedTexture(renderer: Renderer, path: String): ?Texture {
    adoptRenderer(renderer)
    match (cachedTextures.get(path)) {
        case Some(entry) => entry
        case None =>
            let loaded = decodeTexture(renderer, path)
            cachedTextures[path] = loaded
            loaded
    }
}

// Textures are only valid on the renderer that created them. When a different renderer shows
// up (a recreated window), the stale entries are dropped WITHOUT closing: SDL destroyed them
// together with their renderer, and closing again would touch freed handles.
private func adoptRenderer(renderer: Renderer): Unit {
    match (cacheRenderer) {
        case Some(existing) =>
            if (!refEq(existing, renderer)) {
                cachedTextures.clear()
                cacheRenderer = Some(renderer)
            }
        case None => cacheRenderer = Some(renderer)
    }
}

private func decodeTexture(renderer: Renderer, path: String): ?Texture {
    // A missing or corrupt file (or a headless renderer) must not throw out of draw and kill
    // the frame loop; the failure is cached so the disk is not retried every frame.
    try {
        let texture = renderer.loadTexture(path)
        texture.setBlendMode(TextureBlendMode.Blend)
        Some(texture)
    } catch (_: Exception) {
        None
    }
}

/**
 * Drops the cached texture for `path` (closing it); the next draw reloads from disk. Call
 * this after overwriting an image file — including one whose earlier load failed.
 */
public func invalidateImage(path: String): Unit {
    match (cachedTextures.get(path)) {
        case Some(Some(texture)) => texture.close()
        case _ => ()
    }
    let _ = cachedTextures.remove(path) // cjcheck-ignore: ignore-result # the removed entry was already closed above; a miss means nothing to invalidate
}

/** Empties the image cache, closing every cached texture; images reload on next draw. */
public func clearImageCache(): Unit {
    for ((_, entry) in cachedTextures) {
        match (entry) {
            case Some(texture) => texture.close()
            case None => ()
        }
    }
    cachedTextures.clear()
}
