/*
 * 活动流视图层：抬头 + 动作筛选 + 活动列表。
 *
 *  - 每条活动是一段 `RichText`：行首按动作着色的图标，随后强调色的操作者、常规色动词、动作色文件、弱化时间。
 *  - 长文件路径在卡片宽度内自动换行（`RichText` 逐字符断行、图标随文流动），短条目则单行。
 *  - 分段控件按动作类型筛选，列表由 `filtered()` 派生。
 */
package cui_activity

import cui.{FontSizes, ForEach, Label, LengthUnits, Panel, RichSpan, RichText, ScrollView, SegmentedControl, VStack}

func activityView(model: ActivityModel): Unit {
    VStack {
        appHeader()
        SegmentedControl(FILTER_LABELS, model.filter)
        feedList(model)
    }.spacing(12.vp).padding(16.vp)
}

func appHeader(): Unit {
    VStack {
        Label("文件活动").fontSize(FontSizes.TITLE)
        Label("每条活动是一段富文本：图标 + 彩色操作者 + 动词 + 彩色文件 + 弱化时间，长路径自动换行").muted()
            .fontSize(FontSizes.CAPTION)
    }.spacing(2.vp).hug()
}

func feedList(model: ActivityModel): Unit {
    ScrollView {
        VStack {
            let items = model.filtered()
            if (items.isEmpty()) {
                Label("没有此类活动").muted()
            }
            ForEach(items, key: {a => "act${a.id}"}) {
                a => activityRow(a)
            }
        }.spacing(8.vp)
    }.flex()
}

func activityRow(activity: Activity): Unit {
    Panel {
        RichText([
            RichSpan.icon(actionIcon(activity.action), color: actionColor(activity.action)),
            RichSpan.text("  ${activity.actor} ", color: ACTIVITY_ACTOR),
            RichSpan.text("${actionVerb(activity.action)} "),
            RichSpan.text(activity.file, color: actionColor(activity.action)),
            RichSpan.muted("    ${activity.time}")
        ])
    }.contentPadding(12.vp).hug()
}
