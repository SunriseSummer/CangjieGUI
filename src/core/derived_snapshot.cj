package cui.core

/* One initial value together with the exact source preimage from which it was computed. */
class DerivedInitialComputation<T> {
    let value: T
    let sourceRevisions: Array<UInt64>
    let stateWriteEpoch: UInt64

    init(value: T, sourceRevisions: Array<UInt64>, stateWriteEpoch: UInt64) {
        this.value = value
        this.sourceRevisions = sourceRevisions
        this.stateWriteEpoch = stateWriteEpoch
    }
}

/*
 * State-backed reads are thread-confined and their projection functions are required to be pure,
 * so revision/value pairs may be sampled in one source-order traversal. Capturing the process epoch
 * before the traversal makes a write inside a getter or compute visible to the next pull.
 */
func initialStateBackedComputation<A, T>(
    sources: Array<Observable<A>>,
    compute: (Array<A>) -> T
): DerivedInitialComputation<T> {
    initialComputation(sources.size, {index => observableValueRevisionSnapshot(sources[index])}, compute)
}

func initialStateComputation<A, T>(
    sources: Array<State<A>>,
    compute: (Array<A>) -> T
): DerivedInitialComputation<T> {
    initialComputation(sources.size, {index => sources[index].valueRevisionSnapshot()}, compute)
}

private func initialComputation<A, T>(
    sourceCount: Int64,
    snapshot: (Int64) -> (A, UInt64),
    compute: (Array<A>) -> T
): DerivedInitialComputation<T> {
    let stateWriteEpoch = currentStateGeneration()
    let revisions = Array<UInt64>(sourceCount, repeat: UInt64(0))
    let values = Array<A>(
        sourceCount,
        {
            index =>
                let (value, revision) = snapshot(index)
                revisions[index] = revision
                value
        }
    )
    DerivedInitialComputation<T>(compute(values), revisions, stateWriteEpoch)
}

func observableValueRevisionSnapshot<T>(source: Observable<T>): (T, UInt64) {
    match (source as State<T>) {
        case Some(state) => state.valueRevisionSnapshot()
        case None => match (source as Binding<T>) {
            case Some(binding) => binding.valueRevisionSnapshot()
            case None =>
                let revision = source.revision
                (source.get(), revision)
        }
    }
}
