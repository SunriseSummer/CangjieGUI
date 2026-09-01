package cui.core

private class EntityTableRecord {
    let id: Int64
    let value: Int64

    init(id: Int64, value: Int64) {
        this.id = id
        this.value = value
    }
}

private struct EntityCollisionId <: Hashable & Equatable<EntityCollisionId> {
    let value: Int64

    init(value: Int64) {
        this.value = value
    }

    public func hashCode(): Int64 {
        -1
    }

    public operator func ==(other: EntityCollisionId): Bool {
        value == other.value
    }
}

private class EntityCollisionRecord {
    let id: EntityCollisionId
    let value: Int64

    init(id: Int64, value: Int64) {
        this.id = EntityCollisionId(id)
        this.value = value
    }
}

private class EntityTableProbe {
    var didThrow = false
}

private func entityTableRecords(size: Int64): Array<EntityTableRecord> {
    Array<EntityTableRecord>(size, {id => EntityTableRecord(id, id * 2)})
}

private func emptyEntityTable(): EntityTable<Int64, EntityTableRecord> {
    EntityTable<Int64, EntityTableRecord>([], id: {entity => entity.id})
}

@Test
func entityTableSnapshotsInputAndLooksUpNegativeIds(): Unit {
    let source = [EntityTableRecord(-7, 3), EntityTableRecord(2, 4)]
    let table = EntityTable<Int64, EntityTableRecord>(source, id: {entity => entity.id})
    source[0] = EntityTableRecord(99, 10)

    @Expect(table.size, Int64(2))
    @Expect(!table.isEmpty())
    @Expect(table.get(-7).getOrThrow().value, Int64(3))
    @Expect(table.get(2).getOrThrow().value, Int64(4))
    @Expect(table.get(99).isNone())
    @Expect(table.contains(-7))
    @Expect(table.toArray().size, Int64(2))
    @Expect(table.diagnostics().entities, Int64(2))
    @Expect(table.diagnostics().buckets, Int64(8))
}

