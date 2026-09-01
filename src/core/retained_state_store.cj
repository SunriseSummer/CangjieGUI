package cui.core

/* Retained-subtree bookkeeping is split from StateStore's ordinary state/focus paths. */
extend StateStore {
    /*
     * Returns a retained widget record at the current identity path. A revision hit skips the
     * declarative body and touches one child mount scope in O(1), regardless of descendant count.
     */
    func retainWidget(
        key: String,
        revision: UInt64,
        cachePaint: Bool,
        body: () -> Widget,
        hasExternalRevision!: Bool
    ): RetainedRecord {
        let path = retainedDeclarationPath(this, key, hasExternalRevision)
        match (retainedEntries.get(path)) {
            case Some(record) where !forceFullRetainedExecution && record.matches(revision, cachePaint) &&
                !record.mountScope.buildDirty =>
                replayFrameSubscribers(this, record.frameSubscribers)
                registerFocusFragment(record.focusFragment)
                record.recordBuildHit()
                record
            case previous =>
                let mountScope = match (previous) {
                    case Some(existing) => existing.mountScope
                    case None => createElementMountScope(this, path, diagnosticScopedKey(key), ElementKind.Retained)
                }
                pushScope(key)
                beginRetainedMount(this, mountScope)
                let subscriberStart = frameSubscriberCount(this)
                let focusStart = focusDeclarationCount()
                let child = try {
                    body()
                } finally {
                    endRetainedMount(this)
                    popScope()
                }
                let subscribers = frameSubscribersFrom(this, subscriberStart)
                let focusFragment = focusFragmentFrom(focusStart)
                let record = match (previous) {
                    case Some(existing) =>
                        stageRetainedReplacement(this, existing, revision, cachePaint, child, focusFragment, subscribers)
                        existing
                    case None =>
                        let sceneNode = elementArena.sceneFacet(mountScope.elementId).acquire(0)
                        let created = RetainedRecord(revision, cachePaint, child, mountScope, focusFragment, subscribers,
                            sceneNode)
                        created.attachDamageSink({rect => markRetainedDamage(this, rect)})
                        let _ = retainedEntries.add(path, created) // cjcheck-ignore: ignore-result # path was absent
                        retainedAddedDuringBuild.add(path)
                        elementArena.attachRetained(mountScope.elementId, created)
                        created
                }
                record
        }
    }
}

private func retainedDeclarationPath(store: StateStore, key: String, hasExternalRevision: Bool): String {
    store.validateKey(key)
    let path = store.scopedKey(key)
    visitRetainedChild(store, path, key, hasExternalRevision)
    path
}
