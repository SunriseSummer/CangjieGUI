package cui.core

import sdl.{Rect, Renderer, Size}

func scaledContext(): UiContext {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    ctx.displayScale = 2.0
    ctx.fontScale = 1.5
    ctx
}

@Test
func uiContextResolvesEachUnitAgainstItsScale(): Unit {
    let ctx = scaledContext()

    @Expect(ctx.resolve(100.px), Float32(50.0))
    @Expect(ctx.resolve(100.vp), Float32(100.0))
    @Expect(ctx.resolve(10.fp), Float32(15.0))
    @Expect(ctx.resolve(1.5.vp), Float32(1.5))
}

@Test
func lengthLiteralsSupportScalarArithmetic(): Unit {
    let ctx = scaledContext()

    @Expect(ctx.resolve(16.vp * 2.0), Float32(32.0))
    @Expect(ctx.resolve(24.vp / 2.0), Float32(12.0))
    @Expect(Length.zero().value, Float32(0.0))
}

@Test
func lengthInsetsResolveEdges(): Unit {
    let ctx = scaledContext()
    let insets = ctx.resolve(LengthInsets(10.vp, 4.px))

    @Expect(insets.horizontal(), Float32(20.0))
    @Expect(insets.vertical(), Float32(4.0))
}

@Test
func sizeModifiersResolveUnitsAtLayoutTime(): Unit {
    let ctx = scaledContext()
    let probe = SizedLayoutProbe(Size(10.0, 10.0))
    let view = VStack {
        emit(probe)
        probe.width(100.px).height(40.vp)
    }

    view.layout(ctx, Rect(0.0, 0.0, 300.0, 100.0))

    @Expect(probe.rect.w, Float32(50.0))
    @Expect(probe.rect.h, Float32(40.0))
}

@Test
func paddingModifierResolvesPhysicalPixels(): Unit {
    let ctx = scaledContext()
    let decorated = SizedLayoutProbe(Size(40.0, 20.0)).padding(10.px)
    let measured = decorated.measure(ctx, Size(200.0, 100.0))

    @Expect(measured.w, Float32(50.0))
    @Expect(measured.h, Float32(30.0))
}

@Test
func stackSpacingAcceptsUnitLengths(): Unit {
    let ctx = scaledContext()
    let first = SizedLayoutProbe(Size(40.0, 20.0))
    let second = SizedLayoutProbe(Size(40.0, 20.0))
    let view = VStack(spacing: 24.px) {
        emit(first)
        emit(second)
    }.crossAxisAlignment(CrossAxisAlignment.Start)

    view.layout(ctx, Rect(0.0, 0.0, 120.0, 100.0))

    @Expect(second.rect.y, Float32(32.0))
}

// The headless renderer measures text deterministically (bytes * pointSize * 0.55),
// which lets truncation and wrapping be asserted exactly.
@Test
func labelTextFittingEllipsizesAndWraps(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())

    @Expect(ellipsize(ctx, "abcdefghij", 30.0, 10.0), "ab…")
    @Expect(ellipsize(ctx, "abc", 30.0, 10.0), "abc")

    let lines = wrapText(ctx, "aaa bbb ccc", 30.0, 10.0, 3)
    @Expect(lines.size, 3)
    @Expect(lines[0], "aaa")
    @Expect(lines[1], "bbb")
    @Expect(lines[2], "ccc")
}

// Multi-line measure reports the widest wrapped line (cached alongside the lines). Guards the
// widest-width cache: a warm re-measure must return the same value, never the unset 0, and the
// wrapped width must sit below the single-line width of the same text (wrapping narrows it).
@Test
func labelMultiLineMeasureReportsCachedWidestLine(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let label = Label("aaa bbb ccc").maxLines(3)

    // Narrow width forces the three words onto separate lines; the reported width is one word's.
    let first = label.measure(ctx, Size(30.0, 200.0))
    @Expect(first.w > 0.0, true)
    // A second pass hits the line cache and must agree (the widest is cached, not recomputed to 0).
    @Expect(label.measure(ctx, Size(30.0, 200.0)).w, first.w)

    // The same text on one line is wider than any single wrapped word, proving measure returns the
    // widest wrapped line rather than the full-text width.
    let singleLine = Label("aaa bbb ccc")
    @Expect(first.w < singleLine.measure(ctx, Size(1000.0, 200.0)).w, true)
}

@Test
func controlIdentityIsUniquePerBuildAndStableAcrossBuilds(): Unit {
    let store = StateStore()
    let first = State<String>("")
    let second = State<String>("")

    let _ = buildRoot(
        {
            =>
                first.value = controlIdentity("IconButton")
                second.value = controlIdentity("IconButton")
                Spacer()
        },
        store
    )
    let firstBuildA = first.value
    let firstBuildB = second.value

    let _ = buildRoot(
        {
            =>
                first.value = controlIdentity("IconButton")
                second.value = controlIdentity("IconButton")
                Spacer()
        },
        store
    )

    @Expect(firstBuildA != firstBuildB)
    @Expect(first.value, firstBuildA)
    @Expect(second.value, firstBuildB)
}

@Test
func keyedScopesNamespaceControlIdentity(): Unit {
    let store = StateStore()
    let inFirst = State<String>("")
    let inSecond = State<String>("")

    let _ = buildRoot({
        => VStack {
            Keyed("first") {
                inFirst.value = controlIdentity("Button:确定")
                Spacer()
            }
            Keyed("second") {
                inSecond.value = controlIdentity("Button:确定")
                Spacer()
            }
        }
    }, store)

    @Expect(inFirst.value != inSecond.value)
}
