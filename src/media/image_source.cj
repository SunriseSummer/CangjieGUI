package cui.media

import sdl.{ImageLoadOptions, Surface}
import std.sync.AtomicUInt64

private let IMAGE_MEMORY_ID = AtomicUInt64(UInt64(0))

// The encoded bytes are immutable to callers. File sources do not allocate this object.
private class EncodedImage {
    let bytes: Array<UInt8>
    let hint: String
    init(bytes: Array<UInt8>, hint: String) {
        this.bytes = bytes.clone()
        this.hint = hint
    }
}

/** A reusable static image source: a file path or an immutable snapshot of encoded bytes. */
public struct ImageSource {
    internal let identity: String
    private let encoded: ?EncodedImage

    /** Creates a file source without I/O; throws `IllegalArgumentException` for a NUL path. */
    public init(path: String) {
        if (path.contains("\0")) {
            throw IllegalArgumentException("Image path must not contain NUL")
        }
        identity = path
        encoded = None
    }

    private init(identity: String, encoded: EncodedImage) {
        this.identity = identity
        this.encoded = Some(encoded)
    }

    /**
     * Copies encoded bytes once. Retain and reuse this source across UI rebuilds to share its cache.
     * `typeHint` is optional except for signature-less formats such as TGA. Throws
     * `IllegalArgumentException` for a NUL hint; empty/corrupt bytes become a normal load failure.
     */
    public static func memory(bytes: Array<UInt8>, typeHint!: String = ""): ImageSource {
        if (typeHint.contains("\0")) {
            throw IllegalArgumentException("Image type hint must not contain NUL")
        }
        let id = IMAGE_MEMORY_ID.fetchAdd(UInt64(1))
        ImageSource("\0memory:${id}", EncodedImage(bytes, typeHint))
    }

    internal func load(options: ImageLoadOptions): Surface {
        match (encoded) {
            case Some(value) => Surface.loadBytes(value.bytes, typeHint: value.hint, options: options)
            case None => Surface.load(identity, options: options)
        }
    }

    internal func cacheKey(options: ImageLoadOptions): String {
        if (options.width == 0 && options.height == 0 && options.maxPixels == 67108864) {
            identity
        } else {
            "\0size:${identity.size}:${identity}:${options.width}:${options.height}:${options.maxPixels}"
        }
    }
}
