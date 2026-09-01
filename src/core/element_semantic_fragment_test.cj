package cui.core

import sdl.{Rect, Renderer}

@Test
func emptyElementLayoutCommitReplaysNoSemanticContribution(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    let commit = ElementLayoutCommit(
        Rect(0.0, 0.0, 20.0, 10.0),
        None,
        PaintOutset(),
        context.uiEnvironmentKey(),
        ElementLayoutEffects(None<OverlaySnapshot>, None<SemanticFragment>)
    )

    @Expect(context.semanticRegistrationCount(), Int64(0))
    commit.replay(context)
    @Expect(context.semanticRegistrationCount(), Int64(0))
    @Expect(context.semanticFragmentIfAnyFrom(0).isNone())
}

@Test
func nonEmptyElementLayoutCommitReplaysOneSemanticFragment(): Unit {
    let context = UiContext(Renderer.headless(), Theme.light())
    context.registerSemantics(
        SemanticsNode("fragment-child", Semantics(label: "Child", role: SemanticsRole.Button),
            Rect(0.0, 0.0, 20.0, 10.0))
    )
    let fragment = context.semanticFragmentIfAnyFrom(0)
    @Expect(fragment.isSome())
    context.clearSemantics()

    let commit = ElementLayoutCommit(
        Rect(0.0, 0.0, 20.0, 10.0),
        None,
        PaintOutset(),
        context.uiEnvironmentKey(),
        ElementLayoutEffects(None<OverlaySnapshot>, fragment)
    )
    commit.replay(context)
    @Expect(context.semanticRegistrationCount(), Int64(1))
    context.commitSemantics()
    @Expect(context.semanticsTreeSnapshot().node("fragment-child").isSome())
}
