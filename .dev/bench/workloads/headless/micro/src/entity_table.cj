package bench_micro

import std.collection.HashMap
import cui.{EntityTable, EntityUpdate, IdentifiedAction, Reducer, entityBatchReducer, entityReducer}
import bench_harness.{report, reportCount, timeit}

private let ENTITY_TABLE_BENCH_READ_STEP: Int64 = 7919

private class EntityTableBenchRecord {
    let id: Int64
    let value: Int64

    init(id: Int64, value: Int64) {
        this.id = id
        this.value = value
    }
}

private class EntityTableBench {
    private let targetId: Int64
    private let recordCount: Int64
    private var linear: Array<EntityTableBenchRecord>
    private var clonedMap: HashMap<Int64, EntityTableBenchRecord>
    private var persistent: EntityTable<Int64, EntityTableBenchRecord>
    private var linearReadCursor: Int64 = 0
    private var mapReadCursor: Int64 = 0
    private var persistentReadCursor: Int64 = 0

    init(size: Int64) {
        let records = Array<EntityTableBenchRecord>(size, {id => EntityTableBenchRecord(id, 0)})
        recordCount = size
        targetId = size - 1
        linear = records
        let map = HashMap<Int64, EntityTableBenchRecord>(size)
        for (record in records) {
            match (map.add(record.id, record)) {
                case Some(_) => throw IllegalStateException("entity benchmark generated a duplicate ID")
                case None => ()
            }
        }
        clonedMap = map
        persistent = EntityTable<Int64, EntityTableBenchRecord>(records, id: {record => record.id})
    }

    func updateLinear(): Int64 {
        var target: Int64 = -1
        for (index in 0..linear.size) {
            if (linear[index].id == targetId) {
                target = index
                break
            }
        }
        if (target < 0) {
            throw IllegalStateException("linear entity benchmark target missing")
        }
        let next = linear.clone()
        let record = linear[target]
        next[target] = EntityTableBenchRecord(record.id, record.value + 1)
        linear = next
        linear[target].value
    }

    func updateClonedMap(): Int64 {
        let next = clonedMap.clone()
        let record = next.get(targetId).getOrThrow()
        match (next.add(targetId, EntityTableBenchRecord(record.id, record.value + 1))) {
            case Some(_) => ()
            case None => throw IllegalStateException("cloned map benchmark target missing")
        }
        clonedMap = next
        clonedMap.get(targetId).getOrThrow().value
    }

    func updatePersistent(): Int64 {
        persistent = persistent.updating(
            targetId,
            {record => EntityTableBenchRecord(record.id, record.value + 1)}
        ).getOrThrow()
        persistent.get(targetId).getOrThrow().value
    }

    func readMap(): Int64 {
        let id = mapReadCursor
        mapReadCursor = (mapReadCursor + ENTITY_TABLE_BENCH_READ_STEP) % recordCount
        clonedMap.get(id).getOrThrow().value + id
    }

    func readLinear(): Int64 {
        let id = linearReadCursor
        linearReadCursor = (linearReadCursor + ENTITY_TABLE_BENCH_READ_STEP) % recordCount
        for (record in linear) {
            if (record.id == id) {
                return record.value + id
            }
        }
        throw IllegalStateException("linear entity read benchmark target missing")
    }

    func readPersistent(): Int64 {
        let id = persistentReadCursor
        persistentReadCursor = (persistentReadCursor + ENTITY_TABLE_BENCH_READ_STEP) % recordCount
        persistent.get(id).getOrThrow().value + id
    }

    func persistentSize(): UInt64 {
        UInt64(persistent.size)
    }
}

private class EntityTableBatchBench {
    private let updates: Array<EntityUpdate<Int64, EntityTableBenchRecord>>
    private var sequential: EntityTable<Int64, EntityTableBenchRecord>
    private var batched: EntityTable<Int64, EntityTableBenchRecord>

    init(size: Int64, width: Int64) {
        let records = Array<EntityTableBenchRecord>(size, {id => EntityTableBenchRecord(id, 0)})
        sequential = EntityTable<Int64, EntityTableBenchRecord>(records, id: {record => record.id})
        batched = EntityTable<Int64, EntityTableBenchRecord>(records, id: {record => record.id})
        updates = Array<EntityUpdate<Int64, EntityTableBenchRecord>>(width, {
            index => EntityUpdate<Int64, EntityTableBenchRecord>(
                (index * ENTITY_TABLE_BENCH_READ_STEP) % size,
                transform: {record => EntityTableBenchRecord(record.id, record.value + 1)}
            )
        })
    }

    func updateSequential(): Int64 {
        for (update in updates) {
            sequential = sequential.updating(update).getOrThrow()
        }
        sequential.get(updates[updates.size - 1].id).getOrThrow().value
    }

    func updateBatch(): Int64 {
        batched = batched.updatingAll(updates).getOrThrow()
        batched.get(updates[updates.size - 1].id).getOrThrow().value
    }

    func batchSize(): UInt64 {
        UInt64(batched.size)
    }
}

