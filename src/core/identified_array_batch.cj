package cui.core

/* Non-escaping mutable editor for one IdentifiedArray Action batch. */
class IdentifiedArrayUpdateSession<ID, Element> where ID <: Equatable<ID> {
    private let chunks: Array<Array<Element>>
    private let identify: (Element) -> ID
    private let touchedChunks: Array<Bool>

    init(source: Array<Array<Element>>, identify: (Element) -> ID) {
        chunks = source.clone()
        this.identify = identify
        touchedChunks = Array<Bool>(source.size, {_ => false})
    }

    func reduceAt<Action>(
        index: Int64,
        identifiedAction: IdentifiedAction<ID, Action>,
        reducer: (Element, Action) -> Element
    ): Unit {
        let chunkIndex = index / IDENTIFIED_ARRAY_CHUNK_SIZE
        let elementIndex = index % IDENTIFIED_ARRAY_CHUNK_SIZE
        let element = reducer(chunks[chunkIndex][elementIndex], identifiedAction.action)
        if (identify(element) != identifiedAction.id) {
            throw IllegalArgumentException("IdentifiedArray batch updates cannot change identity")
        }
        if (!touchedChunks[chunkIndex]) {
            chunks[chunkIndex] = chunks[chunkIndex].clone()
            touchedChunks[chunkIndex] = true
        }
        chunks[chunkIndex][elementIndex] = element
    }

    func finish(): Array<Array<Element>> {
        chunks
    }
}
