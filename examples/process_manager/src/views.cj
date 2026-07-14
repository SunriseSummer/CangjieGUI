/*
 * 视图层：工具栏、进程文本页与概览卡片。
 *
 *  - 只描述界面结构；刷新调度在 worker.cj，展示文案全部由 model.cj 派生
 *  - 事实卡片用 ForEach 按标题建立稳定身份；显示器型号等长文本用 maxLines
 *    截断，不会撑破卡片
 *  - 尺寸一律使用 vp 单位表达
 */
package cui_process_manager

import cui.{ButtonRole, FontSizes, ForEach, HStack, IconButton, IconName, Label, LengthUnits, Panel, ProgressBar,
    Spacer, TabView, Table, TableColumn, VStack}

func processView(model: ProcessModel, worker: RefreshWorker, facts: Array<SystemFact>): Unit {
    VStack {
        toolbar(model, worker)
        TabView(["进程", "概览"], model.tab) {
            processPage(model)
            summaryPage(model, facts)
        }
    }.padding(14.vp)
}

// 顶栏：手动刷新按钮、状态文字与自动刷新说明。按钮标识由框架按构建顺序自动分配。
func toolbar(model: ProcessModel, worker: RefreshWorker): Unit {
    Panel {
        HStack {
            IconButton(IconName.Refresh) {
                => worker.request()
            }.label("刷新").role(ButtonRole.Primary)
            Label(statusText(model, worker)).muted()
            Spacer()
            Label("每 ${Refresh.INTERVAL_MS / Refresh.MS_PER_SECOND} 秒自动刷新")
                .muted()
                .fontSize(FontSizes.CAPTION)
        }
    }.contentPadding(10.vp).hug()
}

/*
 * 进程页：把 tasklist 快照展示为可排序的数据表格（映像名称/PID/会话名/内存 KB）。
 * 快照尚未到达或采集出错时表格为空，回退成一行状态文本，保留错误可见性。
 */
func processPage(model: ProcessModel): Unit {
    let rows = model.processRows.value
    if (rows.isEmpty()) {
        Panel {
            Label(model.output.value).muted()
        }.contentPadding(12.vp).flex()
    }
    if (!rows.isEmpty()) {
        Table("process.table", processColumns(), rows, model.selectedRow).flex()
    }
}

func processColumns(): Array<TableColumn> {
    [
        TableColumn("映像名称", 260.0),
        TableColumn("PID", 100.0, numeric: true),
        TableColumn("会话名", 160.0),
        TableColumn("内存 (KB)", 140.0, numeric: true)
    ]
}

// 刷新进行中的提示优先；空闲时显示距上次快照上屏过去了多久。
func statusText(model: ProcessModel, worker: RefreshWorker): String {
    if (worker.isBusy()) {
        "正在刷新……"
    } else {
        model.refreshAge.value
    }
}

func summaryPage(model: ProcessModel, facts: Array<SystemFact>): Unit {
    VStack {
        ForEach(facts, key: {fact => "fact.${fact.title}"}) {
            fact => factCard(fact)
        }
        snapshotCard(model)
        Spacer()
    }.spacing(10.vp).padding(6.vp)
}

func factCard(fact: SystemFact): Unit {
    Panel {
        VStack {
            Label(fact.title).muted().fontSize(FontSizes.CAPTION)
            // 显示器型号等文案长度不可控，限两行以省略号收尾，防止溢出卡片。
            Label(fact.value).fontSize(FontSizes.TITLE).maxLines(2)
        }.spacing(6.vp).hug()
    }.contentPadding(12.vp).hug()
}

func snapshotCard(model: ProcessModel): Unit {
    Panel {
        VStack {
            Label("进程快照大小").muted().fontSize(FontSizes.CAPTION)
            ProgressBar(model.snapshotFraction)
            Label(model.snapshotBytes.value).muted().fontSize(FontSizes.CAPTION)
        }.spacing(8.vp).hug()
    }.contentPadding(12.vp).hug()
}
