/*
 * 浏览器状态：当前路径（根之下的文件夹名序列）与选中的文件。
 *
 * 当前目录内容、面包屑分段、条目计数都是路径的纯函数派生；进入子文件夹压入路径，“上级”或面包屑截断路径。
 * 单击文件仅选中（状态栏展示详情），任何导航都清除选中——这与资源管理器的习惯一致。
 */
package cui_explorer

import cui.State

class ExplorerModel {
    let root: FsNode = buildTree()
    let path = State<Array<String>>([])
    let selected = State<String>("") // 选中的文件名；空串表示未选中

    // 面包屑各段：["根目录", ...path]。
    func segments(): Array<String> {
        pathSegments(path.value)
    }

    // 当前目录下的子项。
    func entries(): Array<FsNode> {
        childrenAt(root, path.value)
    }

    func isRoot(): Bool {
        path.value.size == 0
    }

    func canGoUp(): Bool {
        !isRoot()
    }

    // 返回上一级目录（根目录下为无操作）。
    func goUp(): Unit {
        if (path.value.size > 0) {
            path.value = pathForSegment(path.value, path.value.size - 1)
            selected.value = ""
        }
    }

    // 进入子文件夹。
    func openFolder(name: String): Unit {
        path.value = pathInto(path.value, name)
        selected.value = ""
    }

    // 点面包屑第 index 段跳转（0 为根）。
    func navigateTo(segmentIndex: Int64): Unit {
        path.value = pathForSegment(path.value, segmentIndex)
        selected.value = ""
    }

    // 单击文件：选中并在状态栏展示详情。
    func selectFile(name: String): Unit {
        selected.value = name
    }

    // 当前选中的文件节点；未选中或选中项已不在当前目录时为 None。
    func selectedFile(): ?FsNode {
        if (selected.value.isEmpty()) {
            return None
        }
        for (entry in entries()) {
            if (!entry.isDir && entry.name == selected.value) {
                return Some(entry)
            }
        }
        None
    }

    func folderCount(): Int64 {
        var count = 0
        for (entry in entries()) {
            if (entry.isDir) {
                count += 1
            }
        }
        count
    }

    func fileCount(): Int64 {
        entries().size - folderCount()
    }
}
