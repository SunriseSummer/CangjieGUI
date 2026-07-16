/*
 * 文件浏览器示例的模拟文件树与纯导航逻辑。
 *
 * 目录树是不可变的 `FsNode` 结构；沿路径查找、列目录、面包屑分段/导航都是纯函数，便于单测且与视图无关。
 */
package cui_explorer

import std.collection.ArrayList

// 目录树节点（文件夹或文件）。
class FsNode {
    let name: String
    let isDir: Bool
    let children: Array<FsNode>

    init(name: String, isDir: Bool, children: Array<FsNode>) {
        this.name = name
        this.isDir = isDir
        this.children = children
    }
}

func fsFile(name: String): FsNode {
    FsNode(name, false, [])
}

func fsDir(name: String, children: Array<FsNode>): FsNode {
    FsNode(name, true, children)
}

// 一棵固定的示例目录树（根名为“根目录”）。
func buildTree(): FsNode {
    fsDir("根目录", [
        fsDir("文档", [
            fsDir("工作", [
                fsFile("季度报告.docx"),
                fsFile("预算.xlsx"),
                fsDir("归档", [fsDir("2025", [fsFile("旧报告.pdf")])])
            ]),
            fsDir("个人", [fsFile("简历.pdf"), fsDir("照片", [fsFile("头像.png"), fsFile("风景.jpg")])]),
            fsFile("说明.txt")
        ]),
        fsDir("下载", [fsFile("安装包.dmg"), fsFile("壁纸.jpg")]),
        fsDir("项目", [
            fsDir("cangjie-gui", [fsFile("README.md"), fsDir("src", [fsFile("main.cj"), fsFile("views.cj")])]),
            fsFile("笔记.md")
        ]),
        fsFile("待办.txt")
    ])
}

// 沿 path（根之下的文件夹名序列）走到的节点；路径无效时为 None。
func nodeAt(root: FsNode, path: Array<String>): ?FsNode {
    var cur = root
    for (name in path) {
        var next: ?FsNode = None
        for (c in cur.children) {
            if (c.isDir && c.name == name) {
                next = c
                break
            }
        }
        match (next) {
            case Some(n) => cur = n
            case None => return None
        }
    }
    Some(cur)
}

// 当前 path 目录下的子项，文件夹在前、文件在后（各自保持声明序）。
func childrenAt(root: FsNode, path: Array<String>): Array<FsNode> {
    match (nodeAt(root, path)) {
        case Some(n) => sortedChildren(n.children)
        case None => []
    }
}

func sortedChildren(children: Array<FsNode>): Array<FsNode> {
    let out = ArrayList<FsNode>()
    for (c in children) {
        if (c.isDir) {
            out.add(c)
        }
    }
    for (c in children) {
        if (!c.isDir) {
            out.add(c)
        }
    }
    out.toArray()
}

// 面包屑各段：["根目录", ...path]。
func pathSegments(path: Array<String>): Array<String> {
    let out = ArrayList<String>()
    out.add("根目录")
    for (p in path) {
        out.add(p)
    }
    out.toArray()
}

// 导航到面包屑第 index 段：0 为根，否则取 path 前 index 段。
func pathForSegment(path: Array<String>, index: Int64): Array<String> {
    let out = ArrayList<String>()
    var i = 0
    while (i < index && i < path.size) {
        out.add(path[i])
        i += 1
    }
    out.toArray()
}

// 进入子文件夹：path + [name]。
func pathInto(path: Array<String>, name: String): Array<String> {
    let out = ArrayList<String>()
    for (p in path) {
        out.add(p)
    }
    out.add(name)
    out.toArray()
}
