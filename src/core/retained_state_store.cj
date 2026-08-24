package cui.core

/* Retained-subtree bookkeeping is split from StateStore's ordinary state/focus paths. */
extend StateStore {
    /*
     * Returns a retained widget record at the current identity path. A revision hit skips the
     * declarative body and touches one child mount scope in O(1), regardless of descendant count.
     */
    func retainWidget(key: String, revision: UInt64, cachePaint: Bool, body: () -> Widget): RetainedRecord {
        validateKey(key)
        let path = scopedKey(key)
        visitRetainedChild(this, path, key)
        match (retainedEntries.get(path)) {
            case Some(record) where !forceFullRetainedExecution && record.matches(revision, cachePaint) &&
                !record.mountScope.buildDirty =>
                replayFrameSubscribers(this, record.frameSubscribers)
                for (id in record.focusableIds) {
                    registerFocusable(id)
                }
                record.recordBuildHit()
                record
            case previous =>
                let mountScope = match (previous) {
                    case Some(existing) => existing.mountScope
                    case None => StateMountScope(currentMountScope(this), diagnosticScopedKey(key))
                }
                pushScope(key)
                beginRetainedMount(this, mountScope)
                let subscriberStart = frameSubscriberCount(this)
                let child = try {
                    body()
                } finally {
                    endRetainedMount(this)
                    popScope()
                }
                let subscribers = frameSubscribersFrom(this, subscriberStart)
                let record = match (previous) {
                    case Some(existing) =>
                        stageRetainedReplacement(this, existing, revision, cachePaint, child, subscribers)
                        existing
                    case None =>
                        let created = RetainedRecord(revision, cachePaint, child, mountScope, subscribers)
                        created.attachDamageSink({rect => markRetainedDamage(this, rect)})
                        let _ = retainedEntries.add(path, created) // cjcheck-ignore: ignore-result # path was absent
                        retainedAddedDuringBuild.add(path)
                        created
                }
                record
        }
    }
}
