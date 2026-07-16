package cui.core

import sdl.{MouseButton, Rect, Size, UiEvent}

// Drives a full drag on a fresh list: press the handle of `from` (rows are 40px tall, no spacing), move
// the pointer to `toY`, release. Returns the recorded "from->to" the onMove callback saw (empty if none).
private func dragRow(from: Int64, toY: Float32): String {
    let ctx = testContext()
    ctx.leftMouseDown = true
    let moved = State<String>("")
    let list = ReorderableList(4, 40.0, {a, b => moved.value = "${a}->${b}"}, spacing: 0.0, id: "rl") {
        _ => emit(Spacer())
    }
    list.layout(ctx, Rect(0.0, 0.0, 300.0, 200.0))
    let pressY = Float32(from) * 40.0 + 15.0
    let _ = list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 15.0, pressY)) // grip is the left 30px
    let _ = list.handle(ctx, UiEvent.MouseMove(15.0, toY))
    let _ = list.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 15.0, toY))
    moved.value
}

@Test
func reorderableBuildsAllRowsNotWindowed(): Unit {
    let counter = LazyBuildCounter()
    let list = ReorderableList(5, 40.0, {_, _ => ()}, id: "rl.all") {
        _ =>
        counter.bump()
        emit(Spacer())
    }
    @Expect(counter.count, 5) // every row is built (a reorderable list is not virtualized)
    @Expect(list.measure(testContext(), Size(200.0, 400.0)).w, Float32(200.0))
}

@Test
func reorderableMeasureIsContentHeight(): Unit {
    let ctx = testContext()
    let list = ReorderableList(4, 40.0, {_, _ => ()}, spacing: 6.0, id: "rl.m") {
        _ => emit(Spacer())
    }
    // 4 rows of 40 with three 6px gaps between them.
    @Expect(list.measure(ctx, Size(300.0, 500.0)).h, Float32(178.0))
}

@Test
func reorderableDragDownMovesItem(): Unit {
    // Grab row 0, drag it down over row 3, drop → move 0 to 3.
    @Expect(dragRow(0, 130.0), "0->3")
}

@Test
func reorderableDragUpMovesItem(): Unit {
    // Grab row 3, drag it to the top → move 3 to 0.
    @Expect(dragRow(3, 5.0), "3->0")
}

@Test
func reorderableDropOnSameSlotIsNoOp(): Unit {
    // Grab row 1 and barely move it — the drop index stays 1, so nothing is committed.
    @Expect(dragRow(1, 62.0), "")
}

@Test
func reorderableContentPressDoesNotDrag(): Unit {
    let ctx = testContext()
    ctx.leftMouseDown = true
    let moved = State<String>("")
    let list = ReorderableList(4, 40.0, {a, b => moved.value = "${a}->${b}"}, spacing: 0.0, id: "rl.c") {
        _ => emit(Spacer())
    }
    list.layout(ctx, Rect(0.0, 0.0, 300.0, 200.0))
    // A press to the right of the grip (x=100) is not a drag; the Spacer content does not consume it.
    @Expect(!list.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 100.0, 20.0)))
    let _ = list.handle(ctx, UiEvent.MouseMove(100.0, 150.0))
    let _ = list.handle(ctx, UiEvent.MouseUp(MouseButton.Left, 100.0, 150.0))
    @Expect(model_unchanged(moved))
}

private func model_unchanged(moved: State<String>): Bool {
    moved.value == ""
}
