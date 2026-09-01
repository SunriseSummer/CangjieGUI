package cui.media

/** A snapshot of the image-texture cache owned by the calling UI thread. */
public struct ImageCacheStats {
    public let hits: UInt64
    public let misses: UInt64
    public let loadFailures: UInt64
    public let evictions: UInt64
    public let entries: Int64
    public let estimatedBytes: UInt64
    public let maxEntries: Int64
    public let maxBytes: UInt64
    public let rendererChanges: UInt64
    public let oversizedAdmissions: UInt64

    public init(
        hits: UInt64,
        misses: UInt64,
        loadFailures: UInt64,
        evictions: UInt64,
        entries: Int64,
        estimatedBytes: UInt64,
        maxEntries: Int64,
        maxBytes: UInt64,
        rendererChanges: UInt64,
        oversizedAdmissions: UInt64
    ) {
        this.hits = hits
        this.misses = misses
        this.loadFailures = loadFailures
        this.evictions = evictions
        this.entries = entries
        this.estimatedBytes = estimatedBytes
        this.maxEntries = maxEntries
        this.maxBytes = maxBytes
        this.rendererChanges = rendererChanges
        this.oversizedAdmissions = oversizedAdmissions
    }
}
