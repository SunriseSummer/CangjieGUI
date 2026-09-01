package cui.core

/* Non-escaping mutable editor for one EntityTable batch. */
class EntityTableUpdateSession<ID, Entity> where ID <: Hashable & Equatable<ID> {
    private let regions: Array<Array<Array<?Array<Entity>>>>
    private let bucketCount: Int64
    private let identify: (Entity) -> ID
    private let touchedRegions: Array<Bool>
    private let touchedPages: Array<UInt32>
    private let touchedBuckets: Array<UInt32>

    init(
        source: Array<Array<Array<?Array<Entity>>>>,
        bucketCount: Int64,
        identify: (Entity) -> ID
    ) {
        regions = source.clone()
        this.bucketCount = bucketCount
        this.identify = identify
        touchedRegions = Array<Bool>(source.size, {_ => false})
        touchedPages = Array<UInt32>(source.size, {_ => UInt32(0)})
        touchedBuckets = Array<UInt32>(
            (bucketCount + ENTITY_TABLE_BRANCH_WIDTH - 1) / ENTITY_TABLE_BRANCH_WIDTH,
            {_ => UInt32(0)}
        )
    }

    func apply(update: EntityUpdate<ID, Entity>): Bool {
        applyValue<EntityUpdate<ID, Entity>>(
            update.id,
            update,
            {entity, change => change.apply(entity)}
        )
    }

    func reduce<Action>(
        identifiedAction: IdentifiedAction<ID, Action>,
        reducer: (Entity, Action) -> Entity
    ): Bool {
        applyValue<Action>(identifiedAction.id, identifiedAction.action, reducer)
    }

    func finish(): Array<Array<Array<?Array<Entity>>>> {
        regions
    }

    private func applyValue<Value>(
        id: ID,
        value: Value,
        transform: (Entity, Value) -> Entity
    ): Bool {
        let bucketIndex = entityTableBucketIndex(id, bucketCount)
        let location = entityTableLocation(bucketIndex)
        let current = match (regions[location.region][location.page][location.slot]) {
            case Some(bucket) => bucket
            case None => return false
        }
        let position = match (entityTableBucketPosition<ID, Entity>(current, id, identify)) {
            case Some(index) => index
            case None => return false
        }
        let entity = transform(current[position], value)
        if (identify(entity) != id) {
            throw IllegalArgumentException("EntityTable batch updates cannot change identity")
        }
        let region = writableRegion(location.region)
        let page = writablePage(region, location.region, location.page)
        match (writableBucket(page, location.slot, bucketIndex)) {
            case Some(bucket) => bucket[position] = entity
            case None => throw IllegalStateException("EntityTable batch lost a resolved bucket")
        }
        true
    }

    private func writableRegion(index: Int64): Array<Array<?Array<Entity>>> {
        if (!touchedRegions[index]) {
            regions[index] = regions[index].clone()
            touchedRegions[index] = true
        }
        regions[index]
    }

    private func writablePage(
        region: Array<Array<?Array<Entity>>>,
        regionIndex: Int64,
        pageIndex: Int64
    ): Array<?Array<Entity>> {
        let mask = UInt32(1) << UInt32(pageIndex)
        if ((touchedPages[regionIndex] & mask) == UInt32(0)) {
            region[pageIndex] = region[pageIndex].clone()
            touchedPages[regionIndex] |= mask
        }
        region[pageIndex]
    }

    private func writableBucket(
        page: Array<?Array<Entity>>,
        slot: Int64,
        bucketIndex: Int64
    ): ?Array<Entity> {
        let pageIndex = bucketIndex / ENTITY_TABLE_BRANCH_WIDTH
        let mask = UInt32(1) << UInt32(slot)
        if ((touchedBuckets[pageIndex] & mask) != UInt32(0)) {
            return page[slot]
        }
        match (page[slot]) {
            case Some(bucket) =>
                let cloned = bucket.clone()
                page[slot] = Some(cloned)
                touchedBuckets[pageIndex] |= mask
                Some(cloned)
            case None => None
        }
    }
}
