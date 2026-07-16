/*
 * 观影清单状态：电影列表 + 一份按下标对应的评分数组。
 *
 * 每部电影的评分是评分数组在该下标上的镜头（`project`），`Rating` 双向读写它；已评计数与平均分都是
 * 评分数组的纯函数，每帧现算。
 */
package cui_watchlist

import cui.{Binding, State}

class WatchlistModel {
    let movies: Array<Movie> = seedMovies()
    let ratings: State<Array<Int64>>

    init() {
        this.ratings = State<Array<Int64>>(seedRatings())
    }

    // 第 index 部电影评分的双向镜头，供该行的 `Rating` 绑定。
    func ratingLens(index: Int64): Binding<Int64> {
        ratings.project(get: {arr => arr[index]}, set: {arr, v => withRating(arr, index, v)})
    }

    func total(): Int64 {
        movies.size
    }

    func ratedCount(): Int64 {
        countRated(ratings.value)
    }

    // 已评项平均分文案，未评任何项时为 "—"。
    func averageText(): String {
        let tenths = averageTenths(ratings.value)
        if (tenths == 0) {
            "—"
        } else {
            formatTenths(tenths)
        }
    }
}
