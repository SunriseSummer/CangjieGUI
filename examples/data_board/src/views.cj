/*
 * 看板视图层。
 *
 *  - 三列都从 BoardModel 的单一数据源渲染；列头计数是 DerivedState，与卡片数
 *    永远一致
 *  - 卡片列表用 ForEach 按任务 id 建立稳定身份，插入新卡不会扰动其余卡片状态
 *  - 筛选器直接作用于三列可见集合；“新增任务／添加到某列”会真正追加卡片
 *  - 进行中数量超过在制上限时，列头计数切换为警示色
 */
package cui_data_board

import cui.{Button, ButtonRole, Color, CrossAxisAlignment, FlowRow, FontSizes, ForEach, Grid, HStack, Icon, IconName,
    Label, LengthUnits, Panel, Picker, ScrollView, Spacer, State, Stepper, Switch, VStack}

func boardView(model: BoardModel): Unit {
    VStack {
        boardHeader(model)
        Grid(3) {
            boardColumn(model, "待规划", model.plannedCount.value, Color.rgb(98, 112, 132), model.planned,
                model.visiblePlanned())
            boardColumn(model, "进行中", model.doingCount.value, doingAccent(model), model.doing,
                model.visibleDoing())
            boardColumn(model, "已完成", model.doneCount.value, Color.rgb(24, 145, 105), model.done,
                model.visibleDone())
        }.spacing(14.vp).flex()
    }.spacing(14.vp).padding(18.vp)
}

func doingAccent(model: BoardModel): Color {
    if (model.wipExceeded.value) {
        WIP_WARNING
    } else {
        Color.rgb(54, 116, 210)
    }
}

func boardHeader(model: BoardModel): Unit {
    Panel {
        // 居中对齐让定高控件保持自然高度（38vp），而不是被两行标题撑高的行拉伸变形。
        HStack {
            Icon(IconName.Process).foregroundColor(Color.rgb(54, 116, 210)).iconSize(22.vp)
            VStack {
                Label("产品看板").fontSize(FontSizes.TITLE)
                Label("Northstar · 桌面端体验迭代").muted().fontSize(FontSizes.CAPTION)
            }.spacing(2.vp).hug()
            Spacer()
            Picker("board.filter", FILTER_LABELS, model.filter)
            Switch("紧凑卡片", model.compact)
            Label("在制上限").muted().fontSize(FontSizes.CAPTION)
            Stepper("board.wip", model.wipLimit).range(2, 8)
            Button("新增任务", {=> model.addTask(model.planned)}).role(ButtonRole.Primary)
        }.crossAxisAlignment(CrossAxisAlignment.Center)
    }.contentPadding(12.vp).hug()
}

func boardColumn(
    model: BoardModel,
    title: String,
    count: String,
    accent: Color,
    column: State<Array<Task>>,
    visible: Array<Task>
): Unit {
    Panel {
        VStack {
            HStack {
                Label(title).fontSize(BOARD_HEADING)
                Spacer()
                Label(count).foregroundColor(accent).fontSize(FontSizes.CAPTION)
            }.hug()
            // 卡片区在列内滚动：窗口调矮时卡片不会溢出面板，多出的卡片滚动可达，
            // “添加”按钮始终钉在列底。
            ScrollView("board.cards.${title}") {
                VStack {
                    ForEach(visible, key: {task => "task.${task.id}"}) {
                        task => taskCard(task, model.compact.value)
                    }
                }.spacing(10.vp).hug()
            }.flex()
            Button("添加到${title}", {=> model.addTask(column)}).fillWidth()
        }.spacing(10.vp)
    }.contentPadding(12.vp).style(columnSurface())
}

func taskCard(task: Task, compact: Bool): Unit {
    Panel {
        VStack {
            Label(task.title).fontSize(pick(compact, 15.fp, BOARD_HEADING)).maxLines(2)
            if (!compact) {
                Label("负责人 · ${task.owner}").muted().fontSize(FontSizes.CAPTION)
            }
            FlowRow {
                for (tag in task.tags) {
                    tagPill(tag)
                }
                Spacer()
                Label(task.due).muted().fontSize(FontSizes.CAPTION)
            }.spacing(6.vp)
        }.spacing(pick(compact, 5.vp, 8.vp)).hug()
    }.contentPadding(pick(compact, 10.vp, 14.vp)).style(taskSurface()).hug()
}

func tagPill(text: String): Unit {
    Label(text)
        .foregroundColor(Color.rgb(54, 91, 161))
        .fontSize(FontSizes.CAPTION)
        .padding(8.vp, 4.vp)
        .background(Color.rgb(232, 239, 252), 999.vp)
}

/** 按密度二选一的小工具，避免视图里重复三元分支。 */
func pick<T>(compact: Bool, whenCompact: T, whenComfort: T): T {
    if (compact) {
        whenCompact
    } else {
        whenComfort
    }
}
