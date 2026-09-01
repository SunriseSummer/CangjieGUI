package cui.testing

import sdl.Rect
import cui.core.{Label, ModelStore, Panel, ScopedStore, VStack, structuralEqualityPolicy}

private class ScopedHostModel {
    let left: Int64
    let right: Int64

    init(left: Int64, right: Int64) {
        this.left = left
        this.right = right
    }
}

private class ScopedHostAction {
    let left: Bool
    let amount: Int64

    init(left: Bool, amount: Int64) {
        this.left = left
        this.amount = amount
    }
}

private class ScopedHostScene {
    let store: ModelStore<ScopedHostModel, ScopedHostAction>
    let left: ScopedStore<Int64, Int64>
    let right: ScopedStore<Int64, Int64>
    var leftBuilds: Int64 = 0
    var rightBuilds: Int64 = 0

    init() {
        store = ModelStore<ScopedHostModel, ScopedHostAction>(
            ScopedHostModel(0, 0),
            update: {
                model, action => if (action.left) {
                    ScopedHostModel(model.left + action.amount, model.right)
                } else {
                    ScopedHostModel(model.left, model.right + action.amount)
                }
            }
        )
        left = store.scope<Int64, Int64>(
            state: {model => model.left},
            action: {amount => ScopedHostAction(true, amount)},
            policy: structuralEqualityPolicy<Int64>()
        )
        right = store.scope<Int64, Int64>(
            state: {model => model.right},
            action: {amount => ScopedHostAction(false, amount)},
            policy: structuralEqualityPolicy<Int64>()
        )
    }

    func build(): Unit {
        VStack {
            Panel {
                leftBuilds += 1
                Label("left ${left.get()}")
            }
            Panel {
                rightBuilds += 1
                Label("right ${right.get()}")
            }
        }
    }
}

@Test
func scopedStorePolicyRebuildsOnlyTheChangedFeatureBranch(): Unit {
    let scene = ScopedHostScene()
    let host = WidgetTestHost()
    let rect = Rect(0.0, 0.0, 240.0, 100.0)
    let _ = host.frame(rect) {scene.build()}

    scene.left.dispatch(1)
    let _ = host.frame(rect) {scene.build()}

    @Expect(scene.leftBuilds, Int64(2))
    @Expect(scene.rightBuilds, Int64(1))
    @Expect(scene.store.get().left, Int64(1))
    @Expect(scene.store.get().right, Int64(0))
}
