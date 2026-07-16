/*
 * CUI 示例：观影清单评分。
 *
 * 演示 `Rating` 评分控件：一排圆点，填充到当前分、其后置空。点某点即评到该位、再点当前分清除，悬停预览，
 * 聚焦后方向键增减（Home 清零、End 满分）。逐部电影一行绑定各自的评分镜头（`State.project`），
 * 汇总的已评条数与平均分随评分实时派生。
 */
package cui_watchlist

import cui.{DesktopApp, WindowSpec}

main(): Int64 {
    let model = WatchlistModel()
    let app = DesktopApp(WindowSpec("CUI 观影清单", 560, 640, scale: 1.25), theme: watchlistTheme())
    app.setMinimumSize(460, 480)
    app.run {
        watchlistView(model)
    }
    return 0
}
