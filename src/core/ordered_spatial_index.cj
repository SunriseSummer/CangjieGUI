package cui.core

import sdl.Rect

/*
 * One contiguous declaration/z-order segment in a balanced AABB aggregation tree. Bounds combine
 * by rectangle union, an associative operation; `hasUnbounded` preserves compatibility leaves that
 * may observe any point. Event routing and committed semantics share this algebra while keeping
 * their traversal result types specialized and allocation-free.
 */
struct OrderedSpatialNode {
    let begin: Int64
    let end: Int64
    let left: Int64
    let right: Int64
    let bounds: Rect
    let hasBounds: Bool
    let hasUnbounded: Bool

    init(
        begin: Int64,
        end: Int64,
        left: Int64,
        right: Int64,
        bounds: Rect,
        hasBounds: Bool,
        hasUnbounded: Bool
    ) {
        this.begin = begin
        this.end = end
        this.left = left
        this.right = right
        this.bounds = bounds
        this.hasBounds = hasBounds
        this.hasUnbounded = hasUnbounded
    }

    func isLeaf(): Bool {
        end - begin == 1
    }
}

func orderedSpatialBranch(
    begin: Int64,
    end: Int64,
    left: Int64,
    right: Int64,
    leftNode: OrderedSpatialNode,
    rightNode: OrderedSpatialNode
): OrderedSpatialNode {
    OrderedSpatialNode(begin, end, left, right, combinedOrderedBounds(leftNode, rightNode),
        leftNode.hasBounds || rightNode.hasBounds, leftNode.hasUnbounded || rightNode.hasUnbounded)
}

private func combinedOrderedBounds(left: OrderedSpatialNode, right: OrderedSpatialNode): Rect {
    if (!left.hasBounds) {
        return right.bounds
    }
    if (!right.hasBounds) {
        return left.bounds
    }
    let x = min(left.bounds.x, right.bounds.x)
    let y = min(left.bounds.y, right.bounds.y)
    let rightEdge = max(left.bounds.right(), right.bounds.right())
    let bottomEdge = max(left.bounds.bottom(), right.bounds.bottom())
    Rect(x, y, rightEdge - x, bottomEdge - y)
}
