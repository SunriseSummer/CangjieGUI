package cui.core

import std.collection.HashSet
import sdl.{Key, MouseButton, Rect, Size, UiEvent}

private func intSet(values: Array<Int64>): HashSet<Int64> {
    let set = HashSet<Int64>()
    for (value in values) {
        set.add(value)
    }
    set
}

// A leaf reporting a fixed focus id, so the accordion's focus order can be inspected.
private class AccFocusProbe <: Widget {
    private let id: String

    init(id: String) {
        this.id = id
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }
}

@Test
func accordionBuildsOnlyOpenBodies(): Unit {
    let counter = LazyBuildCounter()
    let acc = Accordion([
        AccordionSection("A") {=> counter.bump(); emit(Spacer())},
        AccordionSection("B") {=> counter.bump(); emit(Spacer())},
        AccordionSection("C") {=> counter.bump(); emit(Spacer())}
    ], expanded: State<HashSet<Int64>>(intSet([1])))
    // Only section 1 is open, so only its body builder ran.
    @Expect(counter.count, 1)
    @Expect(acc.focusableIds().size >= 3, true) // three headers at least
}

@Test
func accordionMeasureSumsHeadersAndOpenBodies(): Unit {
    let ctx = testContext()
    let acc = Accordion([
        AccordionSection("A") {=> emit(SizedLayoutProbe(Size(100.0, 50.0)))},
        AccordionSection("B") {=> emit(Spacer())}
    ], expanded: State<HashSet<Int64>>(intSet([0])))
    // header(42) + open body(50) + header(42); section B is collapsed and contributes nothing.
    @Expect(acc.measure(ctx, Size(300.0, 1000.0)).h, Float32(134.0))
}

@Test
func accordionClickHeaderTogglesSection(): Unit {
    let ctx = testContext()
    let expanded = State<HashSet<Int64>>(intSet([]))
    let acc = Accordion([
        AccordionSection("A") {=> emit(Spacer())},
        AccordionSection("B") {=> emit(Spacer())}
    ], expanded: expanded)
    acc.layout(ctx, Rect(0.0, 0.0, 300.0, 400.0))

    // Header 0 spans y 0..42; a click on it opens the section.
    @Expect(acc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 20.0)))
    @Expect(expanded.value.contains(0))
    // A second click closes it again.
    let _ = acc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 20.0))
    @Expect(!expanded.value.contains(0))
}

@Test
func accordionSingleModeClosesOthersOnOpen(): Unit {
    let ctx = testContext()
    let expanded = State<HashSet<Int64>>(intSet([0]))
    let acc = Accordion([
        AccordionSection("A") {=> emit(SizedLayoutProbe(Size(100.0, 50.0)))},
        AccordionSection("B") {=> emit(SizedLayoutProbe(Size(100.0, 50.0)))},
        AccordionSection("C") {=> emit(SizedLayoutProbe(Size(100.0, 50.0)))}
    ], single: true, expanded: expanded)
    acc.layout(ctx, Rect(0.0, 0.0, 300.0, 600.0))

    // Header 1 sits below header 0 (42) and open body 0 (50), at y 92..134.
    @Expect(acc.handle(ctx, UiEvent.MouseDown(MouseButton.Left, 150.0, 110.0)))
    @Expect(expanded.value.contains(1))
    @Expect(!expanded.value.contains(0)) // single mode closed the previously open section
}

@Test
func accordionKeyboardTogglesFocusedHeader(): Unit {
    let ctx = testContext()
    let expanded = State<HashSet<Int64>>(intSet([]))
    let acc = Accordion([
        AccordionSection("A") {=> emit(Spacer())},
        AccordionSection("B") {=> emit(Spacer())}
    ], expanded: expanded, key: "acc")
    acc.layout(ctx, Rect(0.0, 0.0, 300.0, 400.0))
    ctx.focus("Accordion:acc:header:1")

    @Expect(acc.handle(ctx, UiEvent.KeyDown(Key.Enter, false)))
    @Expect(expanded.value.contains(1))
    @Expect(acc.handle(ctx, UiEvent.KeyDown(Key.Space, false)))
    @Expect(!expanded.value.contains(1)) // Space toggles it back
}

@Test
func accordionFocusOrderInterleavesHeadersAndOpenBodies(): Unit {
    let acc = Accordion([
        AccordionSection("A") {=> emit(AccFocusProbe("bodyA"))},
        AccordionSection("B") {=> emit(Spacer())}
    ], expanded: State<HashSet<Int64>>(intSet([0])), key: "acc")

    let ids = acc.focusableIds()
    // header 0, then its open body's stop, then header 1 (its body is collapsed).
    @Expect(ids.size, 3)
    @Expect(ids[0], "Accordion:acc:header:0")
    @Expect(ids[1], "bodyA")
    @Expect(ids[2], "Accordion:acc:header:1")
}
