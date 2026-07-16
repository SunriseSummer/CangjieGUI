/*
 * 文件浏览器数据：以 `TreeNode` 描述一棵（本项目的）目录树，并按 id 建索引供详情面板查询。
 *
 * 约定每个节点的 id 即其完整路径、label 为末段名；因此路径面包屑可直接由 id 拆分得到，选中项的
 * 元信息（是否文件夹、子项数）由一次遍历建成的 `HashMap` 查得，无需在树上回溯。
 */
package cui_file_explorer

import std.collection.HashMap
import cui.{IconName, TreeNode}

/** 选中节点的元信息，供详情面板展示。 */
struct FileInfo {
    let path: String
    let name: String
    let isFolder: Bool
    let childCount: Int64

    init(path: String, name: String, isFolder: Bool, childCount: Int64) {
        this.path = path
        this.name = name
        this.isFolder = isFolder
        this.childCount = childCount
    }
}

func folder(path: String, children: Array<TreeNode>): TreeNode {
    TreeNode(path, basename(path), children: children, icon: IconName.OpenFolder)
}

func file(path: String): TreeNode {
    TreeNode(path, basename(path), icon: IconName.NewDocument)
}

/** 路径末段（去掉目录前缀）。空串 split 得空数组，故取末段前判空。 */
func basename(path: String): String {
    let segments = path.split("/")
    if (segments.isEmpty()) {
        path
    } else {
        segments[segments.size - 1]
    }
}

/** 一棵示意目录树：本项目的主要结构（截取，足以演示展开/折叠与层级导航）。 */
func seedRoots(): Array<TreeNode> {
    [
        folder("CangjieGUI", [
            folder("CangjieGUI/src", [
                folder("CangjieGUI/src/core", [
                    file("CangjieGUI/src/core/widget.cj"),
                    file("CangjieGUI/src/core/state.cj"),
                    file("CangjieGUI/src/core/layout_widgets.cj"),
                    file("CangjieGUI/src/core/split_view.cj")
                ]),
                folder("CangjieGUI/src/controls", [
                    file("CangjieGUI/src/controls/selection_widgets.cj"),
                    file("CangjieGUI/src/controls/table.cj"),
                    file("CangjieGUI/src/controls/tree_view.cj")
                ]),
                folder("CangjieGUI/src/text", [
                    file("CangjieGUI/src/text/text_field.cj"),
                    file("CangjieGUI/src/text/text_area.cj")
                ])
            ]),
            folder("CangjieGUI/examples", [
                folder("CangjieGUI/examples/workbench", [
                    file("CangjieGUI/examples/workbench/README.md")
                ]),
                folder("CangjieGUI/examples/file_explorer", [
                    file("CangjieGUI/examples/file_explorer/README.md")
                ])
            ]),
            folder("CangjieGUI/docs", [
                file("CangjieGUI/docs/components.md"),
                file("CangjieGUI/docs/architecture.md")
            ]),
            file("CangjieGUI/README.md"),
            file("CangjieGUI/LICENSE")
        ])
    ]
}

/** 遍历树，为每个节点建立 id → 元信息的索引。 */
func buildIndex(roots: Array<TreeNode>): HashMap<String, FileInfo> {
    let index = HashMap<String, FileInfo>()
    for (root in roots) {
        indexNode(index, root)
    }
    index
}

func indexNode(index: HashMap<String, FileInfo>, node: TreeNode): Unit {
    let isFolder = !node.children.isEmpty()
    index.add(node.id, FileInfo(node.id, node.label, isFolder, node.children.size))
    for (child in node.children) {
        indexNode(index, child)
    }
}

/** 文件扩展名（含点），无扩展名时回退占位。 */
func extensionOf(name: String): String {
    let parts = name.split(".")
    if (parts.size > 1) {
        ".${parts[parts.size - 1]}"
    } else {
        "无扩展名"
    }
}

/** 面包屑：把路径的 "/" 展开为分隔样式。 */
func breadcrumb(path: String): String {
    path.replace("/", "  /  ")
}
