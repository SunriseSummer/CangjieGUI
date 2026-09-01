package cui.testing

import std.collection.ArrayList
import sdl.Rect
import cui.core.{AccessibilityAdapter, AccessibilityUpdate, Button, Label, RetainedSubtree, ScrollView,
    Semantics, SemanticsAction, SemanticsChange, SemanticsNode, SemanticsRole, Spacer, State, VStack, ZStack}
import cui.controls.Checkbox
import cui.text.TextField

@Test
func semanticsNodeRejectsEmptyIdentity(): Unit {
    var rejected = false
    try {
        let _ = SemanticsNode("", Semantics(label: "invalid"), Rect.zero())
    } catch (error: IllegalArgumentException) {
        rejected = error.message == "Semantics id must not be empty"
    }
    @Expect(rejected)
}

@Test
func semanticSnapshotExposesBuiltInRolesAndActions(): Unit {
    let host = WidgetTestHost()
    let activations = State<Int64>(0)
    let rect = Rect(0.0, 0.0, 240.0, 100.0)

    let _ = host.frame(rect) {
        Label("状态")
        Button("保存", {=> activations.value += 1}).key("save")
    }

    let save = semanticNode(host.context.semanticsSnapshot(), "save")
    @Expect(isButtonRole(save.properties.role))
    @Expect(save.properties.label, "保存")
    @Expect(host.context.performSemanticsAction("save", SemanticsAction.Activate))
    @Expect(activations.value, Int64(1))
}

@Test
func disabledSemanticModifierSurvivesRetainedLayoutReplay(): Unit {
    let host = WidgetTestHost()
    let rect = Rect(0.0, 0.0, 200.0, 60.0)
    let body: () -> Unit = {
        => RetainedSubtree("semantic-cache") {
            Spacer()
                .semantics(Semantics(label: "图表", role: SemanticsRole.Image), key: "chart")
                .enabled(false)
        }
    }

    let _ = host.frame(rect, body: body)
    let first = semanticNode(host.context.semanticsSnapshot(), "chart")
    @Expect(!first.properties.enabled)

    let _ = host.frame(rect, body: body)
    let replayed = semanticNode(host.context.semanticsSnapshot(), "chart")
    @Expect(!replayed.properties.enabled)
    @Expect(replayed.bounds.w, Float32(200.0))
}

@Test
func semanticActionsDriveCheckboxAndTextFieldBindings(): Unit {
    let host = WidgetTestHost()
    let checked = State<Bool>(false)
    let text = State<String>("old")
    let rect = Rect(0.0, 0.0, 280.0, 100.0)
    let body: () -> Unit = {
        =>
            Checkbox("同步", checked).key("sync")
            TextField(text, key: "name")
    }

    let _ = host.frame(rect, body: body)
    @Expect(host.context.performSemanticsAction("sync", SemanticsAction.Activate))
    @Expect(host.context.performSemanticsAction("name", SemanticsAction.SetValue("new")))
    @Expect(checked.value)
    @Expect(text.value, "new")

    let _ = host.frame(rect, body: body)
    let checkbox = semanticNode(host.context.semanticsSnapshot(), "sync")
    let field = semanticNode(host.context.semanticsSnapshot(), "name")
    @Expect(checkbox.properties.checked.getOrThrow())
    @Expect(field.properties.value, "new")
}

private class AccessibilityAdapterProbe <: AccessibilityAdapter {
    let updates = ArrayList<AccessibilityUpdate>()

    public func update(value: AccessibilityUpdate): Unit {
        updates.add(value)
    }
}

private class FailingAccessibilityAdapter <: AccessibilityAdapter {
    public func update(value: AccessibilityUpdate): Unit {
        if (!value.snapshot.nodes.isEmpty()) {
            throw IllegalStateException("adapter failed")
        }
    }
}

