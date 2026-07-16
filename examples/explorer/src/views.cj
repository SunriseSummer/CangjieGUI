/*
 * 浏览器视图层：标题 + 工具栏（上级 + 面包屑）+ 目录列表（列头 + 条目行）+ 底部状态栏。
 *
 *  - 工具栏左侧“上级”按钮返回上一级（根目录下置灰），右侧 `Breadcrumb` 显示 根目录 › … › 当前 的路径，
 *    点任意一段跳回该层（末段为当前、不可点，超长自动折叠省略号）——上下两个方向的导航都一步可达。
 *  - 列表按 名称 / 修改日期 / 大小 三列展示，列头与条目行共享列几何；整行可点：单击文件夹进入、
 *    单击文件选中，悬停高亮（见 `EntryRow`）。
 *  - 底部状态栏展示条目计数与选中文件的详情，符合文件管理器惯例。
 */
package cui_explorer

import cui.{Breadcrumb, CrossAxisAlignment, Divider, FontSizes, HStack, IconButton, IconName, Label, LengthUnits,
    Panel, ScrollView, Spacer, VStack}

func explorerView(model: ExplorerModel): Unit {
    VStack {
        header()
        toolbar(model)
        Panel {
            VStack {
                EntryHeaderRow()
                Divider()
                entryList(model)
            }.spacing(4.vp)
        }.contentPadding(10.vp).flex()
        statusBar(model)
    }.spacing(12.vp).padding(16.vp)
}

func header(): Unit {
    VStack {
        Label("文件浏览器").fontSize(FontSizes.TITLE)
        Label("单击文件夹进入、文件选中；“上级”或面包屑跳回上层").muted().fontSize(FontSizes.CAPTION)
    }.spacing(3.vp).hug()
}

func toolbar(model: ExplorerModel): Unit {
    Panel {
        HStack {
            IconButton(IconName.ChevronLeft, label: "上级", onClick: {=> model.goUp()}).enabled(model.canGoUp())
            Breadcrumb(model.segments(), onSelect: {i => model.navigateTo(i)}, maxItems: 4)
            Spacer()
        }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center)
    }.contentPadding(8.vp).hug()
}

func entryList(model: ExplorerModel): Unit {
    let entries = model.entries()
    ScrollView {
        VStack {
            if (entries.size == 0) {
                Label("（空文件夹）").muted().fontSize(FontSizes.CAPTION).padding(8.vp)
            }
            for (entry in entries) {
                EntryRow(entry, isEntrySelected(model, entry), {=> activate(model, entry)})
            }
        }.spacing(2.vp)
    }.flex()
}

private func isEntrySelected(model: ExplorerModel, entry: FsNode): Bool {
    !entry.isDir && model.selected.value == entry.name
}

private func activate(model: ExplorerModel, entry: FsNode): Unit {
    if (entry.isDir) {
        model.openFolder(entry.name)
    } else {
        model.selectFile(entry.name)
    }
}

func statusBar(model: ExplorerModel): Unit {
    HStack {
        Label("${model.entries().size} 个项目（${model.folderCount()} 个文件夹、${model.fileCount()} 个文件）")
            .muted().fontSize(FontSizes.CAPTION)
        Spacer()
        match (model.selectedFile()) {
            case Some(file) => Label("已选择：${file.name}（${formatSize(file.sizeBytes)}）").muted()
                .fontSize(FontSizes.CAPTION)
            case None => ()
        }
    }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
}
