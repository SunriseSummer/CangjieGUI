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
    model.openFolder("文档")
    model.openFolder("工作")
    @Expect(model.path.value, ["文档", "工作"])
    @Expect(model.segments(), ["根目录", "文档", "工作"])
    @Expect(model.entries().size, 3)
    model.navigateTo(1) // 回到文档
    @Expect(model.path.value, ["文档"])
    model.navigateTo(0) // 回到根目录
    @Expect(model.isRoot())
}
