package cui.core

/**
 * Defines observational equivalence for State mutations or derived results. Implementations must
 * be deterministic, fast, and free of side effects.
 */
public interface StateMutationPolicy<T> {
    /** Returns true when `current` is in the same observational equivalence class as `previous`. */
    func equivalent(previous: T, current: T): Bool

    /** Pulls this equivalence relation back along one pure projection. */
    func pullback<S>(project: (S) -> T): StateMutationPolicy<S> {
        PulledBackStateMutationPolicy<S, T>(this, project)
    }
}

private class PulledBackStateMutationPolicy<S, T> <: StateMutationPolicy<S> {
    private let target: StateMutationPolicy<T>
    private let project: (S) -> T

    init(target: StateMutationPolicy<T>, project: (S) -> T) {
        this.target = target
        this.project = project
    }

    public func equivalent(previous: S, current: S): Bool {
        target.equivalent(project(previous), project(current))
    }
}

private class StructuralEqualityStatePolicy<T> <: StateMutationPolicy<T> where T <: Equatable<T> {
    public func equivalent(previous: T, current: T): Bool {
        previous == current
    }
}

private class NeverEqualStatePolicy<T> <: StateMutationPolicy<T> {
    public func equivalent(_: T, _: T): Bool {
        false
    }
}

private class ClosureStateMutationPolicy<T> <: StateMutationPolicy<T> {
    private let compare: (T, T) -> Bool

    init(compare: (T, T) -> Bool) {
        this.compare = compare
    }

    public func equivalent(previous: T, current: T): Bool {
        compare(previous, current)
    }
}

/** Builds a mutation policy from one deterministic observational-equivalence function. */
public func stateMutationPolicy<T>(equivalent: (T, T) -> Bool): StateMutationPolicy<T> {
    ClosureStateMutationPolicy<T>(equivalent)
}

/** A policy that suppresses assignments equal under `Equatable`. */
public func structuralEqualityPolicy<T>(): StateMutationPolicy<T> where T <: Equatable<T> {
    StructuralEqualityStatePolicy<T>()
}

/** A policy that treats every assignment as a change, matching the default `State(value)` contract. */
public func neverEqualPolicy<T>(): StateMutationPolicy<T> {
    NeverEqualStatePolicy<T>()
}
