/*
 * 观影清单视图层：标题 + 汇总（已评 N/M · 平均分）+ 逐部电影一行（片名 / 类型 + 可交互评分）。
 *
 * 每行的 `Rating` 绑定该片评分的镜头；点圆点评分、再点当前分清除，汇总随之实时更新。
 */
package cui_watchlist

import cui.{CrossAxisAlignment, FontSizes, HStack, Label, LengthUnits, Panel, Rating, ScrollView, Spacer, VStack}

func watchlistView(model: WatchlistModel): Unit {
    VStack {
        header(model)
        Panel {
            ScrollView {
                VStack {
                    for (i in 0..model.movies.size) {
                        movieRow(model, i)
                    }
                }.spacing(8.vp)
            }.flex()
        }.contentPadding(12.vp).flex()
    }.spacing(14.vp).padding(18.vp)
}

func header(model: WatchlistModel): Unit {
    VStack {
        Label("观影清单").fontSize(FontSizes.TITLE)
        HStack {
            Label("点圆点评分，再点当前分可清除").muted().fontSize(FontSizes.CAPTION)
            Spacer()
            Label("已评 ${model.ratedCount()}/${model.total()} · 平均 ${model.averageText()}").fontSize(FontSizes.CAPTION)
        }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.spacing(6.vp).hug()
}

private func movieRow(model: WatchlistModel, index: Int64): Unit {
    let movie = model.movies[index]
    Panel {
        HStack {
            VStack {
                Label(movie.title).fontSize(FontSizes.CONTROL)
                Label(movie.genre).muted().fontSize(FontSizes.CAPTION)
            }.spacing(2.vp).hug().flex()
            Rating(model.ratingLens(index), key: "rating-${index}")
        }.spacing(12.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()
    }.contentPadding(12.vp)
}
