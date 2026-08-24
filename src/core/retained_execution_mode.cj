package cui.core

/** Enables normal retained cache hits after a differential test run. */
protected func useIncrementalRetainedExecution(store: StateStore): Unit {
    store.forceFullRetainedExecution = false
}

/** Disables retained cache hits for deterministic differential testing. */
protected func useFullRetainedExecution(store: StateStore): Unit {
    store.forceFullRetainedExecution = true
}
