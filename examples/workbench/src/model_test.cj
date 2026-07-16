package cui_workbench

/*
 * 大纲与统计是工作台的“活文档”核心：它们从正文实时派生，最容易出错的是标题前缀剥离与空正文边界。
 */
@Test
func outlineExtractsHeadingsWithLevels(): Unit {
    let headings = outlineOf("# 顶层\n正文一行\n## 次级\n### 三级\n普通行")

    @Expect(headings.size, 3)
    @Expect(headings[0].level, 1)
    @Expect(headings[0].text, "顶层")
    @Expect(headings[1].level, 2)
    @Expect(headings[1].text, "次级")
    @Expect(headings[2].level, 3)
    @Expect(headings[2].text, "三级")
}

@Test
func headingParsingHandlesEdgesWithoutCrashing(): Unit {
    // 空串 split 得空数组，不应越界；纯 '#' 无正文不算标题；前后空白被裁剪。
    @Expect(outlineOf("").size, 0)
    @Expect(outlineOf("###").size, 0)
    @Expect(outlineOf("   ##   带空白的标题  ")[0].text, "带空白的标题")
}

@Test
func docTitleFallsBackFromHeadingToFirstLineToPlaceholder(): Unit {
    @Expect(docTitle("# 路线图\n内容"), "路线图")
    @Expect(docTitle("没有标题的首行\n第二行"), "没有标题的首行")
    @Expect(docTitle(""), "无标题")
    @Expect(docTitle("\n\n"), "无标题")
}

@Test
func statsCountsLinesSectionsAndChars(): Unit {
    let text = statsText("# 标题\n一二三四五")
    // 2 行、1 小节；字符数计原始正文、不含换行："# 标题" 4 个 + 正文 5 个 = 9。
    @Expect(text.contains("2 行"))
    @Expect(text.contains("1 小节"))
    @Expect(text.contains("9 字"))
}

@Test
func charCountExcludesNewlines(): Unit {
    @Expect(charCount("abc"), 3)
    @Expect(charCount("a\nb\r\nc"), 3)
    @Expect(charCount("中文三字"), 4)
}

/*
 * 主从绑定必须始终读写“当前选中”的那篇文档，新增后选中索引落在新文档且大纲/标题即时跟随。
 */
@Test
func projectBindingReadsAndWritesSelectedDoc(): Unit {
    let model = WorkbenchModel()

    @Expect(model.body.value.contains("产品路线图"))
    @Expect(model.currentTitle(), "产品路线图")

    model.selected.value = 1
    @Expect(model.body.value.contains("会议纪要"))
    @Expect(model.outline.value[0].text, "会议纪要")

    model.body.value = "# 改写\n新内容"
    @Expect(model.docs.value[1].body.contains("改写"))
    @Expect(model.titles()[1], "改写") // 侧栏标题实时跟随首个小节标题
}

@Test
func addDocSelectsNewEmptyDocument(): Unit {
    let model = WorkbenchModel()
    let before = model.docs.value.size

    model.addDoc()
    @Expect(model.docs.value.size, before + 1)
    @Expect(model.selected.value, before) // 新建文档成为选中项
    @Expect(model.outline.value[0].text, "新文档")
}

@Test
func splitRatiosStartWithinBounds(): Unit {
    let model = WorkbenchModel()
    @Expect(model.sidebarRatio.value > 0.0 && model.sidebarRatio.value < 1.0)
    @Expect(model.editorRatio.value > 0.0 && model.editorRatio.value < 1.0)
}
