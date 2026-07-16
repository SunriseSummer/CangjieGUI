/*
 * 工作台视图层：三区分栏布局，边界皆可拖动。
 *
 *  - 外层横向 `SplitView`：左侧文档导航 | 右侧工作区，拖动分隔条重分配宽度。
 *  - 右侧嵌套纵向 `SplitView`：上方编辑器 / 下方大纲与统计，拖动分隔条重分配高度。
 *  - 分隔条可 Tab 聚焦、方向键微调，悬停显示对应的横向/纵向调整光标。
 *  - 大纲与统计由正文实时派生（见 model 的 `derive`），编辑即刻反映到右下信息区。
 */
package cui_workbench

import cui.{Axis, ButtonRole, CrossAxisAlignment, Divider, FontSizes, ForEach, HStack, IconButton, IconName, Label,
    LengthUnits, ListView, Panel, ScrollView, Spacer, SplitView, TextArea, Tooltip, VStack}

func workbenchView(model: WorkbenchModel): Unit {
    VStack {
        appHeader(model)
        // 外层横向分栏占据抬头以下的全部空间；侧栏比例由模型持有，可跨文档切换延续。
        SplitView(axis: Axis.Horizontal, ratio: model.sidebarRatio, minFirst: 170.0, minSecond: 360.0,
            first: {=> sidebar(model)}) {
            => workArea(model)
        }
    }.spacing(14.vp).padding(16.vp)
}

func appHeader(model: WorkbenchModel): Unit {
    HStack {
        VStack {
            Label("工作台").fontSize(WORKBENCH_TITLE)
            Label("拖动分隔条重分配三区；分隔条可 Tab 聚焦、方向键微调").muted().fontSize(FontSizes.CAPTION)
        }.spacing(2.vp).hug()
        Spacer()
        Tooltip(text: "新建文档") {
            IconButton(IconName.NewDocument) {
                => model.addDoc()
            }.label("新建").role(ButtonRole.Primary)
        }
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func sidebar(model: WorkbenchModel): Unit {
    Panel {
        VStack {
            Label("文档").muted().fontSize(FontSizes.CAPTION)
            ListView(model.titles(), model.selected)
        }.spacing(8.vp)
    }.contentPadding(10.vp)
}

// 右侧工作区：编辑器与信息面板的纵向分栏。
func workArea(model: WorkbenchModel): Unit {
    SplitView(axis: Axis.Vertical, ratio: model.editorRatio, minFirst: 160.0, minSecond: 120.0,
        first: {=> editorPane(model)}) {
        => infoPane(model)
    }
}

func editorPane(model: WorkbenchModel): Unit {
    Panel {
        VStack {
            HStack {
                Label(model.currentTitle()).fontSize(FontSizes.TITLE)
                Spacer()
                Label("Markdown · Ctrl+Z 撤销").muted().fontSize(FontSizes.CAPTION)
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            TextArea(model.body, key: model.editorId())
        }.spacing(10.vp)
    }.contentPadding(14.vp)
}

func infoPane(model: WorkbenchModel): Unit {
    Panel {
        VStack {
            Label("大纲").muted().fontSize(FontSizes.CAPTION)
            outlineList(model)
            Divider()
            Label(model.stats.value).muted().fontSize(FontSizes.CAPTION)
        }.spacing(8.vp)
    }.contentPadding(12.vp)
}

// 大纲：按标题层级缩进，一级用醒目符号、更深层级用弱化文字，长文档在此内部滚动。
func outlineList(model: WorkbenchModel): Unit {
    ScrollView {
        VStack {
            let headings = model.outline.value
            if (headings.isEmpty()) {
                Label("（正文中以 # 开头的行会成为小节）").muted().fontSize(FontSizes.CAPTION)
            }
            ForEach(headings, key: {h => "${h.level}:${h.text}"}) {
                h => outlineRow(h)
            }
        }.spacing(4.vp)
    }
}

func outlineRow(heading: Heading): Unit {
    // 一级标题作为分组抬头：无前缀、正文色；更深层级缩进并加中点、弱化文字。
    let indent = Float32(max(0, heading.level - 1)) * 14.0
    if (heading.level <= 1) {
        Label(heading.text).fontSize(FontSizes.BODY)
    } else {
        Label("· ${heading.text}").fontSize(FontSizes.BODY).muted().padding(indent, 0.0, 0.0, 0.0)
    }
}