@Test
func accessibilityAdapterReceivesAtomicIndexedTreePatches(): Unit {
    let host = WidgetTestHost()
    let adapter = AccessibilityAdapterProbe()
    let title = State<String>("Alpha")
    let reversed = State<Bool>(false)
    let showAlpha = State<Bool>(true)
    let activations = State<Int64>(0)
    let rect = Rect(0.0, 0.0, 280.0, 100.0)
    let body: () -> Unit = {=> emitAccessibilityPatchButtons(title, reversed, showAlpha, activations)}

    host.context.setAccessibilityAdapter(adapter)
    @Expect(adapter.updates.size, Int64(1))
    @Expect(adapter.updates[0].snapshot.nodes.size, Int64(0))

    let _ = host.frame(rect, body: body)
    @Expect(adapter.updates.size, Int64(2))
    let added = adapter.updates[1]
    @Expect(added.snapshot.revision, UInt64(1))
    @Expect(added.snapshot.node("alpha").isSome())
    @Expect(countAddedChanges(added.changes), Int64(2))
    @Expect(added.performAction("alpha", SemanticsAction.Activate))
    @Expect(activations.value, Int64(1))

    let _ = host.frame(rect, body: body)
    @Expect(adapter.updates.size, Int64(2))

    title.value = "Alpha updated"
    reversed.value = true
    let _ = host.frame(rect, body: body)
    @Expect(adapter.updates.size, Int64(3))
    let changed = adapter.updates[2]
    @Expect(changed.previousRevision, UInt64(1))
    @Expect(changed.snapshot.revision, UInt64(2))
    // Reordering the vertical children changes both bounds; Alpha also changes its label.
    @Expect(countUpdatedChanges(changed.changes), Int64(2))
    @Expect(countMovedChanges(changed.changes), Int64(2))

    showAlpha.value = false
    let _ = host.frame(rect, body: body)
    @Expect(adapter.updates.size, Int64(4))
    let removed = adapter.updates[3]
    @Expect(countRemovedChanges(removed.changes), Int64(1))
    @Expect(removed.snapshot.node("alpha").isNone())
    @Expect(!removed.performAction("alpha", SemanticsAction.Activate))
}

@Test
func accessibilityAdapterCommitsFocusEvenWhenSemanticPropertiesStayStable(): Unit {
    let host = WidgetTestHost()
    let adapter = AccessibilityAdapterProbe()
    let body: () -> Unit = {=> Button("Focus target", {=>}).key("focus-commit")}
    host.context.setAccessibilityAdapter(adapter)
    let _ = host.frame(Rect(0.0, 0.0, 200.0, 50.0), body: body)
    @Expect(adapter.updates.size, Int64(2))

    host.context.focus("focus-commit")
    let _ = host.frame(Rect(0.0, 0.0, 200.0, 50.0), body: body)
    @Expect(adapter.updates.size, Int64(3))
    let focused = adapter.updates[2]
    @Expect(focused.snapshot.focusedId, "focus-commit")
    @Expect(focused.snapshot.revision, UInt64(2))
    @Expect(countFocusChanges(focused.changes), Int64(1))
}

private func emitAccessibilityPatchButtons(
    title: State<String>,
    reversed: State<Bool>,
    showAlpha: State<Bool>,
    activations: State<Int64>
): Unit {
    if (reversed.value) {
        Button("Beta", {=>}).key("beta")
        if (showAlpha.value) {
            Button(title.value, {=> activations.value += 1}).key("alpha")
        }
    } else {
        if (showAlpha.value) {
            Button(title.value, {=> activations.value += 1}).key("alpha")
        }
        Button("Beta", {=>}).key("beta")
    }
}

@Test
func semanticProviderStateInvalidationProducesPatchWithoutTopologyChange(): Unit {
    let host = WidgetTestHost()
    let adapter = AccessibilityAdapterProbe()
    let checked = State<Bool>(false)
    let body: () -> Unit = {=> Checkbox("Indexed", checked).key("indexed")}
    host.context.setAccessibilityAdapter(adapter)

    let _ = host.frame(Rect(0.0, 0.0, 200.0, 50.0), body: body)
    @Expect(adapter.updates.size, Int64(2))
    let first = adapter.updates[1].snapshot.node("indexed").getOrThrow()
    @Expect(!first.properties.checked.getOrThrow())

    // The provider reads checked only while semantics commits; the retained layout fragment stays identical.
    checked.value = true
    let _ = host.frame(Rect(0.0, 0.0, 200.0, 50.0), body: body)
    @Expect(adapter.updates.size, Int64(3))
    @Expect(countUpdatedChanges(adapter.updates[2].changes), Int64(1))
    let updated = adapter.updates[2].snapshot.node("indexed").getOrThrow()
    @Expect(updated.properties.checked.getOrThrow())
}

