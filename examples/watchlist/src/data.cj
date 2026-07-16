/*
 * 观影清单示例的类型化数据与纯统计（评分更新、已评计数、平均分）。
 *
 * 评分数组与电影列表按下标一一对应；更新/统计都是纯函数，便于单测且与视图无关。
 */
package cui_watchlist

import std.collection.ArrayList

// 一部电影的类型化数据。
struct Movie {
    let title: String
    let genre: String

    init(title: String, genre: String) {
        this.title = title
        this.genre = genre
    }
}

func seedMovies(): Array<Movie> {
    [
        Movie("盗梦空间", "科幻 · 悬疑"),
        Movie("千与千寻", "动画 · 奇幻"),
        Movie("肖申克的救赎", "剧情"),
        Movie("星际穿越", "科幻 · 冒险"),
        Movie("这个杀手不太冷", "剧情 · 动作"),
        Movie("辛德勒的名单", "历史 · 剧情"),
        Movie("阿甘正传", "剧情 · 爱情"),
        Movie("楚门的世界", "剧情 · 科幻"),
        Movie("疯狂动物城", "动画 · 喜剧"),
        Movie("寻梦环游记", "动画 · 音乐")
    ]
}

// 初始评分（0 表示未评），与 seedMovies 按下标对应。
func seedRatings(): Array<Int64> {
    [5, 5, 4, 0, 4, 0, 5, 0, 4, 0]
}

// 返回把下标 index 处评分替换为 value 的新数组。
func withRating(ratings: Array<Int64>, index: Int64, value: Int64): Array<Int64> {
    let out = ArrayList<Int64>()
    for (i in 0..ratings.size) {
        if (i == index) {
            out.add(value)
        } else {
            out.add(ratings[i])
        }
    }
    out.toArray()
}

// 已评（非零）条数。
func countRated(ratings: Array<Int64>): Int64 {
    var n = 0
    for (r in ratings) {
        if (r > 0) {
            n += 1
        }
    }
    n
}

// 已评项平均分的十分之一制（如 45 表示 4.5）；未评任何项时为 0。
func averageTenths(ratings: Array<Int64>): Int64 {
    var sum = 0
    var n = 0
    for (r in ratings) {
        if (r > 0) {
            sum += r
            n += 1
        }
    }
    if (n == 0) {
        0
    } else {
        (sum * 10) / n
    }
}

func formatTenths(tenths: Int64): String {
    "${tenths / 10}.${tenths % 10}"
}
