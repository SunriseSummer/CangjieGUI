package bench_micro

import std.collection.ArrayList
import cui.{DerivedState, State, StateObservation, WidgetTestHost}
import bench_harness.{report, reportCount, timeit}

private class DerivedTransactionCounter {
    var callbacks: Int64 = 0

    func hit(): Unit {
        callbacks += 1
    }
}

func runDerivedObserverTransactionBenches(): Unit {
    runDerivedObserverTransactionBench(1, 250000)
    runDerivedObserverTransactionBench(32, 20000)
}

private func runDerivedObserverTransactionBench(observerCount: Int64, transactions: Int64): Unit {
    let host = WidgetTestHost()
    let source = State<Int64>(0)
    let derived = Array<DerivedState<Int64>>(observerCount,
        {index => source.map<Int64>({value => value + index})})
    let counter = DerivedTransactionCounter()
    let observations = ArrayList<StateObservation<Int64>>()
    for (value in derived) {
        observations.add(value.observe({_, _ => counter.hit()}))
    }

    report("micro", "派生观察事务", timeit("${observerCount} 个派生观察者", transactions, {
        =>
            host.batch({=> source.value += 1})
            source.value + counter.callbacks
    }))
    let expected = observerCount * transactions
    if (counter.callbacks != expected) {
        throw IllegalStateException(
            "Derived transaction benchmark expected ${expected} callbacks, got ${counter.callbacks}")
    }
    reportCount("派生观察事务", "${observerCount} 个观察者回调", UInt64(counter.callbacks))
    for (observation in observations) {
        observation.close()
    }
}
