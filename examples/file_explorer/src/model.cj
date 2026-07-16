/*
 * 文件浏览器状态：一棵目录树、按 id 的元信息索引，以及当前选中项。
 *
 * `TreeView` 的选中项是节点 id（此处即路径），详情面板据此从索引查得元信息、由 id 拆出面包屑，
 * 两侧数据单向流动、无冗余副本。初始展开集让 `src/core` 一路打开，使初始选中的文件可见。
 */
package cui_file_explorer

import std.collection.HashMap
import cui.{State, TreeNode}

class ExplorerModel {
    let roots: Array<TreeNode>
    let index: HashMap<String, FileInfo>
    let selected = State<String>("CangjieGUI/src/core/split_view.cj")
    // 初始展开：根、src、core 依次打开，恰好露出初始选中的文件。
    let initiallyExpanded = ["CangjieGUI", "CangjieGUI/src", "CangjieGUI/src/core"]

    init() {
        this.roots = seedRoots()
        this.index = buildIndex(this.roots)
    }

    /** 选中节点的元信息（未选中或未知 id 时为 None）。 */
    func infoFor(id: String): ?FileInfo {
        index.get(id)
    }
}
