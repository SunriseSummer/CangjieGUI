/*
 * 命令面板视图层。
 *
 *  - 搜索框 autofocus，打开即可键入；文本选区/撤销由框架内建
 *  - 上/下/回车在应用根部拦截：即使焦点在搜索框，也能移动高亮并执行——这正是命令面板的交互
 *  - 结果列表由 query 派生，可点击/悬停；执行记录累积在下方
 */
package cui_command_palette

import cui.{Color, CrossAxisAlignment, EventHandler, FontSizes, Icon, IconName, Key, Label, LengthUnits, ListView,
    Panel, ScrollView, Spacer, TextField, UiEvent, VStack, HStack}

func paletteView(model: PaletteModel): Unit {
    EventHandler(onEvent: {event => handlePaletteKeys(event, model)}) {
        VStack {
            header(model)
            searchBox(model)
            resultsPanel(model)
            hintBar(model)
            logPanel(model)
        }.spacing(12.vp).padding(18.vp)
    }
}

/*
 * 上/下移动高亮、回车执行命令——在应用根部拦截，使键盘焦点停在搜索框（而非列表）时
 * 这些键依旧生效，这正是命令面板的标志性交互。其余按键（文字输入、左/右、Ctrl+Z）
 * 继续下发给聚焦的输入框。
 */
func handlePaletteKeys(event: UiEvent, model: PaletteModel): Bool {
    match (event) {
        case UiEvent.KeyDown(Key.Up, _) =>
            model.moveSelection(-1)
            true
        case UiEvent.KeyDown(Key.Down, _) =>
            model.moveSelection(1)
            true
        case UiEvent.KeyDown(Key.Enter, _) =>
            model.runSelected()
            true
        case _ => false
    }
}

func header(model: PaletteModel): Unit {
    HStack {
        VStack {
            Label("命令面板").fontSize(PALETTE_TITLE)
            Label("键入以筛选，↑ / ↓ 选择，回车执行").muted().fontSize(FontSizes.CAPTION)
        }.spacing(3.vp).hug()
        Spacer()
        Label("${model.resultCount.value} 条").muted().fontSize(FontSizes.CAPTION)
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

func searchBox(model: PaletteModel): Unit {
    Panel {
        HStack {
            Icon(IconName.ChevronRight).foregroundColor(Color.rgb(108, 140, 255)).iconSize(18.vp)
            TextField("palette.search", model.query).autofocus().flex()
        }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center)
    }.contentPadding(12.vp, 8.vp).hug()
}

func resultsPanel(model: PaletteModel): Unit {
    Panel {
        ListView(model.resultTitles(), model.selected)
    }.contentPadding(6.vp).height(250.vp)
}

func hintBar(model: PaletteModel): Unit {
    Label(model.selectedHint()).muted().fontSize(FontSizes.CAPTION)
}

func logPanel(model: PaletteModel): Unit {
    Panel {
        VStack {
            Label("执行记录").muted().fontSize(FontSizes.CAPTION)
            ScrollView("palette.log") {
                VStack {
                    if (model.log.value.isEmpty()) {
                        Label("尚无记录。选中一条命令后按回车执行。").muted().fontSize(FontSizes.CAPTION)
                    }
                    for (entry in model.log.value) {
                        Label(entry).fontSize(FontSizes.CAPTION)
                    }
                }.spacing(4.vp).hug()
            }
        }.spacing(8.vp)
    }.contentPadding(12.vp).flex()
}
