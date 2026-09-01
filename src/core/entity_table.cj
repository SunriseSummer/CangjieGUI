package cui.core

import std.collection.ArrayList

let ENTITY_TABLE_BRANCH_WIDTH: Int64 = 32
private let ENTITY_TABLE_REGION_WIDTH: Int64 = 1024
private let ENTITY_TABLE_MIN_BUCKETS: Int64 = 8
private let ENTITY_TABLE_TARGET_LOAD: Int64 = 4
private let ENTITY_TABLE_MAX_LOAD: Int64 = 6
private let ENTITY_TABLE_SEQUENTIAL_BATCH_LIMIT: Int64 = 8

struct EntityTableLocation {
    let region: Int64
    let page: Int64
    let slot: Int64

    init(region: Int64, page: Int64, slot: Int64) {
        this.region = region
        this.page = page
        this.slot = slot
    }
}

/** Hash-directory diagnostics for detecting poor ID hash distribution and retained capacity. */
public struct EntityTableStats {
    /** Current entity count. */
    public let entities: Int64
    /** Power-of-two logical bucket count. */
    public let buckets: Int64
    /** Buckets that currently contain at least one entity. */
    public let occupiedBuckets: Int64
    /** Largest collision bucket. */
    public let maxBucketSize: Int64
    /** Top-level persistent directory region count. */
    public let regions: Int64

    init(entities: Int64, buckets: Int64, occupiedBuckets: Int64, maxBucketSize: Int64, regions: Int64) {
        this.entities = entities
        this.buckets = buckets
        this.occupiedBuckets = occupiedBuckets
        this.maxBucketSize = maxBucketSize
        this.regions = regions
    }
}

/**
 * An immutable ID-keyed entity table for normalized application state. Hash buckets live in a
 * shallow 32-way persistent radix directory: a single update shares every untouched region, page,
 * and bucket. Unlike IdentifiedArray, iteration order is not a display-order contract.
 */
public struct EntityTable<ID, Entity> where ID <: Hashable & Equatable<ID> {
    private let regions: Array<Array<Array<?Array<Entity>>>>
    private let bucketCount: Int64
    private let entityCount: Int64
    private let identify: (Entity) -> ID

    /**
     * Snapshots `entities` and builds the persistent hash directory.
     * Throws `IllegalArgumentException` when the `id` projection contains a duplicate.
     */
    public init(entities: Array<Entity>, id!: (Entity) -> ID) {
        let nextBucketCount = entityTableBucketCount(entities.size)
        let builders = Array<?ArrayList<Entity>>(nextBucketCount, {_ => None})
        for (entity in entities) {
            let entityId = id(entity)
            let bucketIndex = entityTableBucketIndex(entityId, nextBucketCount)
            match (builders[bucketIndex]) {
                case Some(bucket) =>
                    if (entityTableBuilderContains<ID, Entity>(bucket, entityId, id)) {
                        throw IllegalArgumentException("EntityTable requires unique IDs")
                    }
                    bucket.add(entity)
                case None =>
                    let bucket = ArrayList<Entity>()
                    bucket.add(entity)
                    builders[bucketIndex] = Some(bucket)
            }
        }
        regions = entityTableRegions(builders, nextBucketCount)
        bucketCount = nextBucketCount
        entityCount = entities.size
        identify = id
    }

    private init(
        regions: Array<Array<Array<?Array<Entity>>>>,
        bucketCount: Int64,
        entityCount: Int64,
        identify: (Entity) -> ID
    ) {
        this.regions = regions
        this.bucketCount = bucketCount
        this.entityCount = entityCount
        this.identify = identify
    }

    /** Number of entities in the table. */
    public prop size: Int64 {
        get() {
            entityCount
        }
    }

    /** Whether the table contains no entities. */
    public func isEmpty(): Bool {
        entityCount == 0
    }