@Test
func entityTableRejectsDuplicateAndMutatedIdentity(): Unit {
    let probe = EntityTableProbe()
    try {
        let _ = EntityTable<Int64, EntityTableRecord>(
            [EntityTableRecord(1, 1), EntityTableRecord(1, 2)],
            id: {entity => entity.id}
        )
    } catch (_: IllegalArgumentException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)

    probe.didThrow = false
    let table = EntityTable<Int64, EntityTableRecord>(entityTableRecords(4), id: {entity => entity.id})
    try {
        let _ = table.updating(2, {entity => EntityTableRecord(entity.id + 10, entity.value)})
    } catch (_: IllegalArgumentException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(table.get(2).getOrThrow().value, Int64(4))
    @Expect(table.get(12).isNone())
}

@Test
func entityTablePersistentInsertSetUpdateAndRemoveKeepOldVersions(): Unit {
    let original = EntityTable<Int64, EntityTableRecord>(entityTableRecords(3), id: {entity => entity.id})
    let inserted = original.inserting(EntityTableRecord(9, 90))
    let updated = inserted.updating(1, {entity => EntityTableRecord(entity.id, 77)}).getOrThrow()
    let set = updated.setting(EntityTableRecord(9, 99))
    let removed = set.removing(0).getOrThrow()

    @Expect(original.size, Int64(3))
    @Expect(original.get(9).isNone())
    @Expect(inserted.get(1).getOrThrow().value, Int64(2))
    @Expect(inserted.get(9).getOrThrow().value, Int64(90))
    @Expect(updated.get(1).getOrThrow().value, Int64(77))
    @Expect(updated.get(9).getOrThrow().value, Int64(90))
    @Expect(set.get(9).getOrThrow().value, Int64(99))
    @Expect(removed.get(0).isNone())
    @Expect(removed.size, Int64(3))
    @Expect(set.get(0).isSome())
}

@Test
func entityTableResizePreservesEveryPersistentVersion(): Unit {
    var table = emptyEntityTable()
    var beforeFirstResize = emptyEntityTable()
    var afterFirstResize = emptyEntityTable()
    for (id in 0..130) {
        table = table.inserting(EntityTableRecord(id, id + 1))
        if (id == 47) {
            beforeFirstResize = table
        }
        if (id == 48) {
            afterFirstResize = table
        }
    }

    @Expect(beforeFirstResize.size, Int64(48))
    @Expect(beforeFirstResize.get(47).getOrThrow().value, Int64(48))
    @Expect(beforeFirstResize.get(48).isNone())
    @Expect(afterFirstResize.size, Int64(49))
    @Expect(afterFirstResize.get(48).getOrThrow().value, Int64(49))
    @Expect(table.size, Int64(130))
    for (id in 0..130) {
        @Expect(table.get(id).getOrThrow().value, id + 1)
    }
}

@Test
func entityTableHandlesFullHashCollisions(): Unit {
    let table = EntityTable<EntityCollisionId, EntityCollisionRecord>(
        Array<EntityCollisionRecord>(40, {id => EntityCollisionRecord(id, id)}),
        id: {entity => entity.id}
    )
    let updated = table.updating(
        EntityCollisionId(21),
        {entity => EntityCollisionRecord(entity.id.value, 210)}
    ).getOrThrow()
    let removed = updated.removing(EntityCollisionId(7)).getOrThrow()

    @Expect(table.get(EntityCollisionId(21)).getOrThrow().value, Int64(21))
    @Expect(updated.get(EntityCollisionId(21)).getOrThrow().value, Int64(210))
    @Expect(removed.get(EntityCollisionId(7)).isNone())
    @Expect(removed.get(EntityCollisionId(39)).getOrThrow().value, Int64(39))
    @Expect(removed.size, Int64(39))
    @Expect(removed.diagnostics().occupiedBuckets, Int64(1))
    @Expect(removed.diagnostics().maxBucketSize, Int64(39))
}

@Test
func entityTableMissingAndFailurePathsDoNotChangeTheOriginal(): Unit {
    let probe = EntityTableProbe()
    let table = EntityTable<Int64, EntityTableRecord>(entityTableRecords(5), id: {entity => entity.id})

    @Expect(table.updating(99, {entity => entity}).isNone())
    @Expect(table.removing(99).isNone())
    try {
        let _ = table.inserting(EntityTableRecord(2, 200))
    } catch (_: IllegalArgumentException) {
        probe.didThrow = true
    }

    @Expect(probe.didThrow)
    @Expect(table.size, Int64(5))
    @Expect(table.get(2).getOrThrow().value, Int64(4))
}

@Test
func entityTableBatchComposesDuplicateIdsInOrderAndSharesOldVersion(): Unit {
    let table = EntityTable<Int64, EntityTableRecord>(entityTableRecords(5000), id: {entity => entity.id})
    let updates = [
        EntityUpdate<Int64, EntityTableRecord>(2, transform: {
            entity => EntityTableRecord(entity.id, entity.value + 3)
        }),
        EntityUpdate<Int64, EntityTableRecord>(4095, transform: {
            entity => EntityTableRecord(entity.id, entity.value + 5)
        }),
        EntityUpdate<Int64, EntityTableRecord>(2, transform: {
            entity => EntityTableRecord(entity.id, entity.value * 2)
        }),
        EntityUpdate<Int64, EntityTableRecord>(100, transform: {entity => entity}),
        EntityUpdate<Int64, EntityTableRecord>(101, transform: {entity => entity}),
        EntityUpdate<Int64, EntityTableRecord>(102, transform: {entity => entity}),
        EntityUpdate<Int64, EntityTableRecord>(103, transform: {entity => entity}),
        EntityUpdate<Int64, EntityTableRecord>(104, transform: {entity => entity}),
        EntityUpdate<Int64, EntityTableRecord>(105, transform: {entity => entity}),
        EntityUpdate<Int64, EntityTableRecord>(106, transform: {entity => entity})
    ]
    let changed = table.updatingAll(updates).getOrThrow()

    @Expect(table.get(2).getOrThrow().value, Int64(4))
    @Expect(table.get(4095).getOrThrow().value, Int64(8190))
    @Expect(changed.get(2).getOrThrow().value, Int64(14))
    @Expect(changed.get(4095).getOrThrow().value, Int64(8195))
    @Expect(changed.size, table.size)
}

@Test
func entityTableBatchEmptySingleAndMissingPathsAreAtomic(): Unit {
    let table = EntityTable<Int64, EntityTableRecord>(entityTableRecords(8), id: {entity => entity.id})
    let empty: Array<EntityUpdate<Int64, EntityTableRecord>> = []
    let unchanged = table.updatingAll(empty).getOrThrow()
    let single = table.updatingAll([
        EntityUpdate<Int64, EntityTableRecord>(3, transform: {
            entity => EntityTableRecord(entity.id, entity.value + 1)
        })
    ]).getOrThrow()
    let missingUpdates = Array<EntityUpdate<Int64, EntityTableRecord>>(10, {
        index =>
            let id = if (index == 9) { 99 } else { index % 8 }
            EntityUpdate<Int64, EntityTableRecord>(id, transform: {
                entity => EntityTableRecord(entity.id, 200 + index)
            })
    })
    let missing = table.updatingAll(missingUpdates)

    @Expect(unchanged.get(3).getOrThrow().value, Int64(6))
    @Expect(single.get(3).getOrThrow().value, Int64(7))
    @Expect(missing.isNone())
    @Expect(table.get(2).getOrThrow().value, Int64(4))
}

@Test
func entityTableBatchIdentityAndTransformFailuresLeaveSourceUntouched(): Unit {
    let probe = EntityTableProbe()
    let table = EntityTable<Int64, EntityTableRecord>(entityTableRecords(8), id: {entity => entity.id})
    let identityUpdates = Array<EntityUpdate<Int64, EntityTableRecord>>(9, {
        index => if (index == 8) {
            EntityUpdate<Int64, EntityTableRecord>(2, transform: {
                entity => EntityTableRecord(entity.id + 10, entity.value)
            })
        } else {
            EntityUpdate<Int64, EntityTableRecord>(index, transform: {
                entity => EntityTableRecord(entity.id, entity.value + 1)
            })
        }
    })
    try {
        let _ = table.updatingAll(identityUpdates)
    } catch (_: IllegalArgumentException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)
    @Expect(table.get(1).getOrThrow().value, Int64(2))
    @Expect(table.get(2).getOrThrow().value, Int64(4))

    probe.didThrow = false
    let throwingUpdates = Array<EntityUpdate<Int64, EntityTableRecord>>(9, {
        index => if (index == 8) {
            EntityUpdate<Int64, EntityTableRecord>(1, transform: {
                _ => throw IllegalStateException("expected batch transform failure")
            })
        } else {
            EntityUpdate<Int64, EntityTableRecord>(index, transform: {
                entity => EntityTableRecord(entity.id, entity.value + 1)
            })
        }
    })
    try {
        let _ = table.updatingAll(throwingUpdates)
    } catch (_: IllegalStateException) {
        probe.didThrow = true
    }
    @Expect(probe.didThrow)
    @Expect(table.get(1).getOrThrow().value, Int64(2))
}

@Test
func entityTableBatchPreservesFullCollisionRouting(): Unit {
    let table = EntityTable<EntityCollisionId, EntityCollisionRecord>(
        Array<EntityCollisionRecord>(40, {id => EntityCollisionRecord(id, id)}),
        id: {entity => entity.id}
    )
    let updates = Array<EntityUpdate<EntityCollisionId, EntityCollisionRecord>>(10, {
        index =>
            let id = if (index == 9) { Int64(39) } else { index }
            EntityUpdate<EntityCollisionId, EntityCollisionRecord>(EntityCollisionId(id), transform: {
                entity => EntityCollisionRecord(entity.id.value, entity.value * 10)
            })
    })
    let changed = table.updatingAll(updates).getOrThrow()

    @Expect(table.get(EntityCollisionId(7)).getOrThrow().value, Int64(7))
    @Expect(changed.get(EntityCollisionId(7)).getOrThrow().value, Int64(70))
    @Expect(changed.get(EntityCollisionId(39)).getOrThrow().value, Int64(390))
    @Expect(changed.diagnostics().maxBucketSize, Int64(40))
}
