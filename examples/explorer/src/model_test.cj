package cui_explorer

@Test
func childrenAtWalksTree(): Unit {
    let root = buildTree()
    let top = childrenAt(root, [])
    @Expect(top[0].name, "文档") // 目录在前，按声明顺序
    @Expect(top[0].isDir)
    let work = childrenAt(root, ["文档", "工作"])
    @Expect(work.size, 3) // 季度报告, 预算, 归档
    @Expect(childrenAt(root, ["不存在"]).size, 0) // 无效路径
}

@Test
func sortedChildrenDirsBeforeFiles(): Unit {
    let root = buildTree()
    let docs = childrenAt(root, ["文档"]) // 工作（目录）、个人（目录）、说明.txt（文件）
    @Expect(docs[0].isDir)
    @Expect(docs[1].isDir)
    @Expect(!docs[docs.size - 1].isDir) // 文件排在最后
}

@Test
func formatSizeUsesExplorerUnits(): Unit {
    @Expect(formatSize(312), "312 B")
    @Expect(formatSize(1024), "1 KB")
    @Expect(formatSize(23_120), "23 KB") // 22.58 KB 向上取整
    @Expect(formatSize(1_284_000), "1.2 MB") // MB 保留一位小数
    @Expect(formatSize(734_000_000), "699.9 MB") // 二进制 MB（1 MB = 1048576 B），与资源管理器一致
}

@Test
func pathSegmentsPrependRoot(): Unit {
    @Expect(pathSegments([]), ["根目录"])
    @Expect(pathSegments(["文档", "工作"]), ["根目录", "文档", "工作"])
}

@Test
func pathNavigationHelpers(): Unit {
    let path = ["文档", "工作", "归档"]
    @Expect(pathForSegment(path, 0), []) // 根目录
    @Expect(pathForSegment(path, 1), ["文档"])
    @Expect(pathForSegment(path, 2), ["文档", "工作"])
    @Expect(pathInto(["文档"], "工作"), ["文档", "工作"])
}

@Test
func modelDescendAndNavigate(): Unit {
    let model = ExplorerModel()
    @Expect(model.isRoot())
    @Expect(!model.canGoUp())
    model.openFolder("文档")
    model.openFolder("工作")
    @Expect(model.path.value, ["文档", "工作"])
    @Expect(model.segments(), ["根目录", "文档", "工作"])
    @Expect(model.entries().size, 3)
    @Expect(model.canGoUp())
    model.goUp() // 回到文档
    @Expect(model.path.value, ["文档"])
    model.navigateTo(0) // 回到根目录
    @Expect(model.isRoot())
    model.goUp() // 根目录下为无操作
    @Expect(model.isRoot())
}

@Test
func selectionFollowsExplorerConventions(): Unit {
    let model = ExplorerModel()
    // 根目录：3 个文件夹 + 1 个文件。
    @Expect(model.folderCount(), 3)
    @Expect(model.fileCount(), 1)
    model.selectFile("待办.txt")
    let selected = model.selectedFile().getOrThrow()
    @Expect(selected.name, "待办.txt")
    @Expect(selected.sizeBytes, 312)
    // 任何导航都清除选中。
    model.openFolder("文档")
    @Expect(model.selected.value, "")
    @Expect(model.selectedFile().isNone())
    // 选中项不在当前目录时同样视为未选中（防御：状态与目录内容永远一致）。
    model.selectFile("不存在.txt")
    @Expect(model.selectedFile().isNone())
}
