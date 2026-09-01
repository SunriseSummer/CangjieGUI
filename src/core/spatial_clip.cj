package cui.core

import sdl.Rect

/*
 * One phase-independent clip policy. Visibility is shared by layout semantics and pointer gating;
 * paint may conservatively extend across the non-scrolling axis for shadows. Composition is the
 * component-wise rectangle intersection, so nested clips form a meet-semilattice with no ordering
 * ambiguity.
 */
struct SpatialClip {
    let visibleBounds: Rect
    let paintBounds: Rect

    init(visibleBounds: Rect, paintBounds: Rect) {
        this.visibleBounds = visibleBounds
        this.paintBounds = paintBounds
    }

    func intersect(other: SpatialClip): SpatialClip {
        SpatialClip(visibleBounds.intersection(other.visibleBounds), paintBounds.intersection(other.paintBounds))
    }

    func contains(x: Float32, y: Float32): Bool {
        visibleBounds.contains(x, y)
    }
}

func exactSpatialClip(bounds: Rect): SpatialClip {
    SpatialClip(bounds, bounds)
}

func verticalViewportSpatialClip(bounds: Rect, outset: PaintOutset): SpatialClip {
    let horizontal = outset.horizontalOnly()
    SpatialClip(bounds, horizontal.expand(bounds))
}

func horizontalViewportSpatialClip(bounds: Rect, outset: PaintOutset): SpatialClip {
    let vertical = outset.verticalOnly()
    SpatialClip(bounds, vertical.expand(bounds))
}

func sameOptionalSpatialRect(left: ?Rect, right: ?Rect): Bool {
    match ((left, right)) {
        case (Some(leftValue), Some(rightValue)) => sameAutomaticRect(leftValue, rightValue)
        case (None, None) => true
        case _ => false
    }
}

extend UiContext {
    /* Applies a compositional visibility clip while layout registers semantics. */
    func withSpatialClip<T>(clip: SpatialClip, body: () -> T): T {
        let previous = spatialClip
        spatialClip = Some(match (previous) {
            case Some(value) => value.intersect(clip)
            case None => clip
        })
        try {
            body()
        } finally {
            spatialClip = previous
        }
    }

    /* Balances the renderer clip even when a child draw callback throws. */
    func drawWithinSpatialClip<T>(clip: SpatialClip, body: () -> T): T {
        renderer.pushClip(clip.paintBounds)
        try {
            withSpatialClip(clip, body)
        } finally {
            renderer.popClip()
        }
    }

    func currentSpatialVisibility(): ?Rect {
        match (spatialClip) {
            case Some(value) => Some(value.visibleBounds)
            case None => None
        }
    }

    func currentSpatialPaintBounds(): ?Rect {
        match (spatialClip) {
            case Some(value) => Some(value.paintBounds)
            case None => None
        }
    }
}
