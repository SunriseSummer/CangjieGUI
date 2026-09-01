package cui.media

import sdl.{Renderer, SdlException, Texture, TextureBlendMode}
import std.sync.{AtomicReference, AtomicUInt64}

private let DEFAULT_IMAGE_CACHE_ENTRIES: Int64 = 256
private let DEFAULT_IMAGE_CACHE_BYTES: UInt64 = UInt64(128 * 1024 * 1024)
private let IMAGE_CACHE_ENTRY_OVERHEAD: UInt64 = UInt64(128)
private let IMAGE_CACHE_FAST_SLOT_COUNT: Int64 = 256

/*
 * Renderer-owned textures are thread-affine, so each UI thread keeps an independent cache. This
 * removes the former process-wide data race and prevents two DesktopApps on different threads from
 * repeatedly clearing each other's entries. A thread normally has one active renderer; switching
 * it closes the previous renderer's wrappers before adopting the new one.
 */
internal class ImageTextureCache {
    private var renderer: ?Renderer = None
    private let textures: BoundedResourceCache<Texture>
    private var hits: UInt64 = UInt64(0)
    private var misses: UInt64 = UInt64(0)
    private var loadFailures: UInt64 = UInt64(0)
    private var rendererChanges: UInt64 = UInt64(0)
    private var observedRevision: UInt64

    init(
        maxEntries!: Int64 = DEFAULT_IMAGE_CACHE_ENTRIES,
        maxBytes!: UInt64 = DEFAULT_IMAGE_CACHE_BYTES
    ) {
        textures = BoundedResourceCache<Texture>(maxEntries, maxBytes, {texture => texture.close()})
        observedRevision = currentImageCacheRevision()
    }

    func texture(activeRenderer: Renderer, path: String): ?Texture {
        refreshInvalidatedEntries()
        adoptRenderer(activeRenderer)
        match (textures.lookup(path)) {
            case Some(entry) => match (entry.cached) {
                case Some(cached) =>
                    if (!cached.isClosed()) {
                        hits += UInt64(1)
                        return Some(cached)
                    }
                    let _ = textures.remove(path) // cjcheck-ignore: ignore-result # lookup proved this stale entry exists
                case None =>
                    hits += UInt64(1)
                    return None
            }
            case None => ()
        }

        misses += UInt64(1)
        let loaded = decodeTexture(activeRenderer, path)
        textures.put(path, loaded, imageEntryWeight(path, loaded))
        loaded
    }

    func invalidate(path: String): Bool {
        textures.remove(path)
    }

    func clearEntries(): Unit {
        textures.clear()
        renderer = None
    }

    func cachedEntry(path: String): ?BoundedResourceCacheEntry<Texture> {
        textures.lookup(path)
    }

    func recordFastHit(entry: BoundedResourceCacheEntry<Texture>): Unit {
        hits += UInt64(1)
        entry.recentlyUsed = true
    }

    func acceptRevision(revision: UInt64): Unit {
        observedRevision = revision
    }

    func stats(): ImageCacheStats {
        ImageCacheStats(
            hits,
            misses,
            loadFailures,
            textures.evictionCount(),
            textures.size(),
            textures.estimatedBytes(),
            textures.maxEntries(),
            textures.maxBytes(),
            rendererChanges,
            textures.oversizedAdmissionCount()
        )
    }

    func refreshedStats(): ImageCacheStats {
        refreshInvalidatedEntries()
        stats()
    }

    private func adoptRenderer(activeRenderer: Renderer): Unit {
        match (renderer) {
            case Some(current) =>
                if (!refEq(current, activeRenderer)) {
                    textures.clear()
                    renderer = Some(activeRenderer)
                    rendererChanges += UInt64(1)
                }
            case None => renderer = Some(activeRenderer)
        }
    }

    private func refreshInvalidatedEntries(): Unit {
        let revision = currentImageCacheRevision()
        if (revision != observedRevision) {
            textures.clear()
            renderer = None
            observedRevision = revision
        }
    }

    private func decodeTexture(activeRenderer: Renderer, path: String): ?Texture {
        // A missing/corrupt file or headless renderer is a recoverable draw result. Cache the
        // failure, expose it in stats, and let unrelated exceptions propagate.
        try {
            let loaded = activeRenderer.loadTexture(path)
            try {
                loaded.setBlendMode(TextureBlendMode.Blend)
                Some(loaded)
            } catch (_: SdlException) {
                loaded.close()
                loadFailures += UInt64(1)
                None
            }
        } catch (_: SdlException) {
            loadFailures += UInt64(1)
            None
        }
    }
}

private let THREAD_IMAGE_CACHE = ThreadLocal<ImageTextureCache>()
private let IMAGE_CACHE_REVISION = AtomicUInt64(UInt64(0))

internal class ImageCacheFastSlot {
    let renderer: Renderer
    let entry: BoundedResourceCacheEntry<Texture>
    let owner: ImageTextureCache
    let revision: UInt64

    init(
        renderer: Renderer,
        entry: BoundedResourceCacheEntry<Texture>,
        owner: ImageTextureCache,
        revision: UInt64
    ) {
        this.renderer = renderer
        this.entry = entry
        this.owner = owner
        this.revision = revision
    }
}

