package cui.controls

import std.collection.HashSet
import sdl.{Key, MouseButton, Rect, Renderer, UiEvent}
import cui.core.{State, Theme, UiContext}

private func treeTestContext(): UiContext {
    UiContext(Renderer.headless(), Theme.light())
}

private func sampleRoots(): Array<TreeNode> {
    [
        TreeNode("a", "A", children: [TreeNode("a1", "A1"), TreeNode("a2", "A2")]),
        TreeNode("b", "B", children: [TreeNode("b1", "B1")])
    ]
}

private func expandedSet(ids: Array<String>): HashSet<String> {
    let set = HashSet<String>()
    for (id in ids) {
        set.add(id)
    }
    set
}

private func makeTree(selected: State<String>, expanded: State<HashSet<String>>): TreeView {
    TreeView(sampleRoots(), selected, scroll: Some(State<Float32>(0.0)), expanded: Some(expanded), key: "tree")
}

@Test
func flattenTreeDescendsOnlyIntoExpandedNodes(): Unit {
    let roots = sampleRoots()
    // Nothing expanded: only the two roots are visible.
    @Expect(flattenTree(roots, expandedSet([])).size, 2)
    // Expanding "a" reveals its two children between the roots: a, a1, a2, b.
    let rows = flattenTree(roots, expandedSet(["a"]))
    @Expect(rows.size, 4)
    @Expect(rows[0].id, "a")
    @Expect(rows[1].id, "a1")
    @Expect(rows[2].id, "a2")
    @Expect(rows[3].id, "b")
}

@Test
func flattenTreeMarksDepthAndChildren(): Unit {
    let rows = flattenTree(sampleRoots(), expandedSet(["a"]))
    @Expect(rows[0].depth, 0)
    @Expect(rows[0].hasChildren)
    @Expect(rows[0].expanded)
    @Expect(rows[1].depth, 1)
    @Expect(!rows[1].hasChildren) // a leaf
    // "b" has children but is collapsed, so it is marked expandable yet not expanded.
    @Expect(rows[3].hasChildren)
    @Expect(!rows[3].expanded)
}

@Test
func treeViewClickSelectsRow(): Unit {
    let ctx = treeTestContext()
    let selected = State<String>("")
    let tree = makeTree(selected, State<HashSet<String>>(expandedSet(["a"])))
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 300.0))

    // Rows: 0=a 1=a1 2=a2 3=b. Row 1 (a1) centre is at viewport.y(6)+1*28+14 = 48; click past its chevron column.
    @Expect(tree.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 120.0, 48.0)))
    @Expect(selected.value, "a1")
}

@Test
func treeViewClickChevronTogglesExpansion(): Unit {
    let ctx = treeTestContext()
    let expanded = State<HashSet<String>>(expandedSet(["a"]))
    let tree = makeTree(State<String>(""), expanded)
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 300.0))

    // Row 0 is "a" (depth 0): its chevron sits at x in [10, 28]. Clicking it collapses "a".
    @Expect(tree.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 16.0, 20.0)))
    @Expect(!expanded.value.contains("a"))
    @Expect(expanded.value.contains("a"), false)
}

@Test
func treeViewArrowKeysMoveSelection(): Unit {
    let ctx = treeTestContext()
    let selected = State<String>("")
    let tree = makeTree(selected, State<HashSet<String>>(expandedSet(["a"])))
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 300.0))
    ctx.focus("tree")

    // From no selection, Down lands on the first row; then walks the visible rows.
    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, "a")
    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.Down, false)))
    @Expect(selected.value, "a1")
    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.End, false)))
    @Expect(selected.value, "b")
    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.Home, false)))
    @Expect(selected.value, "a")
    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.Up, false))) // clamps at the top
    @Expect(selected.value, "a")
}

@Test
func treeViewRightExpandsCollapsedNode(): Unit {
    let ctx = treeTestContext()
    let expanded = State<HashSet<String>>(expandedSet([]))
    let tree = makeTree(State<String>("a"), expanded)
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 300.0))
    ctx.focus("tree")

    // "a" is selected and collapsed: Right opens it.
    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(expanded.value.contains("a"))
}

@Test
func treeViewRightDescendsIntoOpenNode(): Unit {
    let ctx = treeTestContext()
    let selected = State<String>("a")
    let tree = makeTree(selected, State<HashSet<String>>(expandedSet(["a"])))
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 300.0))
    ctx.focus("tree")

    // "a" is already open, so Right steps into its first child.
    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(selected.value, "a1")
}

@Test
func treeViewLeftCollapsesOpenNode(): Unit {
    let ctx = treeTestContext()
    let expanded = State<HashSet<String>>(expandedSet(["a"]))
    let tree = makeTree(State<String>("a"), expanded)
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 300.0))
    ctx.focus("tree")

    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(!expanded.value.contains("a"))
}

@Test
func treeViewLeftAscendsFromLeafToParent(): Unit {
    let ctx = treeTestContext()
    let selected = State<String>("a1")
    let tree = makeTree(selected, State<HashSet<String>>(expandedSet(["a"])))
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 300.0))
    ctx.focus("tree")

    // "a1" is a leaf, so Left steps out to its parent "a".
    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.Left, false)))
    @Expect(selected.value, "a")
}

@Test
func treeViewEnterTogglesSelectedNode(): Unit {
    let ctx = treeTestContext()
    let expanded = State<HashSet<String>>(expandedSet([]))
    let tree = makeTree(State<String>("a"), expanded)
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 300.0))
    ctx.focus("tree")

    @Expect(tree.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(expanded.value.contains("a"))
}

@Test
func treeViewIgnoresKeysWhenUnfocused(): Unit {
    let ctx = treeTestContext()
    let expanded = State<HashSet<String>>(expandedSet([]))
    let tree = makeTree(State<String>("a"), expanded)
    tree.layout(ctx, Rect(0.0, 0.0, 240.0, 300.0))
    // No focus: navigation keys are not consumed and nothing expands.
    @Expect(!tree.handle(ctx, UiEvent.KeyDown(Key.Right, false)))
    @Expect(!expanded.value.contains("a"))
}
