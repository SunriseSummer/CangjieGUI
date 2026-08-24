package cui.core

/* Internal aggregate exported through AutomaticScopeDiagnostics without exposing live nodes. */
struct AutomaticRenderStats {
    let nodeCount: Int64
    let layoutHits: UInt64
    let paintHits: UInt64
    let paintRecordAttempts: UInt64
    let paintDynamicBypasses: UInt64
    let paintRejectedCandidates: UInt64
    let paintBudgetEvictions: UInt64
    let paintCommandCount: Int64
    let paintEstimatedBytes: UInt64
    let paintBypassRemaining: Int64

    init(
        nodeCount: Int64,
        layoutHits: UInt64,
        paintHits: UInt64,
        paintRecordAttempts: UInt64,
        paintDynamicBypasses: UInt64,
        paintRejectedCandidates: UInt64,
        paintBudgetEvictions: UInt64,
        paintCommandCount: Int64,
        paintEstimatedBytes: UInt64,
        paintBypassRemaining: Int64
    ) {
        this.nodeCount = nodeCount
        this.layoutHits = layoutHits
        this.paintHits = paintHits
        this.paintRecordAttempts = paintRecordAttempts
        this.paintDynamicBypasses = paintDynamicBypasses
        this.paintRejectedCandidates = paintRejectedCandidates
        this.paintBudgetEvictions = paintBudgetEvictions
        this.paintCommandCount = paintCommandCount
        this.paintEstimatedBytes = paintEstimatedBytes
        this.paintBypassRemaining = paintBypassRemaining
    }
}

func automaticRenderStats(children: Array<Widget>): AutomaticRenderStats {
    var nodeCount: Int64 = 0
    var layoutHits: UInt64 = UInt64(0)
    var paintHits: UInt64 = UInt64(0)
    var paintRecordAttempts: UInt64 = UInt64(0)
    var paintDynamicBypasses: UInt64 = UInt64(0)
    var paintRejectedCandidates: UInt64 = UInt64(0)
    var paintBudgetEvictions: UInt64 = UInt64(0)
    var paintCommandCount: Int64 = 0
    var paintEstimatedBytes: UInt64 = UInt64(0)
    var paintBypassRemaining: Int64 = 0
    for (child in children) {
        match (child as AutomaticRenderNode) {
            case Some(node) =>
                let value = node.stats()
                nodeCount += value.nodeCount
                layoutHits += value.layoutHits
                paintHits += value.paintHits
                paintRecordAttempts += value.paintRecordAttempts
                paintDynamicBypasses += value.paintDynamicBypasses
                paintRejectedCandidates += value.paintRejectedCandidates
                paintBudgetEvictions += value.paintBudgetEvictions
                paintCommandCount += value.paintCommandCount
                paintEstimatedBytes += value.paintEstimatedBytes
                paintBypassRemaining = max(paintBypassRemaining, value.paintBypassRemaining)
            case None => ()
        }
    }
    AutomaticRenderStats(nodeCount, layoutHits, paintHits, paintRecordAttempts, paintDynamicBypasses,
        paintRejectedCandidates, paintBudgetEvictions, paintCommandCount, paintEstimatedBytes, paintBypassRemaining)
}
