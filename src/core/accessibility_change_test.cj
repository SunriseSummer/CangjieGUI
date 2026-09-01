package cui.core

import std.collection.{ArrayList, HashMap}
import sdl.{Rect, Renderer}

@Test
func semanticDiffReportsReparentingWithoutAFlatIndexChange(): Unit {
    let nodes = [
        semanticChangeNode("left"),
        semanticChangeNode("right"),
        semanticChangeNode("child")
    ]
    let owners = HashMap<String, ElementId>()
    let previous = SemanticsSnapshot(UInt64(1), nodes, owners,
        topology: Some(semanticChangeTopology(0)))
    let nextTopology = semanticChangeTopology(1)

    let changes = semanticsChanges(previous, nodes, owners, nextTopology, "")

    @Expect(hasStableIndexReparent(changes, "child", 2))
}

private class SemanticChangeAdapter <: AccessibilityAdapter {
    let updates = ArrayList<AccessibilityUpdate>()

    public func update(value: AccessibilityUpdate): Unit {
        updates.add(value)
    }
}

@Test
func arenaRevisionInvalidatesStableSemanticContributionTopology(): Unit {
    let arena = ElementArena()
    let parent = arena.mount("semantic-parent-owner", arena.rootId, ElementKind.Automatic)
    let child = arena.mount("semantic-child-owner", parent, ElementKind.Retained)
    let context = UiContext(Renderer.headless(), Theme.light())
    context.registerSemanticContribution(semanticChangeRegistration("parent", parent))
    context.registerSemanticContribution(semanticChangeRegistration("child", child))
    context.commitSemantics(arena: Some(arena))

    let adapter = SemanticChangeAdapter()
    context.setAccessibilityAdapter(adapter)
    @Expect(adapter.updates.size, Int64(1))
    @Expect(adapter.updates[0].snapshot.parent("child").getOrThrow().id, "parent")

    arena.release(child)
    context.commitSemantics(arena: Some(arena))

    @Expect(adapter.updates.size, Int64(2))
    @Expect(adapter.updates[1].snapshot.parent("child").isNone())
    @Expect(hasStableIndexReparent(adapter.updates[1].changes, "child", 1))
}

private func semanticChangeRegistration(id: String, owner: ElementId): SemanticRegistration {
    let bounds = Rect(0.0, 0.0, 10.0, 10.0)
    SemanticRegistration(id, owner, bounds, bounds, [], {=> Semantics(label: id)}, {_ => false}, {=>})
}

private func semanticChangeNode(id: String): SemanticsNode {
    SemanticsNode(id, Semantics(label: id), Rect(0.0, 0.0, 10.0, 10.0))
}

private func semanticChangeTopology(childParent: Int64): SemanticTopology {
    let firstChildren = Array<Int64>(3, repeat: -1)
    let lastChildren = Array<Int64>(3, repeat: -1)
    firstChildren[childParent] = 2
    lastChildren[childParent] = 2
    SemanticTopology(
        [-1, -1, childParent],
        [-1, 0, -1],
        [1, -1, -1],
        firstChildren,
        lastChildren,
        0,
        1
    )
}

private func hasStableIndexReparent(changes: Array<SemanticsChange>, id: String, index: Int64): Bool {
    for (change in changes) {
        match (change) {
            case SemanticsChange.Moved(candidate, previous, next) =>
                if (candidate == id && previous == index && next == index) {
                    return true
                }
            case _ => ()
        }
    }
    false
}
