package cui.core

import std.collection.{ArrayList, HashMap}

private let COMMITTED_DEPENDENCY_LINEAR_LIMIT: Int64 = 8

/* Non-empty persistent declaration facet; absent scopes allocate no ownership collections. */
class CommittedMountOwnership {
    let stateKeys = ArrayList<String>()
    let retainedKeys = ArrayList<String>()
    let automaticKeys = ArrayList<String>()
    let effectKeys = ArrayList<String>()
    var implicitSlotShapes: ?HashMap<String, ImplicitSlotShape> = None
    var hasExternalRetainedRevision = false
    var hasExternalEffectRevision = false
}

/* Non-empty persistent build-dependency facet, independent of declaration ownership. */
class CommittedBuildDependencies {
    let dependencies = ArrayList<ObservableReadDependency>()
    var bySource: ?HashMap<UInt64, ObservableReadDependency> = None

    func get(identity: UInt64): ?ObservableReadDependency {
        match (bySource) {
            case Some(index) => index.get(identity)
            case None =>
                for (dependency in dependencies) {
                    if (dependency.sourceIdentity == identity) {
                        return Some(dependency)
                    }
                }
                None
        }
    }

    func replaceWith(source: ArrayList<ObservableReadDependency>): Unit {
        dependencies.clear()
        for (dependency in source) {
            dependencies.add(dependency)
        }
        if (dependencies.size <= COMMITTED_DEPENDENCY_LINEAR_LIMIT) {
            bySource = None
            return
        }
        let index = match (bySource) {
            case Some(current) =>
                current.clear()
                current
            case None => HashMap<UInt64, ObservableReadDependency>(dependencies.size)
        }
        for (dependency in dependencies) {
            let _ = index.add(dependency.sourceIdentity, dependency) // cjcheck-ignore: ignore-result # the canonical dependency sequence is unique
        }
        bySource = Some(index)
    }
}
