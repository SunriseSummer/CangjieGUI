/*
 * 浏览器状态：当前路径（根之下的文件夹名序列）。
 *
 * 当前目录内容、面包屑分段都是路径的纯函数派生；进入子文件夹压入路径，点面包屑某段截断路径。
 */
package cui_explorer

import cui.State

class ExplorerModel {
    let root: FsNode = buildTree()
    let path = State<Array<String>>([])

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

    // 进入子文件夹。
    func openFolder(name: String): Unit {
        path.value = pathInto(path.value, name)
    }

    // 点面包屑第 index 段跳转（0 为根）。
    func navigateTo(segmentIndex: Int64): Unit {
        path.value = pathForSegment(path.value, segmentIndex)
    }
}
