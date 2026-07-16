/*
 * 浏览器视图层：标题 + 面包屑路径 + 当前目录内容列表。
 *
 *  - 顶部 `Breadcrumb` 显示 根目录 › … › 当前 的路径，点任意一段跳回该层（末段为当前、不可点，超长自动折叠省略号）。
 *  - 下方逐项列出当前目录：文件夹可点（进入），文件为静态行；文件夹在前、文件在后。
 */
package cui_explorer

import cui.{Breadcrumb, Button, CrossAxisAlignment, FontSizes, HStack, Icon, IconName, Label, LengthUnits, Panel,
    ScrollView, Spacer, VStack}

func explorerView(model: ExplorerModel): Unit {
    VStack {
        header(model)
        Panel {
            Breadcrumb(model.segments(), onSelect: {i => model.navigateTo(i)}, maxItems: 4)
        }.contentPadding(10.vp).hug()
        Panel {
            entryList(model)
        }.contentPadding(10.vp).flex()
    }.spacing(12.vp).padding(16.vp)
}

func header(model: ExplorerModel): Unit {
    VStack {
        Label("文件浏览器").fontSize(FontSizes.TITLE)
        Label(headerHint(model)).muted().fontSize(FontSizes.CAPTION)
    }.spacing(3.vp).hug()
}

private func headerHint(model: ExplorerModel): String {
    if (model.isRoot()) {
        "点文件夹进入；当前已在根目录"
    } else {
        "点文件夹进入，点上方面包屑任意一段跳回"
    }
}

func entryList(model: ExplorerModel): Unit {
    let entries = model.entries()
    ScrollView {
        VStack {
            if (entries.size == 0) {
                Label("（空文件夹）").muted().fontSize(FontSizes.CAPTION)
            }
            for (entry in entries) {
                if (entry.isDir) {
                    folderRow(model, entry.name)
                } else {
                    fileRow(entry.name)
                }
            }
        }.spacing(2.vp)
    }.flex()
}

private func folderRow(model: ExplorerModel, name: String): Unit {
    HStack {
        Icon(IconName.OpenFolder).foregroundColor(EXPLORER_FOLDER).iconSize(20.vp)
        Button(name, {=> model.openFolder(name)})
        Spacer()
        Icon(IconName.ChevronRight).foregroundColor(EXPLORER_MUTED).iconSize(16.vp)
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}

private func fileRow(name: String): Unit {
    HStack {
        Icon(IconName.NewDocument).foregroundColor(EXPLORER_MUTED).iconSize(20.vp)
        Label(name)
        Spacer()
    }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
}