private class EntityReducerBatchBench {
    private let actions: Array<IdentifiedAction<Int64, Int64>>
    private let singleReducer: Reducer<EntityTable<Int64, EntityTableBenchRecord>, IdentifiedAction<Int64, Int64>>
    private let batchReducer: Reducer<EntityTable<Int64, EntityTableBenchRecord>, Array<IdentifiedAction<Int64, Int64>>>
    private var sequential: EntityTable<Int64, EntityTableBenchRecord>
    private var batched: EntityTable<Int64, EntityTableBenchRecord>

    init(size: Int64, width: Int64) {
        let records = Array<EntityTableBenchRecord>(size, {id => EntityTableBenchRecord(id, 0)})
        let child = Reducer<EntityTableBenchRecord, Int64>({
            record, amount => EntityTableBenchRecord(record.id, record.value + amount)
        })
        singleReducer = entityReducer<Int64, EntityTableBenchRecord, Int64>(child)
        batchReducer = entityBatchReducer<Int64, EntityTableBenchRecord, Int64>(child)
        sequential = EntityTable<Int64, EntityTableBenchRecord>(records, id: {record => record.id})
        batched = EntityTable<Int64, EntityTableBenchRecord>(records, id: {record => record.id})
        actions = Array<IdentifiedAction<Int64, Int64>>(width, {
            index => IdentifiedAction<Int64, Int64>((index * ENTITY_TABLE_BENCH_READ_STEP) % size, 1)
        })
    }

    func updateSequential(): Int64 {
        for (action in actions) {
            sequential = singleReducer.reduce(sequential, action)
        }
        sequential.get(actions[actions.size - 1].id).getOrThrow().value
    }

    func updateBatch(): Int64 {
        batched = batchReducer.reduce(batched, actions)
        batched.get(actions[actions.size - 1].id).getOrThrow().value
    }

    func batchSize(): UInt64 {
        UInt64(batched.size)
    }
}

func runEntityTableBenches(): Unit {
    runEntityTableBench(16, 150000)
    runEntityTableBench(1024, 12000)
    runEntityTableBench(10000, 1500)
    runEntityTableBench(100000, 160)
    runEntityTableBatchBench(10000, 1, 3000)
    runEntityTableBatchBench(10000, 4, 1500)
    runEntityTableBatchBench(10000, 8, 900)
    runEntityTableBatchBench(10000, 16, 500)
    runEntityTableBatchBench(10000, 32, 300)
    runEntityTableBatchBench(10000, 128, 100)
    runEntityTableBatchBench(100000, 32, 160)
    runEntityReducerBatchBench(10000, 4, 1500)
    runEntityReducerBatchBench(10000, 32, 300)
    runEntityReducerBatchBench(10000, 128, 100)
    runEntityReducerBatchBench(100000, 32, 160)
}

private func runEntityReducerBatchBench(size: Int64, width: Int64, iterations: Int64): Unit {
    let sequential = EntityReducerBatchBench(size, width)
    report(
        "micro",
        "Entity reducer batch",
        timeit("${size} 项 / ${width} Action 逐次", iterations, {=> sequential.updateSequential()})
    )

    let batched = EntityReducerBatchBench(size, width)
    report(
        "micro",
        "Entity reducer batch",
        timeit("${size} 项 / ${width} Action 批次", iterations, {=> batched.updateBatch()})
    )
    reportCount("Entity reducer batch", "${size} 项 / ${width} Action 规模", batched.batchSize())
}

private func runEntityTableBatchBench(size: Int64, width: Int64, iterations: Int64): Unit {
    let sequential = EntityTableBatchBench(size, width)
    report(
        "micro",
        "EntityTable batch",
        timeit("${size} 项 / ${width} 更新逐次", iterations, {=> sequential.updateSequential()})
    )

    let batched = EntityTableBatchBench(size, width)
    report(
        "micro",
        "EntityTable batch",
        timeit("${size} 项 / ${width} 更新批次", iterations, {=> batched.updateBatch()})
    )
    reportCount("EntityTable batch", "${size} 项 / ${width} 更新规模", batched.batchSize())
}

private func runEntityTableBench(size: Int64, iterations: Int64): Unit {
    let linear = EntityTableBench(size)
    report("micro", "EntityTable", timeit("${size} 项线性数组更新", iterations, {=> linear.updateLinear()}))

    let clonedMap = EntityTableBench(size)
    report("micro", "EntityTable", timeit("${size} 项克隆 HashMap 更新", iterations, {=> clonedMap.updateClonedMap()}))

    let persistent = EntityTableBench(size)
    report("micro", "EntityTable", timeit("${size} 项持久表更新", iterations, {=> persistent.updatePersistent()}))
    reportCount("EntityTable", "${size} 项实体规模", persistent.persistentSize())

    let linearReads: Int64 = if (size <= 16) {
        1000000
    } else if (size <= 1024) {
        250000
    } else if (size <= 10000) {
        30000
    } else {
        3000
    }
    let indexedReads = max(linearReads, Int64(500000))
    report("micro", "EntityTable", timeit("${size} 项线性 ID 读取", linearReads, {=> linear.readLinear()}))
    report("micro", "EntityTable", timeit("${size} 项 HashMap 读取", indexedReads, {=> clonedMap.readMap()}))
    report("micro", "EntityTable", timeit("${size} 项持久表读取", indexedReads, {=> persistent.readPersistent()}))
}
