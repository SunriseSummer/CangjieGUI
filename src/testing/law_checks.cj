package cui.testing

import cui.core.{Lens, Prism, StateMutationPolicy}

private let POLICY_LAW_VALUE_COUNT: Int64 = 3

/** Per-law results for one concrete Lens witness. */
public struct LensLawCheck {
    public let getPut: Bool
    public let putGet: Bool
    public let putPut: Bool

    init(getPut: Bool, putGet: Bool, putPut: Bool) {
        this.getPut = getPut
        this.putGet = putGet
        this.putPut = putPut
    }

    /** Returns true only when all three Lens laws hold for this witness. */
    public func isLawful(): Bool {
        getPut && putGet && putPut
    }
}

/** Per-law results for one concrete Prism source/payload witness. */
public struct PrismLawCheck {
    public let extractAfterEmbed: Bool
    public let embedAfterExtract: Bool

    init(extractAfterEmbed: Bool, embedAfterExtract: Bool) {
        this.extractAfterEmbed = extractAfterEmbed
        this.embedAfterExtract = embedAfterExtract
    }

    /** Returns true only when both Prism round-trip laws hold for this witness. */
    public func isLawful(): Bool {
        extractAfterEmbed && embedAfterExtract
    }
}

/** Sampled determinism and equivalence-law results for one policy and three values. */
public struct StateMutationPolicyLawCheck {
    public let deterministic: Bool
    public let reflexive: Bool
    public let symmetric: Bool
    public let transitive: Bool

    init(deterministic: Bool, reflexive: Bool, symmetric: Bool, transitive: Bool) {
        this.deterministic = deterministic
        this.reflexive = reflexive
        this.symmetric = symmetric
        this.transitive = transitive
    }

    /** Returns true only when every sampled policy law holds. */
    public func isLawful(): Bool {
        deterministic && reflexive && symmetric && transitive
    }
}

/** Checks Get-Put, Put-Get for both focuses, and Put-Put for one concrete Lens witness. */
public func checkLensLaws<S, A>(
    lens: Lens<S, A>,
    source!: S,
    first!: A,
    second!: A
): LensLawCheck where S <: Equatable<S>, A <: Equatable<A> {
    let firstSet = lens.set(source, first)
    let secondSet = lens.set(source, second)
    LensLawCheck(
        lens.set(source, lens.get(source)) == source,
        lens.get(firstSet) == first && lens.get(secondSet) == second,
        lens.set(firstSet, second) == secondSet
    )
}

/** Checks both Prism round trips for one source and one focused payload. */
public func checkPrismLaws<S, A>(
    prism: Prism<S, A>,
    source!: S,
    value!: A
): PrismLawCheck where S <: Equatable<S>, A <: Equatable<A> {
    let extractAfterEmbed = match (prism.extract(prism.embed(value))) {
        case Some(extracted) => extracted == value
        case None => false
    }
    let embedAfterExtract = match (prism.extract(source)) {
        case Some(extracted) => prism.embed(extracted) == source
        case None => true
    }
    PrismLawCheck(extractAfterEmbed, embedAfterExtract)
}

/** Checks sampled determinism plus reflexive, symmetric, and transitive equivalence laws. */
public func checkStateMutationPolicyLaws<T>(
    policy: StateMutationPolicy<T>,
    first!: T,
    second!: T,
    third!: T
): StateMutationPolicyLawCheck {
    let values = [first, second, third]
    let relation = samplePolicyRelation(policy, values)
    StateMutationPolicyLawCheck(
        policySampleIsDeterministic(policy, values, relation),
        policySampleIsReflexive(relation),
        policySampleIsSymmetric(relation),
        policySampleIsTransitive(relation)
    )
}

private func samplePolicyRelation<T>(policy: StateMutationPolicy<T>, values: Array<T>): Array<Bool> {
    let relation = Array<Bool>(POLICY_LAW_VALUE_COUNT * POLICY_LAW_VALUE_COUNT, repeat: false)
    for (row in 0..POLICY_LAW_VALUE_COUNT) {
        for (column in 0..POLICY_LAW_VALUE_COUNT) {
            relation[policyRelationIndex(row, column)] = policy.equivalent(values[row], values[column])
        }
    }
    relation
}

private func policySampleIsDeterministic<T>(
    policy: StateMutationPolicy<T>,
    values: Array<T>,
    relation: Array<Bool>
): Bool {
    var deterministic = true
    for (row in 0..POLICY_LAW_VALUE_COUNT) {
        for (column in 0..POLICY_LAW_VALUE_COUNT) {
            if (policy.equivalent(values[row], values[column]) != relation[policyRelationIndex(row, column)]) {
                deterministic = false
            }
        }
    }
    deterministic
}

private func policySampleIsReflexive(relation: Array<Bool>): Bool {
    for (index in 0..POLICY_LAW_VALUE_COUNT) {
        if (!relation[policyRelationIndex(index, index)]) {
            return false
        }
    }
    true
}

private func policySampleIsSymmetric(relation: Array<Bool>): Bool {
    for (row in 0..POLICY_LAW_VALUE_COUNT) {
        for (column in (row + 1)..POLICY_LAW_VALUE_COUNT) {
            if (relation[policyRelationIndex(row, column)] != relation[policyRelationIndex(column, row)]) {
                return false
            }
        }
    }
    true
}

private func policySampleIsTransitive(relation: Array<Bool>): Bool {
    var transitive = true
    for (row in 0..POLICY_LAW_VALUE_COUNT) {
        for (middle in 0..POLICY_LAW_VALUE_COUNT) {
            for (column in 0..POLICY_LAW_VALUE_COUNT) {
                if (relation[policyRelationIndex(row, middle)] && relation[policyRelationIndex(middle, column)] &&
                    !relation[policyRelationIndex(row, column)]) {
                    transitive = false
                }
            }
        }
    }
    transitive
}

private func policyRelationIndex(row: Int64, column: Int64): Int64 {
    row * POLICY_LAW_VALUE_COUNT + column
}