    /** Returns the entity with `id`, or None when it is absent. */
    public func get(id: ID): ?Entity {
        let bucketIndex = id.hashCode() & (bucketCount - 1)
        let regionIndex = bucketIndex / ENTITY_TABLE_REGION_WIDTH
        let withinRegion = bucketIndex % ENTITY_TABLE_REGION_WIDTH
        let pageIndex = withinRegion / ENTITY_TABLE_BRANCH_WIDTH
        let slotIndex = withinRegion % ENTITY_TABLE_BRANCH_WIDTH
        match (regions[regionIndex][pageIndex][slotIndex]) {
            case Some(bucket) =>
                for (position in 0..bucket.size) {
                    let entity = bucket[position]
                    if (identify(entity) == id) {
                        return Some(entity)
                    }
                }
                None
            case None => None
        }
    }

    /** Whether the table contains `id`. */
    public func contains(id: ID): Bool {
        get(id).isSome()
    }

    /**
     * Returns a table with one entity transformed, or None when `id` is absent. The transform runs
     * before structural clones. Exceptions from `transform` propagate without changing this table;
     * changing the entity's ID throws `IllegalArgumentException`.
     */
    public func updating(id: ID, transform: (Entity) -> Entity): ?EntityTable<ID, Entity> {
        let location = locationOf(id)
        match (bucketAt(location)) {
            case Some(bucket) => match (entityTableBucketPosition<ID, Entity>(bucket, id, identify)) {
                case Some(position) =>
                    let entity = transform(bucket[position])
                    if (identify(entity) != id) {
                        throw IllegalArgumentException("EntityTable entity updates cannot change identity")
                    }
                    let nextBucket = bucket.clone()
                    nextBucket[position] = entity
                    Some(replacingBucket(location, Some(nextBucket), entityCount))
                case None => None
            }
            case None => None
        }
    }

    /**
     * Applies one reusable EntityUpdate. Its transform exceptions propagate without changing this
     * table; an identity change throws `IllegalArgumentException`.
     */
    public func updating(update: EntityUpdate<ID, Entity>): ?EntityTable<ID, Entity> {
        updating(update.id, {entity => update.apply(entity)})
    }

    /**
     * Applies an ordered batch atomically. Duplicate IDs compose in array order; a missing ID
     * returns None and no table version. Transform exceptions propagate without a partial version;
     * an identity change throws `IllegalArgumentException`.
     */
    public func updatingAll(updates: Array<EntityUpdate<ID, Entity>>): ?EntityTable<ID, Entity> {
        if (updates.isEmpty()) {
            return Some(this)
        }
        if (updates.size == 1) {
            return updating(updates[0])
        }
        if (updates.size <= ENTITY_TABLE_SEQUENTIAL_BATCH_LIMIT) {
            return updatingSequentially(updates)
        }
        let session = EntityTableUpdateSession<ID, Entity>(regions, bucketCount, identify)
        for (update in updates) {
            if (!session.apply(update)) {
                return None
            }
        }
        Some(EntityTable<ID, Entity>(session.finish(), bucketCount, entityCount, identify))
    }

    /* Package reducer bridge: one explicit Action batch creates at most one table version. */
    func reducingAll<Action>(
        actions: Array<IdentifiedAction<ID, Action>>,
        reducer: (Entity, Action) -> Entity,
        missing: MissingFeaturePolicy
    ): EntityTable<ID, Entity> {
        if (actions.isEmpty()) {
            return this
        }
        if (actions.size <= ENTITY_TABLE_SEQUENTIAL_BATCH_LIMIT) {
            return reducingSequentially(actions, reducer, missing)
        }
        let session = EntityTableUpdateSession<ID, Entity>(regions, bucketCount, identify)
        var applied = false
        for (action in actions) {
            if (session.reduce(action, reducer)) {
                applied = true
            } else {
                handleMissingFeature(missing, "Entity batch reducer")
            }
        }
        if (applied) {
            EntityTable<ID, Entity>(session.finish(), bucketCount, entityCount, identify)
        } else {
            this
        }
    }

