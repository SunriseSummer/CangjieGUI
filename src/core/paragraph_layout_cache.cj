package cui.core

import std.collection.HashMap
import std.deriving.*
import sdl.{FontStyle, Fonts}

private let DEFAULT_PARAGRAPH_CACHE_BYTES: Int64 = 4 * 1024 * 1024
private let PARAGRAPH_ENTRY_OVERHEAD: Int64 = 128

/** Process-local paragraph-layout cache counters exposed through `UiContext`. */
public struct ParagraphCacheStats {
    public let hits: UInt64
    public let misses: UInt64
    public let entries: Int64
    public let bytes: Int64
    public let evictions: UInt64

    public init(hits: UInt64, misses: UInt64, entries: Int64, bytes: Int64, evictions: UInt64) {
        this.hits = hits
        this.misses = misses
        this.entries = entries
        this.bytes = bytes
        this.evictions = evictions
    }
}

@Derive[Equatable, Hashable]
internal struct ParagraphCacheKey {
    let text: String
    let widthBits: UInt32
    let pointSizeBits: UInt32
    let styleFlags: Int32
    let font: String
    let fontRevision: UInt64
    let maxLines: Int64

    init(text: String, width: Float32, pointSize: Float32, style: FontStyle, font: ?String, maxLines: Int64) {
        this.text = text
        this.widthBits = width.toBits()
        this.pointSizeBits = pointSize.toBits()
        this.styleFlags = style.ttfFlags()
        this.font = match (font) {
            case Some(value) => value
            case None => ""
        }
        this.fontRevision = Fonts.revision()
        this.maxLines = maxLines
    }
}

private class ParagraphCacheEntry {
    let key: ParagraphCacheKey
    let layout: ParagraphLayout
    let weight: Int64
    var previous: ?ParagraphCacheEntry = None
    var next: ?ParagraphCacheEntry = None

    init(key: ParagraphCacheKey, layout: ParagraphLayout, weight: Int64) {
        this.key = key
        this.layout = layout
        this.weight = weight
    }
}

/*
 * A byte-budgeted true LRU. Paragraph strings vary by orders of magnitude, so an entry-count cap
 * permits one huge document to dominate memory. Keys retain the immutable input String rather than
 * concatenate it into another key; the derived value key supplies collision-safe equality.
 */
internal class ParagraphLayoutCache {
    private let byteBudget: Int64
    private let entries = HashMap<ParagraphCacheKey, ParagraphCacheEntry>()
    private var head: ?ParagraphCacheEntry = None
    private var tail: ?ParagraphCacheEntry = None
    private var byteCount: Int64 = 0
    private var hitCount: UInt64 = 0
    private var missCount: UInt64 = 0
    private var evictionCount: UInt64 = 0

    init(byteBudget!: Int64 = DEFAULT_PARAGRAPH_CACHE_BYTES) {
        this.byteBudget = max(0, byteBudget)
    }

    func getOrCompute(
        text: String,
        width: Float32,
        pointSize: Float32,
        maxLines: Int64,
        style: FontStyle,
        font: ?String,
        compute: () -> ParagraphLayout
    ): ParagraphLayout {
        let key = ParagraphCacheKey(text, width, pointSize, style, font, maxLines)
        match (entries.get(key)) {
            case Some(entry) =>
                hitCount += 1
                promote(entry)
                return entry.layout
            case None => missCount += 1
        }
        let layout = compute()
        let weight = entryWeight(text, layout)
        if (weight > byteBudget || byteBudget == 0) {
            return layout
        }
        let entry = ParagraphCacheEntry(key, layout, weight)
        entries[key] = entry
        linkFirst(entry)
        byteCount += weight
        trimToBudget()
        layout
    }

    func stats(): ParagraphCacheStats {
        ParagraphCacheStats(hitCount, missCount, entries.size, byteCount, evictionCount)
    }

    func resetStats(): Unit {
        hitCount = 0
        missCount = 0
        evictionCount = 0
    }

    private func promote(entry: ParagraphCacheEntry): Unit {
        match (head) {
            case Some(value) where refEq(value, entry) => return
            case _ => ()
        }
        unlink(entry)
        linkFirst(entry)
    }

    private func linkFirst(entry: ParagraphCacheEntry): Unit {
        entry.previous = None
        entry.next = head
        match (head) {
            case Some(value) => value.previous = Some(entry)
            case None => tail = Some(entry)
        }
        head = Some(entry)
    }

    private func unlink(entry: ParagraphCacheEntry): Unit {
        match (entry.previous) {
            case Some(value) => value.next = entry.next
            case None => head = entry.next
        }
        match (entry.next) {
            case Some(value) => value.previous = entry.previous
            case None => tail = entry.previous
        }
        entry.previous = None
        entry.next = None
    }

    private func trimToBudget(): Unit {
        while (byteCount > byteBudget) {
            let victim = match (tail) {
                case Some(value) => value
                case None => return
            }
            unlink(victim)
            entries.remove(victim.key)
            byteCount -= victim.weight
            evictionCount += 1
        }
    }
}

private func entryWeight(text: String, layout: ParagraphLayout): Int64 {
    var bytes = text.size + PARAGRAPH_ENTRY_OVERHEAD
    for (line in layout.lines) {
        bytes += line.size
    }
    bytes
}