@Test
func failingAccessibilityAdapterDetachesWithoutLosingCommittedTree(): Unit {
    let host = WidgetTestHost()
    host.context.setAccessibilityAdapter(FailingAccessibilityAdapter())
    var failed = false
    try {
        let _ = host.frame(Rect(0.0, 0.0, 200.0, 50.0)) {Button("Recover", {=>}).key("recover")}
    } catch (error: IllegalStateException) {
        failed = error.message == "adapter failed"
    }
    @Expect(failed)

    let replacement = AccessibilityAdapterProbe()
    host.context.setAccessibilityAdapter(replacement)
    @Expect(replacement.updates.size, Int64(1))
    @Expect(replacement.updates[0].snapshot.node("recover").isSome())
}

@Test
func semanticPointQueryUsesTopmostOrderAndSnapshotIsolation(): Unit {
    let host = WidgetTestHost()
    let reversed = State<Bool>(false)
    let body: () -> Unit = {
        => ZStack {
            if (reversed.value) {
                Button("Front", {=>}).key("front")
                Button("Back", {=>}).key("back")
                ()
            } else {
                Button("Back", {=>}).key("back")
                Button("Front", {=>}).key("front")
                ()
            }
        }
    }
    let rect = Rect(0.0, 0.0, 120.0, 40.0)
    let _ = host.frame(rect, body: body)
    let first = host.context.semanticsTreeSnapshot()
    @Expect(first.nodeAt(10.0, 10.0).getOrThrow().id, "front")
    @Expect(first.nodeAt(200.0, 10.0).isNone())

    reversed.value = true
    let _ = host.frame(rect, body: body)
    let second = host.context.semanticsTreeSnapshot()
    @Expect(second.nodeAt(10.0, 10.0).getOrThrow().id, "back")
    @Expect(first.nodeAt(10.0, 10.0).getOrThrow().id, "front")
}

@Test
func semanticSnapshotProjectsElementAncestryIntoConstantTimeNavigation(): Unit {
    let host = WidgetTestHost()
    let _ = host.frame(Rect(0.0, 0.0, 240.0, 100.0)) {
        VStack {
            Button("Alpha", {=>}).key("alpha")
            Button("Beta", {=>}).key("beta")
        }.semantics(Semantics(label: "Actions", role: SemanticsRole.List), key: "actions")
    }

    let snapshot = host.context.semanticsTreeSnapshot()
    @Expect(snapshot.firstRootChild().getOrThrow().id, "actions")
    @Expect(snapshot.lastRootChild().getOrThrow().id, "actions")
    @Expect(snapshot.parent("alpha").getOrThrow().id, "actions")
    @Expect(snapshot.parent("beta").getOrThrow().id, "actions")
    @Expect(snapshot.firstChild("actions").getOrThrow().id, "alpha")
    @Expect(snapshot.lastChild("actions").getOrThrow().id, "beta")
    @Expect(snapshot.nextSibling("alpha").getOrThrow().id, "beta")
    @Expect(snapshot.previousSibling("beta").getOrThrow().id, "alpha")
    @Expect(snapshot.previousSibling("alpha").isNone())
    @Expect(snapshot.nextSibling("beta").isNone())
}

