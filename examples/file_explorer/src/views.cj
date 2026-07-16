/*
 * 文件浏览器视图层：左树右详情的经典资源管理器布局。
 *
 *  - 用上一组件 `SplitView` 分出可拖动的左右两栏（导航｜详情），互相印证组件间的组合。
 *  - 左栏 `TreeView` 展示目录树：点击箭头展开/折叠、点击行选中；Tab 聚焦后 ↑↓ 移动、
 *    →/← 展开折叠、空格切换，图标区分文件夹与文件。
 *  - 右栏详情由选中项 id 从索引查得，路径面包屑直接由 id 拆分得到。
 */
package cui_file_explorer

import cui.{Axis, CrossAxisAlignment, Divider, FontSizes, HStack, Icon, IconName, Label, LengthUnits, Panel, Spacer,
    SplitView, TextAlign, TreeView, VStack}

func explorerView(model: ExplorerModel): Unit {
    VStack {
        appHeader()
        SplitView(axis: Axis.Horizontal, initialRatio: 0.42, minFirst: 220.0, minSecond: 260.0,
            first: {=> treePane(model)}) {
            => detailPane(model)
        }
    }.spacing(14.vp).padding(16.vp)
}

func appHeader(): Unit {
    VStack {
        Label("文件浏览器").fontSize(EXPLORER_TITLE)
        Label("左树：点击箭头展开、点击行选中；Tab 聚焦后 ↑↓ 移动、→ 展开、← 折叠、空格切换").muted()
            .fontSize(FontSizes.CAPTION)
    }.spacing(2.vp).hug()
}

func treePane(model: ExplorerModel): Unit {
    Panel {
        TreeView(model.roots, model.selected, initiallyExpanded: model.initiallyExpanded)
    }.contentPadding(8.vp)
}

func detailPane(model: ExplorerModel): Unit {
    Panel {
        match (model.infoFor(model.selected.value)) {
            case Some(info) => detailBody(info)
            case None =>
                VStack {
                    Spacer()
                    Label("从左侧选择文件或文件夹查看详情").muted().textAlign(TextAlign.Center)
                    Spacer()
                }
        }
    }.contentPadding(16.vp)
}

func detailBody(info: FileInfo): Unit {
    VStack {
        HStack {
            Icon(iconFor(info)).iconSize(26.vp)
            Label(info.name).fontSize(FontSizes.TITLE)
        }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
        Label(kindText(info)).muted()
        Divider()
        Label("路径").muted().fontSize(FontSizes.CAPTION)
        Label(breadcrumb(info.path)).wrap()
        if (info.isFolder) {
            Label("包含 ${info.childCount} 项").muted().fontSize(FontSizes.CAPTION)
        }
        Spacer()
    }.spacing(10.vp)
}

func iconFor(info: FileInfo): IconName {
    if (info.isFolder) {
        IconName.OpenFolder
    } else {
        IconName.NewDocument
    }
}

func kindText(info: FileInfo): String {
    if (info.isFolder) {
        "文件夹"
    } else {
        "文件 · ${extensionOf(info.name)}"
    }
}
