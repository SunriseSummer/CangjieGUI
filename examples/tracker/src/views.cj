/*
 * 追踪器视图层：标题 + 状态过滤 Chip 行 + 问题列表（每行标题 + 状态/优先级 Badge）。
 *
 *  - 顶部一排 `Chip` 按状态过滤，点选切换该状态是否显示；`Badge` 以语义色标注每条问题的状态与优先级。
 *  - 过滤开关是唯一数据源，可见列表由它与问题列表纯函数派生。
 */
package cui_tracker

import cui.{Badge, BadgeKind, Chip, CrossAxisAlignment, FlowRow, FontSizes, HStack, Label, LengthUnits, Panel,
    ScrollView, VStack}

func trackerView(model: TrackerModel): Unit {
    VStack {
        header()
        filterBar(model)
        Panel {
            issueList(model)
        }.contentPadding(14.vp).flex()
    }.spacing(12.vp).padding(16.vp)
}

func header(): Unit {
    VStack {
        Label("问题追踪").fontSize(FontSizes.TITLE)
        Label("点状态标签过滤；每条问题以彩色徽标标注状态与优先级").muted().fontSize(FontSizes.CAPTION)
    }.spacing(3.vp).hug()
}

func filterBar(model: TrackerModel): Unit {
    VStack {
        Label("按状态过滤").muted().fontSize(FontSizes.CAPTION)
        FlowRow {
            for (i in 0..STATUS_NAMES.size) {
                Chip(STATUS_NAMES[i], model.filterLens(i), key: "status-chip-${i}")
            }
        }.spacing(8.vp, 8.vp)
    }.spacing(6.vp).hug()
}

func issueList(model: TrackerModel): Unit {
    let items = model.visible()
    VStack {
        Label("问题（${items.size}/${model.total()}）").muted().fontSize(FontSizes.CAPTION)
        ScrollView {
            VStack {
                if (items.size == 0) {
                    Label("没有匹配的问题；打开上方任一状态过滤").muted().fontSize(FontSizes.CAPTION)
                }
                for (issue in items) {
                    issueRow(issue)
                }
            }.spacing(8.vp)
        }.flex()
    }.spacing(10.vp)
}

private func issueRow(issue: Issue): Unit {
    Panel {
        HStack {
            Label(issue.title).flex()
            Badge(statusName(issue.status), kind: statusKind(issue.status))
            Badge(priorityLabel(issue.priority), kind: priorityKind(issue.priority))
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.contentPadding(12.vp)
}

// 状态 → 徽标语义色。
func statusKind(status: Int64): BadgeKind {
    match (status) {
        case 0 => BadgeKind.Neutral // 待办
        case 1 => BadgeKind.Accent // 进行中
        case 2 => BadgeKind.Success // 已完成
        case _ => BadgeKind.Neutral // 已关闭
    }
}

// 优先级 → 徽标语义色。
func priorityKind(priority: Int64): BadgeKind {
    match (priority) {
        case 0 => BadgeKind.Danger // 高
        case 1 => BadgeKind.Warning // 中
        case _ => BadgeKind.Neutral // 低
    }
}
