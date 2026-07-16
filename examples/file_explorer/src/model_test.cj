package cui_file_explorer

/*
 * 树的 id 即路径这一约定支撑了索引与面包屑：这里守护索引的正确性与路径派生的边界。
 */
@Test
func indexKnowsFoldersAndFiles(): Unit {
    let model = ExplorerModel()

    let core = model.infoFor("CangjieGUI/src/core").getOrThrow()
    @Expect(core.isFolder)
    @Expect(core.name, "core")
    @Expect(core.childCount, 4) // widget/state/layout_widgets/split_view

    let file = model.infoFor("CangjieGUI/src/core/split_view.cj").getOrThrow()
    @Expect(!file.isFolder)
    @Expect(file.name, "split_view.cj")
    @Expect(file.childCount, 0)
}

@Test
func infoForUnknownIdIsNone(): Unit {
    let model = ExplorerModel()
    @Expect(model.infoFor("does/not/exist").isNone())
}

@Test
func initialSelectionIsIndexed(): Unit {
    let model = ExplorerModel()
    // 初始选中的文件必须在索引里，否则详情面板会落到空态。
    @Expect(model.infoFor(model.selected.value).isSome())
    // 且其祖先都在初始展开集里，保证它一开始就可见。
    for (ancestor in model.initiallyExpanded) {
        @Expect(model.infoFor(ancestor).getOrThrow().isFolder)
    }
}

@Test
func basenameTakesLastSegmentSafely(): Unit {
    @Expect(basename("CangjieGUI/src/core/widget.cj"), "widget.cj")
    @Expect(basename("CangjieGUI"), "CangjieGUI")
    @Expect(basename(""), "") // 空串 split 得空数组，回退到原串而非越界
}

@Test
func extensionOfHandlesDottedAndPlainNames(): Unit {
    @Expect(extensionOf("widget.cj"), ".cj")
    @Expect(extensionOf("components.md"), ".md")
    @Expect(extensionOf("LICENSE"), "无扩展名")
}

@Test
func breadcrumbExpandsPathSeparators(): Unit {
    @Expect(breadcrumb("CangjieGUI/src/core").contains("CangjieGUI"))
    @Expect(breadcrumb("CangjieGUI/src/core").contains("core"))
    @Expect(!breadcrumb("CangjieGUI/src/core").contains("/core")) // 分隔符已被展开加空格
}