@Test
func focusedSemanticQueryClearsWithUnmountedOwner(): Unit {
    let host = WidgetTestHost()
    let shown = State<Bool>(true)
    let body: () -> Unit = {
        => if (shown.value) {
            Button("Focus", {=>}).key("focus-target")
            ()
        } else {
            Spacer()
            ()
        }
    }
    let rect = Rect(0.0, 0.0, 120.0, 40.0)
    let _ = host.frame(rect, body: body)
    host.context.focus("focus-target")
    @Expect(host.context.focusedSemanticsNode().getOrThrow().id, "focus-target")

    shown.value = false
    let _ = host.frame(rect, body: body)
    @Expect(host.context.focusedSemanticsNode().isNone())
}

@Test
func semanticPointQueryUsesScrollViewportVisibleBounds(): Unit {
    let host = WidgetTestHost()
    let rect = Rect(0.0, 0.0, 120.0, 40.0)
    let _ = host.frame(rect) {
        ScrollView(key: "semantic-clip") {
            VStack(flexible: false) {
                Button("First", {=>}).key("first")
                Button("Second", {=>}).key("second")
            }.spacing(0.0)
        }
    }

    let snapshot = host.context.semanticsTreeSnapshot()
    let second = snapshot.node("second").getOrThrow()
    @Expect(second.bounds.bottom() > rect.bottom())
    @Expect(second.visibleBounds.bottom(), rect.bottom())
    @Expect(snapshot.nodeAt(10.0, 39.0).getOrThrow().id, "second")
    @Expect(snapshot.nodeAt(10.0, 50.0).isNone())
}

@Test
func semanticVisibleBoundsTracksAncestorClipAcrossRetainedLayoutHit(): Unit {
    let host = WidgetTestHost()
    let body: () -> Unit = {
        => ScrollView(key: "resized-semantic-clip") {
            VStack(flexible: false) {
                Button("First", {=>}).key("resized-first")
                Button("Second", {=>}).key("resized-second")
            }.spacing(0.0)
        }
    }

    let _ = host.frame(Rect(0.0, 0.0, 120.0, 40.0), body: body)
    let clipped = host.context.semanticsTreeSnapshot().node("resized-second").getOrThrow()
    @Expect(clipped.visibleBounds.bottom(), Float32(40.0))

    let _ = host.frame(Rect(0.0, 0.0, 120.0, 60.0), body: body)
    let expanded = host.context.semanticsTreeSnapshot().node("resized-second").getOrThrow()
    @Expect(expanded.bounds.bottom() > clipped.visibleBounds.bottom())
    @Expect(expanded.visibleBounds.bottom(), Float32(60.0))
}


private func semanticNode(nodes: Array<SemanticsNode>, id: String): SemanticsNode {
    for (node in nodes) {
        if (node.id == id) {
            return node
        }
    }
    throw IllegalStateException("Missing semantic node '${id}'")
}

func isButtonRole(role: SemanticsRole): Bool {
    match (role) {
        case SemanticsRole.Button => true
        case _ => false
    }
}

private func countAddedChanges(changes: Array<SemanticsChange>): Int64 {
    var count: Int64 = 0
    for (change in changes) {
        match (change) {
            case SemanticsChange.Added(_) => count += 1
            case _ => ()
        }
    }
    count
}

private func countRemovedChanges(changes: Array<SemanticsChange>): Int64 {
    var count: Int64 = 0
    for (change in changes) {
        match (change) {
            case SemanticsChange.Removed(_) => count += 1
            case _ => ()
        }
    }
    count
}

private func countUpdatedChanges(changes: Array<SemanticsChange>): Int64 {
    var count: Int64 = 0
    for (change in changes) {
        match (change) {
            case SemanticsChange.Updated(_) => count += 1
            case _ => ()
        }
    }
    count
}

private func countMovedChanges(changes: Array<SemanticsChange>): Int64 {
    var count: Int64 = 0
    for (change in changes) {
        match (change) {
            case SemanticsChange.Moved(_, _, _) => count += 1
            case _ => ()
        }
    }
    count
}

private func countFocusChanges(changes: Array<SemanticsChange>): Int64 {
    var count: Int64 = 0
    for (change in changes) {
        match (change) {
            case SemanticsChange.FocusChanged(_, _) => count += 1
            case _ => ()
        }
    }
    count
}
