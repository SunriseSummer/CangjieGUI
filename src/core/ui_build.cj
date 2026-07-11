/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package cui.core

import sdl.{Rect, Size, UiEvent}
import std.collection.ArrayList

/*
 * Declarative builder support.
 *
 * The UI tree is described with trailing-lambda blocks (see VStack, HStack, Panel).
 * Each concrete widget registers itself with the innermost open block by calling
 * `emit` from its constructor, so a block such as
 *
 *     VStack {
 *         Label("Title")
 *         Button("OK") { => save() }
 *     }
 *
 * collects the Label and Button as the stack's children with no explicit array.
 * Ordinary control flow works inside a block because each statement simply runs:
 *
 *     VStack {
 *         for (row in rows) { buttonRow(row) }
 *         if (expanded) { detailPanel() }
 *     }
 *
 * The stack of open blocks is module-private state. That is safe here: the UI runs on
 * a single thread and the whole tree is rebuilt top to bottom each frame, and every
 * block balances its push and pop through `buildChildren`.
 */
var openBlocks = ArrayList<ArrayList<Widget>>()

/*
 * Register a freshly constructed widget with the enclosing builder block. Every widget
 * constructor calls this. Outside any block (for example a widget built to be stored
 * and reused) it is a no-op, so widgets stay ordinary values. Pass an existing widget
 * to place it explicitly: `VStack { for (w in built) { emit(w) } }`.
 */
public func emit(widget: Widget): Unit {
    if (!openBlocks.isEmpty()) {
        openBlocks[openBlocks.size - 1].add(widget)
    }
}

/*
 * Run a builder block and return every widget it declares, in order.
 */
protected func buildChildren(body: () -> Unit): Array<Widget> {
    let block = ArrayList<Widget>()
    openBlocks.add(block)
    try {
        body()
    } finally {
        openBlocks.remove(at: openBlocks.size - 1)
    }
    block.toArray()
}

/*
 * Run a builder block that wraps a single child. No declaration yields an empty
 * placeholder; several are stacked vertically.
 */
protected func buildChild(body: () -> Unit): Widget {
    let children = buildChildren(body)
    match (children.size) {
        case 0 => EmptyView()
        case 1 => children[0]
        case _ => Stack(Axis.Vertical, children)
    }
}

/*
 * Zero-size filler used where a child is required but none was declared. It never
 * emits, so `buildChild` can create it while an outer block is still open.
 */
class EmptyView <: Widget {
    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }
}