    /**
     * Returns a table with a new entity.
     * Throws `IllegalArgumentException` when the entity ID is already present.
     */
    public func inserting(entity: Entity): EntityTable<ID, Entity> {
        let id = identify(entity)
        if (contains(id)) {
            throw IllegalArgumentException("EntityTable cannot insert a duplicate ID")
        }
        if (entityCount + 1 > bucketCount * ENTITY_TABLE_MAX_LOAD) {
            let current = toArray()
            let next = Array<Entity>(entityCount + 1, {
                index => if (index < entityCount) {
                    current[index]
                } else {
                    entity
                }
            })
            return EntityTable<ID, Entity>(next, id: identify)
        }
        let location = locationOf(id)
        let nextBucket = match (bucketAt(location)) {
            case Some(bucket) => Array<Entity>(bucket.size + 1, {
                index => if (index < bucket.size) {
                    bucket[index]
                } else {
                    entity
                }
            })
            case None => [entity]
        }
        replacingBucket(location, Some(nextBucket), entityCount + 1)
    }

    /** Inserts `entity`, or replaces the existing entity with the same ID. */
    public func setting(entity: Entity): EntityTable<ID, Entity> {
        let id = identify(entity)
        match (updating(id, {_ => entity})) {
            case Some(table) => table
            case None => inserting(entity)
        }
    }

    /** Returns a table without `id`, or None when it is absent. */
    public func removing(id: ID): ?EntityTable<ID, Entity> {
        let location = locationOf(id)
        match (bucketAt(location)) {
            case Some(bucket) => match (entityTableBucketPosition<ID, Entity>(bucket, id, identify)) {
                case Some(position) =>
                    let nextBucket = entityTableRemovingAt(bucket, position)
                    Some(replacingBucket(location, nextBucket, entityCount - 1))
                case None => None
            }
            case None => None
        }
    }

    /** Returns an isolated snapshot in unspecified hash-bucket order. */
    public func toArray(): Array<Entity> {
        let result = ArrayList<Entity>()
        for (region in regions) {
            appendEntityTableRegion(result, region)
        }
        result.toArray()
    }

    /** Returns deterministic structural counters without exposing or copying entity values. */
    public func diagnostics(): EntityTableStats {
        var occupied: Int64 = 0
        var largest: Int64 = 0
        for (region in regions) {
            for (page in region) {
                for (bucket in page) {
                    match (bucket) {
                        case Some(entities) =>
                            occupied += 1
                            largest = max(largest, entities.size)
                        case None => ()
                    }
                }
            }
        }
        EntityTableStats(entityCount, bucketCount, occupied, largest, regions.size)
    }

    private func locationOf(id: ID): EntityTableLocation {
        entityTableLocation(entityTableBucketIndex(id, bucketCount))
    }

    private func bucketAt(location: EntityTableLocation): ?Array<Entity> {
        regions[location.region][location.page][location.slot]
    }

    private func updatingSequentially(updates: Array<EntityUpdate<ID, Entity>>): ?EntityTable<ID, Entity> {
        var current = this
        for (update in updates) {
            match (current.updating(update)) {
                case Some(next) => current = next
                case None => return None
            }
        }
        Some(current)
    }

    private func reducingSequentially<Action>(
        actions: Array<IdentifiedAction<ID, Action>>,
        reducer: (Entity, Action) -> Entity,
        missing: MissingFeaturePolicy
    ): EntityTable<ID, Entity> {
        var current = this
        for (identifiedAction in actions) {
            let action = identifiedAction.action
            match (current.updating(identifiedAction.id, {entity => reducer(entity, action)})) {
                case Some(next) => current = next
                case None => handleMissingFeature(missing, "Entity batch reducer")
            }
        }
        current
    }

