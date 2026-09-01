package cui.core

import sdl.{Rect, Size, UiEvent}

/**
 * Gives a subtree stable declarative identity. Local `rememberState` keys are namespaced
 * beneath this value, so repeated components can use the same internal state names.
 */
public class Keyed <: Widget {
    private let child: Widget

    public init(key: String, body!: () -> Unit) {
        child = buildKeyedChild(key, body)
        emit(this)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        child.measure(ctx, available)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        child.layout(ctx, rect)
    }

    public func draw(ctx: UiContext): Unit {
        child.draw(ctx)
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        child.handle(ctx, event)
    }

    public func pointerEventScope(): PointerEventScope {
        child.pointerEventScope()
    }

    public func paintOutset(): PaintOutset {
        child.paintOutset()
    }

    public func isFlexible(): Bool {
        child.isFlexible()
    }

    public func flexWeight(): Float32 {
        child.flexWeight()
    }

    public func acceptsStretch(axis: Axis): Bool {
        child.acceptsStretch(axis)
    }

    public func participatesInLayout(): Bool {
        // Forwarded so `.visible(false)` inside ForEach leaves no stray spacing gap.
        child.participatesInLayout()
    }

    public func needsDetachedLayout(): Bool {
        child.needsDetachedLayout()
    }

    public func focusableId(): ?String {
        child.focusableId()
    }

    public func focusableIds(): Array<String> {
        child.focusableIds()
    }
}

/**
 * Declares one keyed subtree per item. `key` must be unique and stable per item, so
 * local state and control identity follow an item through reorders and removals:
 *
 *     ForEach(tasks, key: {task => task.id}) {task => taskRow(task)}
 */
public func ForEach<T>(items: Iterable<T>, key!: (T) -> String, body!: (T) -> Unit): Unit {
    for (item in items) {
        Keyed(key(item)) {
            body(item)
        }
    }
}

/**
 * Declares one keyed subtree per item using the position as identity. Prefer `ForEach`
 * with a stable key when items can be inserted, removed or reordered.
 */
public func ForEachIndexed<T>(items: Iterable<T>, body!: (Int64, T) -> Unit): Unit {
    var index: Int64 = 0
    for (item in items) {
        let position = index
        Keyed("${position}") {
            body(position, item)
        }
        index += 1
    }
}
