package cui.core

import sdl.{Rect, Size, UiEvent}

private class FocusMetadataQueryCounter {
    var queries: Int64 = 0
}

private class LegacyFocusMetadataProbe <: Widget {
    private let counter: FocusMetadataQueryCounter

    init(counter: FocusMetadataQueryCounter) {
        this.counter = counter
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        available
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func draw(_: UiContext): Unit {}

    public func handle(_: UiContext, _: UiEvent): Bool {
        false
    }

    public func focusableIds(): Array<String> {
        counter.queries += 1
        ["legacy-focus"]
    }
}

@Test
func automaticRecordDoesNotRecursivelyQueryLegacyFocusMetadata(): Unit {
    let store = StateStore()
    enableAutomaticComposition(store)
    let revision = State<Int64>(0)
    let counter = FocusMetadataQueryCounter()
    let body: () -> Unit = {
        => let _ = revision.value
        LegacyFocusMetadataProbe(counter)
    }

    let _ = buildRoot(body, store)
    revision.value = 1
    let _ = buildRoot(body, store)

    @Expect(counter.queries, Int64(0))
}
