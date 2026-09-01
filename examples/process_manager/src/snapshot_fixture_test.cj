package cui_process_manager

@Test
func processSnapshotFixtureActivatesOnlyForSnapshotRuns(): Unit {
    @Expect(processSnapshotFixture(["app"]).isNone())
    @Expect(processSnapshotFixture(["app", "--cui-force-full-retained"]).isNone())

    let fixture = processSnapshotFixture(["app", "--snapshot", "result.bmp"])
    match (fixture) {
        case Some(snapshot) =>
            let rows = parseProcessRows(snapshot)
            @Expect(rows.size, Int64(16))
            @Expect(rows[7], ["csrss.exe", "1156", "Console", "8188"])
        case None => @Expect(false)
    }
}

@Test
func snapshotWorkerSeedsTheMailboxBeforeItsFirstFrame(): Unit {
    let fixture = processSnapshotFixture(["app", "--snapshot", "result.bmp"])
    let worker = RefreshWorker(snapshotFixture: fixture)
    match (worker.collect()) {
        case Some(snapshot) => @Expect(parseProcessRows(snapshot).size, Int64(16))
        case None => @Expect(false)
    }
    @Expect(worker.isBusy(), false)
}
