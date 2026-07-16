package cui_watchlist

@Test
func updatingRatingReplacesOne(): Unit {
    let base = [0, 3, 5]
    let next = withRating(base, 1, 4)
    @Expect(next[0], 0)
    @Expect(next[1], 4)
    @Expect(next[2], 5)
    @Expect(base[1], 3) // 原数组不受影响
}

@Test
func countRatedCountsNonZero(): Unit {
    @Expect(countRated([0, 0, 0]), 0)
    @Expect(countRated([5, 0, 4, 0, 3]), 3)
}

@Test
func averageOfRatedOnly(): Unit {
    @Expect(averageTenths([0, 0, 0]), 0) // 无已评分项
    @Expect(averageTenths([4, 5, 0]), 45) // (4+5)/2 = 4.5
    @Expect(averageTenths([5, 5, 5]), 50)
    @Expect(formatTenths(45), "4.5")
    @Expect(formatTenths(50), "5.0")
}

@Test
func modelLensReadsAndWrites(): Unit {
    let model = WatchlistModel()
    let lens = model.ratingLens(3) // 初始值为 0
    @Expect(lens.get(), 0)
    lens.value = 4
    @Expect(model.ratings.value[3], 4)
    // 其余条目保持不变。
    @Expect(model.ratings.value[0], 5)
}

@Test
func modelSummaryDerives(): Unit {
    let model = WatchlistModel()
    // 初始数据 [5,5,4,0,4,0,5,0,4,0]，已评分 6 项，总和 27，平均 4.5。
    @Expect(model.total(), 10)
    @Expect(model.ratedCount(), 6)
    @Expect(model.averageText(), "4.5")
}
