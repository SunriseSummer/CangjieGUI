package cui.core

import sdl.system.PerformanceClock

/** Immutable counters from one explicitly instrumented state-mutation policy. */
public struct StateMutationPolicyDiagnostics {
    public let comparisons: UInt64
    public let equivalentResults: UInt64
    public let distinctResults: UInt64
    public let failures: UInt64
    public let totalNanoseconds: UInt64
    public let maximumNanoseconds: UInt64

    init(
        comparisons: UInt64,
        equivalentResults: UInt64,
        distinctResults: UInt64,
        failures: UInt64,
        totalNanoseconds: UInt64,
        maximumNanoseconds: UInt64
    ) {
        this.comparisons = comparisons
        this.equivalentResults = equivalentResults
        this.distinctResults = distinctResults
        this.failures = failures
        this.totalNanoseconds = totalNanoseconds
        this.maximumNanoseconds = maximumNanoseconds
    }
}

/** An opt-in policy wrapper that measures suppression yield, failures, and comparison time. */
public class DiagnosedStateMutationPolicy<T> <: StateMutationPolicy<T> {
    private let target: StateMutationPolicy<T>
    private var comparisons: UInt64 = UInt64(0)
    private var equivalentResults: UInt64 = UInt64(0)
    private var distinctResults: UInt64 = UInt64(0)
    private var failures: UInt64 = UInt64(0)
    private var totalNanoseconds: UInt64 = UInt64(0)
    private var maximumNanoseconds: UInt64 = UInt64(0)

    init(target: StateMutationPolicy<T>) {
        this.target = target
    }

    public func equivalent(previous: T, current: T): Bool {
        let started = PerformanceClock.ticksNanoseconds()
        comparisons += UInt64(1)
        try {
            let result = target.equivalent(previous, current)
            if (result) {
                equivalentResults += UInt64(1)
            } else {
                distinctResults += UInt64(1)
            }
            result
        } catch (error: Exception) {
            failures += UInt64(1)
            throw error
        } finally {
            recordElapsed(started)
        }
    }

    /** Returns a stable snapshot without resetting counters. */
    public func diagnostics(): StateMutationPolicyDiagnostics {
        StateMutationPolicyDiagnostics(comparisons, equivalentResults, distinctResults, failures, totalNanoseconds,
            maximumNanoseconds)
    }

    /** Clears all counters; the wrapped policy and every State using it remain unchanged. */
    public func resetDiagnostics(): Unit {
        comparisons = UInt64(0)
        equivalentResults = UInt64(0)
        distinctResults = UInt64(0)
        failures = UInt64(0)
        totalNanoseconds = UInt64(0)
        maximumNanoseconds = UInt64(0)
    }

    private func recordElapsed(started: UInt64): Unit {
        let ended = PerformanceClock.ticksNanoseconds()
        let elapsed = if (ended >= started) {
            ended - started
        } else {
            UInt64(0)
        }
        totalNanoseconds += elapsed
        maximumNanoseconds = max(maximumNanoseconds, elapsed)
    }
}

/** Wraps one policy with explicit diagnostics; ordinary policies retain zero instrumentation cost. */
public func diagnoseStateMutationPolicy<T>(policy: StateMutationPolicy<T>): DiagnosedStateMutationPolicy<T> {
    DiagnosedStateMutationPolicy<T>(policy)
}