    private func replacingBucket(
        location: EntityTableLocation,
        bucket: ?Array<Entity>,
        nextCount: Int64
    ): EntityTable<ID, Entity> {
        let nextRegions = regions.clone()
        let nextRegion = regions[location.region].clone()
        let nextPage = nextRegion[location.page].clone()
        nextPage[location.slot] = bucket
        nextRegion[location.page] = nextPage
        nextRegions[location.region] = nextRegion
        EntityTable<ID, Entity>(nextRegions, bucketCount, nextCount, identify)
    }
}

private func entityTableBucketCount(size: Int64): Int64 {
    let target = max(ENTITY_TABLE_MIN_BUCKETS, (size + ENTITY_TABLE_TARGET_LOAD - 1) / ENTITY_TABLE_TARGET_LOAD)
    var count = ENTITY_TABLE_MIN_BUCKETS
    while (count < target) {
        count *= 2
    }
    count
}

func entityTableBucketIndex<ID>(id: ID, bucketCount: Int64): Int64 where ID <: Hashable {
    id.hashCode() & (bucketCount - 1)
}

func entityTableLocation(bucketIndex: Int64): EntityTableLocation {
    let region = bucketIndex / ENTITY_TABLE_REGION_WIDTH
    let withinRegion = bucketIndex % ENTITY_TABLE_REGION_WIDTH
    EntityTableLocation(
        region,
        withinRegion / ENTITY_TABLE_BRANCH_WIDTH,
        withinRegion % ENTITY_TABLE_BRANCH_WIDTH
    )
}

func entityTableBucketPosition<ID, Entity>(
    bucket: Array<Entity>,
    id: ID,
    identify: (Entity) -> ID
): ?Int64 where ID <: Equatable<ID> {
    for (position in 0..bucket.size) {
        if (identify(bucket[position]) == id) {
            return Some(position)
        }
    }
    None
}

private func entityTableBuilderContains<ID, Entity>(
    bucket: ArrayList<Entity>,
    id: ID,
    identify: (Entity) -> ID
): Bool where ID <: Equatable<ID> {
    for (entity in bucket) {
        if (identify(entity) == id) {
            return true
        }
    }
    false
}

private func entityTableRemovingAt<Entity>(bucket: Array<Entity>, position: Int64): ?Array<Entity> {
    if (bucket.size == 1) {
        return None
    }
    Some(Array<Entity>(bucket.size - 1, {
        index => if (index < position) {
            bucket[index]
        } else {
            bucket[index + 1]
        }
    }))
}

private func appendEntityTableRegion<Entity>(
    result: ArrayList<Entity>,
    region: Array<Array<?Array<Entity>>>
): Unit {
    for (page in region) {
        for (bucket in page) {
            match (bucket) {
                case Some(entities) => result.add(all: entities)
                case None => ()
            }
        }
    }
}

private func entityTableRegions<Entity>(
    builders: Array<?ArrayList<Entity>>,
    bucketCount: Int64
): Array<Array<Array<?Array<Entity>>>> {
    let regionCount = (bucketCount + ENTITY_TABLE_REGION_WIDTH - 1) / ENTITY_TABLE_REGION_WIDTH
    Array<Array<Array<?Array<Entity>>>>(
        regionCount,
        {
            region =>
                let regionStart = region * ENTITY_TABLE_REGION_WIDTH
                let regionBuckets = min(ENTITY_TABLE_REGION_WIDTH, bucketCount - regionStart)
                let pageCount = (regionBuckets + ENTITY_TABLE_BRANCH_WIDTH - 1) / ENTITY_TABLE_BRANCH_WIDTH
                Array<Array<?Array<Entity>>>(
                    pageCount,
                    {
                        page =>
                            let pageStart = regionStart + page * ENTITY_TABLE_BRANCH_WIDTH
                            let pageBuckets = min(ENTITY_TABLE_BRANCH_WIDTH, bucketCount - pageStart)
                            Array<?Array<Entity>>(pageBuckets, {
                                slot => match (builders[pageStart + slot]) {
                                    case Some(bucket) => Some(bucket.toArray())
                                    case None => None
                                }
                            })
                    }
                )
        }
    )
}
