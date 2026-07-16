package cui_catalog

@Test
func catalogHasFullCatalog(): Unit {
    @Expect(buildCatalog().size, 140)
}

@Test
func catalogFilterByCategory(): Unit {
    let all = buildCatalog()
    @Expect(catalogFiltered(all, 0).size, 140) // 全部
    @Expect(catalogFiltered(all, 1).size, 28) // 电子
    @Expect(catalogFiltered(all, 5).size, 28) // 运动
    // 过滤结果只含该分类的商品。
    for (p in catalogFiltered(all, 2)) {
        @Expect(p.category, 1)
    }
}

@Test
func catalogPageCountRoundsUp(): Unit {
    @Expect(catalogPageCount(140, 8), 18) // 17*8=136，第 18 页放 4 件
    @Expect(catalogPageCount(28, 8), 4) // 3*8=24，第 4 页放 4 件
    @Expect(catalogPageCount(8, 8), 1)
    @Expect(catalogPageCount(0, 8), 1) // 空目录仍保留一页
}

@Test
func catalogPageSliceWindows(): Unit {
    let all = buildCatalog()
    let first = catalogPageSlice(all, 0, 8)
    @Expect(first.size, 8)
    @Expect(first[0].name, all[0].name)
    // 末页只剩 4 件（140 - 17*8 = 4）。
    @Expect(catalogPageSlice(all, 17, 8).size, 4)
    // 越界页得空切片。
    @Expect(catalogPageSlice(all, 99, 8).size, 0)
}

@Test
func catalogClampsPageIntoRange(): Unit {
    @Expect(catalogClampPage(-3, 18), 0)
    @Expect(catalogClampPage(99, 18), 17)
    @Expect(catalogClampPage(5, 18), 5)
}

@Test
func catalogRangeLabels(): Unit {
    @Expect(catalogRangeStart(140, 0, 8), 1)
    @Expect(catalogRangeEnd(140, 0, 8), 8)
    @Expect(catalogRangeStart(140, 2, 8), 17)
    @Expect(catalogRangeEnd(140, 17, 8), 140) // 末页封顶到总数
    @Expect(catalogRangeStart(0, 0, 8), 0) // 无结果
}

@Test
func catalogSelectingCategoryResetsPage(): Unit {
    let model = CatalogModel()
    model.page.value = 5
    model.category.value = 2 // 切换分类
    @Expect(model.page.value, 0) // observe 把游标重置回第一页
}

@Test
func catalogNoOpCategoryWriteKeepsPage(): Unit {
    let model = CatalogModel()
    model.page.value = 5
    // State 对等值赋值同样通知（重复点击当前分段就是这种写入）；守卫保证页码不被平白重置。
    model.category.value = model.category.value
    @Expect(model.page.value, 5)
}
