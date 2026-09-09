package cui.media

/** Original preserves source colors; Template replaces RGB with the foreground while preserving alpha. */
public enum IconRenderingMode {
    | Original
    | Template
}

/** One application-provided square raster representation, with its actual canvas extent in pixels. */
public struct IconVariant {
    public let source: ImageSource
    public let pixels: Int32

    /** Throws `IllegalArgumentException` unless pixels is positive. No image is read here. */
    public init(source: ImageSource, pixels: Int32) {
        if (pixels <= 0) {
            throw IllegalArgumentException("Icon variant pixels must be positive")
        }
        this.source = source
        this.pixels = pixels
    }

    /** File convenience constructor; the same pixel and path validation applies. */
    public init(path: String, pixels: Int32) {
        this(ImageSource(path), pixels)
    }
}

private class IconRepresentations {
    let values: Array<IconVariant>
    /** Throws `IllegalArgumentException` for an empty table or duplicate raster extents. */
    init(values: Array<IconVariant>) {
        if (values.isEmpty()) {
            throw IllegalArgumentException("Icon variants must not be empty")
        }
        for (i in 0..values.size) {
            for (j in 0..i) {
                if (values[i].pixels == values[j].pixels) {
                    throw IllegalArgumentException("Icon variants must have distinct pixel extents")
                }
            }
        }
        this.values = values.clone()
    }
}

/**
 * Immutable caller-owned icon media and color intent, reusable in Icon, IconButton, RichSpan and
 * TreeNode. No built-in artwork, file probing, texture allocation or image decoding on construction.
 */
public struct IconSource {
    public let image: ImageSource
    public let renderingMode: IconRenderingMode
    private let representations: ?IconRepresentations

    /** Reuses an image source. Template is the default for foreground-colored action icons. */
    public init(image: ImageSource, renderingMode!: IconRenderingMode = IconRenderingMode.Template) {
        this.image = image
        this.renderingMode = renderingMode
        representations = None
    }

    /** File convenience constructor; NUL paths throw `IllegalArgumentException`. */
    public init(path: String, renderingMode!: IconRenderingMode = IconRenderingMode.Template) {
        this(ImageSource(path), renderingMode: renderingMode)
    }

    private init(image: ImageSource, mode: IconRenderingMode, representations: ?IconRepresentations) {
        this.image = image
        this.renderingMode = mode
        this.representations = representations
    }

    /** Copies encoded bytes once; keep this source outside rebuilt view bodies to share the cache. */
    public static func memory(bytes: Array<UInt8>, typeHint!: String = "",
        renderingMode!: IconRenderingMode = IconRenderingMode.Template): IconSource {
        IconSource(ImageSource.memory(bytes, typeHint: typeHint), renderingMode: renderingMode)
    }

    /**
     * Copies the variant table, not the image bytes. Selects the smallest sufficient square raster,
     * or the largest when all are smaller. Throws `IllegalArgumentException` for empty/duplicate sizes.
     */
    public static func variants(values: Array<IconVariant>,
        renderingMode!: IconRenderingMode = IconRenderingMode.Template): IconSource {
        let choices = IconRepresentations(values)
        IconSource(values[0].source, renderingMode, Some(choices))
    }

    /** Changes color intent while retaining image identities and the immutable variant table. */
    public func withRenderingMode(value: IconRenderingMode): IconSource {
        IconSource(image, value, representations)
    }

    internal func select(pixels: Int32): ImageSource {
        if (let Some(choices) <- representations) {
            var best = choices.values[0]
            for (choice in choices.values) {
                if ((choice.pixels >= pixels && (best.pixels < pixels || choice.pixels < best.pixels)) || (best.pixels <
                    pixels && choice.pixels > best.pixels)) {
                    best = choice
                }
            }
            return best.source
        }
        image
    }

    internal func invalidate(): Unit {
        if (let Some(choices) <- representations) {
            for (choice in choices.values) {
                invalidateImage(choice.source)
            }
        } else {
            invalidateImage(image)
        }
    }
}

/** Drops every size and color-mode cache variant of this icon on the owning UI thread. */
public func invalidateIcon(source: IconSource): Unit {
    source.invalidate()
}
