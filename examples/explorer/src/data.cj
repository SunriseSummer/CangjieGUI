/*
 * 文件浏览器示例的模拟文件树与纯导航逻辑。
 *
 * 目录树是不可变的 `FsNode` 结构，节点带列表展示用的元数据（文件大小、修改日期，演示数据为固定值）；
 * 沿路径查找、列目录、面包屑分段/导航、大小格式化都是纯函数，便于单测且与视图无关。
 */
package cui_explorer

import std.collection.ArrayList

// 目录树节点（文件夹或文件），附列表展示用的元数据。
class FsNode {
    let name: String
    let isDir: Bool
    let children: Array<FsNode>
    let sizeBytes: Int64 // 文件字节数；文件夹为 0（列表中展示子项数）
    let modified: String // 修改日期（演示数据为固定值）

    init(name: String, isDir: Bool, children: Array<FsNode>, sizeBytes: Int64, modified: String) {
        this.name = name
        this.isDir = isDir
        this.children = children
        this.sizeBytes = sizeBytes
        this.modified = modified
    }
}

func fsFile(name: String, sizeBytes: Int64, modified: String): FsNode {
    FsNode(name, false, [], sizeBytes, modified)
}

func fsDir(name: String, modified: String, children: Array<FsNode>): FsNode {
    FsNode(name, true, children, 0, modified)
}

/** 字节数格式化为 B/KB/MB（KB 向上取整、MB 保留一位小数），与资源管理器惯例一致。 */
func formatSize(bytes: Int64): String {
    if (bytes < 1024) {
        return "${bytes} B"
    }
    if (bytes < 1024 * 1024) {
        return "${(bytes + 1023) / 1024} KB"
    }
    let whole = bytes / (1024 * 1024)
    let tenth = bytes % (1024 * 1024) * 10 / (1024 * 1024)
    "${whole}.${tenth} MB"
}

// 一棵固定的示例目录树（根名为“根目录”）。
func buildTree(): FsNode {
    fsDir("根目录", "2026-07-14", [
        fsDir("文档", "2026-07-12", [
            fsDir("工作", "2026-07-12", [
                fsFile("季度报告.docx", 48_640, "2026-07-10"),
                fsFile("预算.xlsx", 23_120, "2026-07-12"),
                fsDir("归档", "2026-01-05", [fsDir("2025", "2026-01-05", [fsFile("旧报告.pdf", 1_284_000, "2025-12-30")])])
            ]),
            fsDir("个人", "2026-06-21", [
                fsFile("简历.pdf", 186_000, "2026-05-08"),
                fsDir("照片", "2026-06-21", [fsFile("头像.png", 215_040, "2026-06-21"), fsFile("风景.jpg", 2_458_000, "2026-06-02")])
            ]),
            fsFile("说明.txt", 940, "2026-04-15")
        ]),
        fsDir("下载", "2026-07-14", [fsFile("安装包.dmg", 734_000_000, "2026-07-14"), fsFile("壁纸.jpg", 3_640_000, "2026-07-01")]),
        fsDir("项目", "2026-07-13", [
            fsDir("cangjie-gui", "2026-07-13", [
                fsFile("README.md", 5_210, "2026-07-09"),
                fsDir("src", "2026-07-13", [fsFile("main.cj", 1_180, "2026-07-13"), fsFile("views.cj", 2_460, "2026-07-13")])
            ]),
            fsFile("笔记.md", 2_380, "2026-07-06")
        ]),
        fsFile("待办.txt", 312, "2026-07-14")
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