private let EMPTY_CACHED_TEXTURE: ?Texture = None
private let EMPTY_IMAGE_CACHE_FAST_SLOT = ImageCacheFastSlot(
    Renderer.headless(),
    BoundedResourceCacheEntry<Texture>("", EMPTY_CACHED_TEXTURE, UInt64(0)),
    ImageTextureCache(),
    UInt64.Max
)
private let IMAGE_CACHE_FAST_SLOTS = Array<AtomicReference<ImageCacheFastSlot>>(
    IMAGE_CACHE_FAST_SLOT_COUNT,
    {_ => AtomicReference<ImageCacheFastSlot>(EMPTY_IMAGE_CACHE_FAST_SLOT)}
)

// Returns the cached texture for `path`, loading and caching it (or the failure) on first use.
protected func sharedTexture(renderer: Renderer, path: String): ?Texture {
    sharedTextureAtRevision(renderer, path, currentImageCacheRevision())
}

/* ImageView already reads the revision for its local fast path, so avoid a second atomic load. */
protected func sharedTextureAtRevision(renderer: Renderer, path: String, revision: UInt64): ?Texture {
    sharedImageSlotAtRevision(renderer, path, revision).entry.cached
}

/*
 * Returns the immutable resolution slot so a stable ImageView only retains one cache field.
 * Throws `IllegalStateException` only if a just-inserted private cache entry disappears.
 */
internal func sharedImageSlotAtRevision(renderer: Renderer, path: String, revision: UInt64): ImageCacheFastSlot {
    let slotIndex = path.hashCode() & (IMAGE_CACHE_FAST_SLOT_COUNT - Int64(1))
    let fast = IMAGE_CACHE_FAST_SLOTS[slotIndex].load()
    if (fast.revision == revision && refEq(fast.renderer, renderer) && fast.entry.active && fast.entry.key == path) {
        match (fast.entry.cached) {
            case Some(texture) =>
                if (!texture.isClosed()) {
                    fast.owner.recordFastHit(fast.entry)
                    return fast
                }
            case None =>
                fast.owner.recordFastHit(fast.entry)
                return fast
        }
    }

    let cache = currentImageCache()
    let _ = cache.texture(renderer, path) // cjcheck-ignore: ignore-result # the cache entry below owns the resolved value
    match (cache.cachedEntry(path)) {
        case Some(entry) =>
            let resolved = ImageCacheFastSlot(renderer, entry, cache, revision)
            IMAGE_CACHE_FAST_SLOTS[slotIndex].store(resolved)
            resolved
        case None => throw IllegalStateException("Media cache lost a newly resolved image entry")
    }
}

private func currentImageCache(): ImageTextureCache {
    match (THREAD_IMAGE_CACHE.get()) {
        case Some(cache) => cache
        case None =>
            let cache = ImageTextureCache()
            THREAD_IMAGE_CACHE.set(Some(cache))
            cache
    }
}

/* ImageView uses this cheap version read to keep a resolved texture locally until invalidation. */
protected func currentImageCacheRevision(): UInt64 {
    IMAGE_CACHE_REVISION.load()
}

private func advanceImageCacheRevision(): UInt64 {
    let previous = IMAGE_CACHE_REVISION.fetchAdd(UInt64(1))
    if (previous == UInt64.Max) {
        UInt64(0)
    } else {
        previous + UInt64(1)
    }
}

private func imageEntryWeight(path: String, texture: ?Texture): UInt64 {
    let metadataBytes = saturatedMediaAdd(IMAGE_CACHE_ENTRY_OVERHEAD, UInt64(max(Int64(0), path.size)))
    match (texture) {
        case Some(value) =>
            let width = UInt64(max(Int64(0), Int64(value.width)))
            let height = UInt64(max(Int64(0), Int64(value.height)))
            let pixelCount = width * height
            let pixelBytes = if (pixelCount > UInt64.Max / UInt64(4)) {
                UInt64.Max
            } else {
                pixelCount * UInt64(4)
            }
            saturatedMediaAdd(metadataBytes, pixelBytes)
        case None => metadataBytes
    }
}

/** Returns image-cache counters and limits for the calling UI thread. */
public func imageCacheStats(): ImageCacheStats {
    match (THREAD_IMAGE_CACHE.get()) {
        case Some(cache) => cache.refreshedStats()
        case None => emptyImageCacheStats()
    }
}

/**
 * Drops `path` from the calling UI thread's cache, closing a loaded texture. Its next draw reloads
 * from disk. Call this after overwriting an image, including one whose earlier load failed.
 */
public func invalidateImage(path: String): Unit {
    let revision = advanceImageCacheRevision()
    match (THREAD_IMAGE_CACHE.get()) {
        case Some(cache) =>
            let _ = cache.invalidate(path) // cjcheck-ignore: ignore-result # invalidating an absent path is intentionally idempotent
            cache.acceptRevision(revision)
        case None => ()
    }
}

/** Closes and removes every image cached by the calling UI thread; future draws start fresh. */
public func clearImageCache(): Unit {
    let _ = advanceImageCacheRevision() // cjcheck-ignore: ignore-result # the revision change is the cross-thread invalidation signal
    match (THREAD_IMAGE_CACHE.get()) {
        case Some(cache) => cache.clearEntries()
        case None => ()
    }
    let empty: ?ImageTextureCache = None
    THREAD_IMAGE_CACHE.set(empty)
}

private func emptyImageCacheStats(): ImageCacheStats {
    ImageCacheStats(
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        Int64(0),
        UInt64(0),
        DEFAULT_IMAGE_CACHE_ENTRIES,
        DEFAULT_IMAGE_CACHE_BYTES,
        UInt64(0),
        UInt64(0)
    )
}
