package cui_desktop_lifecycle_test

import cui.{Label, LazyColumn, LazyList, LazyRow, LengthUnits, ListView, MouseButton, Rect, ScrollView, SdlWindow,
    State, Table, TableColumn, TextArea, TreeNode, TreeView, VStack, Widget, WidgetTestHost, WindowSpec, UiEvent}

// Exercise every scrolling control inside a parent viewport using the real layout/event/
// rebuild/draw transaction and a native renderer. Table deliberately keeps its offset private:
// the parent's observable movement still proves whether the child consumed the wheel.
func verifyScrolling(): Bool {
    for (sampling in [Int32(1), Int32(2)]) {
        try (window = SdlWindow(WindowSpec("Nested scroll E2E", 320, 180, supersample: sampling), hidden: true)) {
            for (kind in 0..8) {
                let host = WidgetTestHost(renderer: window.renderer)
                let outer = State<Float32>(0.0)
                let inner = State<Float32>(0.0)
                let selected = State<Int64>(-1)
                let text = State<String>(String(Array<Rune>(120, {i => if (i % 4 == 3) { r'\n' } else { r'x' }})))
                let treeSelection = State<String>("")
                let bounds = Rect(0.0, 0.0, 320.0, 180.0)
                let view: () -> Unit = {
                    => ScrollView(key: "outer") {
                        VStack {
                            nestedScrollControl(kind, inner, selected, text, treeSelection).height(90.vp)
                            Label("tail").height(300.vp)
                        }.spacing(0.0).hug()
                    }.scrollState(outer)
                    ()
                }
                try {
                    let _ = host.frame(bounds, body: view)
                    let _ = host.frame(bounds, events: [UiEvent.MouseDown(MouseButton.Right, 305.0, 75.0),
                        UiEvent.MouseUp(MouseButton.Right, 305.0, 75.0)], body: view)
                    if (inner.value != 0.0 || outer.value != 0.0 || !host.context.dragId.isEmpty()) { return false }
                    let _ = host.frame(bounds, events: [UiEvent.MouseWheel(0.0, -1.0, 25.0, 45.0)], body: view)
                    if (outer.value != 0.0) { return false }
                    let _ = host.frame(bounds, events: [UiEvent.MouseWheel(0.0, -1000.0, 25.0, 45.0)], body: view)
                    if (outer.value != 0.0) { return false }
                    let _ = host.frame(bounds, events: [UiEvent.MouseWheel(0.0, -1.0, 25.0, 45.0)], body: view)
                    if (outer.value != 72.0) { return false }
                } finally { host.reset() }
            }
        }
    }
    true
}

private func nestedScrollControl(kind: Int64, scroll: State<Float32>, selected: State<Int64>, text: State<String>,
    treeSelection: State<String>): Widget {
    match (kind) {
        case 0 => ScrollView(key: "inner") { Label("content").height(900.vp) }.scrollState(scroll)
        case 1 => LazyColumn(30, 30.0, scroll: scroll, id: "inner") {i => Label("row ${i}")}
        case 2 => LazyList(30, {_ => Float32(30.0)}, scroll: scroll, id: "inner") {i => Label("row ${i}")}
        case 3 => LazyRow(30, 60.0, scroll: scroll, id: "inner") {i => Label("row ${i}")}
        case 4 => ListView(Array<String>(30, {i => "row ${i}"}), selected, scroll: scroll, key: "inner")
        case 5 => TreeView(Array<TreeNode>(30, {i => TreeNode("${i}", "row ${i}")}), treeSelection,
            scroll: scroll, key: "inner")
        case 6 => Table([TableColumn("Header", 300.0)], Array<Array<String>>(30, {i => ["row ${i}"]}), selected,
            key: "inner")
        case _ => TextArea(text, scroll: scroll, key: "inner")
    }
}
