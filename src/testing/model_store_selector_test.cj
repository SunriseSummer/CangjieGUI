package cui.testing

import sdl.Rect
import cui.core.{DerivedState, Label, ModelStore, Panel, VStack, structuralEqualityPolicy}

private class SelectorHostModel {
    let count: Int64
    let text: String

    init(count: Int64, text: String) {
        this.count = count
        this.text = text
    }
}

private class SelectorHostScene {
    let store: ModelStore<SelectorHostModel, Int64>
    let count: DerivedState<Int64>
    let text: DerivedState<String>
    var countBuilds: Int64 = 0
    var textBuilds: Int64 = 0

    init(distinct: Bool) {
        store = ModelStore<SelectorHostModel, Int64>(
            SelectorHostModel(0, "stable"),
            update: {model, delta => SelectorHostModel(model.count + delta, model.text)}
        )
        if (distinct) {
            count = store.select<Int64>({model => model.count}, policy: structuralEqualityPolicy<Int64>())
            text = store.select<String>({model => model.text}, policy: structuralEqualityPolicy<String>())
        } else {
            count = store.select<Int64>({model => model.count})
            text = store.select<String>({model => model.text})
        }
    }

    func build(): Unit {
        VStack {
            Panel {
                countBuilds += 1
                Label("count ${count.value}")
            }
            Panel {
                textBuilds += 1
                Label(text.value)
            }
        }
    }
}

@Test
func modelStoreDistinctSelectorInvalidatesOnlyChangedProjection(): Unit {
    let rect = Rect(0.0, 0.0, 240.0, 100.0)
    let plainHost = WidgetTestHost()
    let plain = SelectorHostScene(false)
    let _ = plainHost.frame(rect) {plain.build()}
    plain.store.dispatch(1)
    let _ = plainHost.frame(rect) {plain.build()}

    let distinctHost = WidgetTestHost()
    let distinct = SelectorHostScene(true)
    let _ = distinctHost.frame(rect) {distinct.build()}
    distinct.store.dispatch(1)
    let _ = distinctHost.frame(rect) {distinct.build()}

    @Expect(plain.countBuilds, Int64(2))
    @Expect(plain.textBuilds, Int64(2))
    @Expect(distinct.countBuilds, Int64(2))
    @Expect(distinct.textBuilds, Int64(1))
}
