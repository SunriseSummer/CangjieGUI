# watchlist：观影清单（评分控件）

一个观影清单评分界面，集中演示 `Rating` 评分控件：逐部电影可交互圆点评分，配合镜头绑定与派生汇总，
点选即时更新已评条数与平均分。

## 演示要点

- `Rating` 一排圆点填充到当前分、其后置空；点某点评到该位、再点当前分清除为 0，悬停预览填充
- 聚焦后方向键增减评分（左/下减、右/上加），Home 清零、End 满分；传 `readonly` 则为纯展示
- 每行的评分是评分数组在该下标上的镜头（`State.project`），`Rating` 双向读写它，各行互不干扰
- 汇总的已评条数与平均分都是评分数组的纯函数，每帧现算，随评分实时更新

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Movie` 类型、初始片单/评分、评分更新与统计（已评数、平均分）纯函数 |
| [model.cj](src/model.cj) | `WatchlistModel`：片单 + 评分数组；逐项评分镜头与汇总派生 |
| [views.cj](src/views.cj) | 标题、汇总、逐部电影一行（片名/类型 + 评分） |
| [theme.cj](src/theme.cj) | 浅色主题（琥珀金强调，评分点用强调色填充） |

## 关键实现

### 逐项评分是评分数组的镜头

整份评分放在一个 `State<Array<Int64>>`，每行 `Rating` 绑定它在该下标上的双向镜头（`project`），
读写自动落到对应位置，各行解耦：

```cangjie
func ratingLens(index: Int64): Binding<Int64> {
    ratings.project(get: {arr => arr[index]}, set: {arr, v => withRating(arr, index, v)})
}
```

### 汇总是评分的纯函数

已评条数与平均分都由评分数组现算，视图每帧读取，无缓存、无失效：

```cangjie
func averageTenths(ratings: Array<Int64>): Int64 {
    var sum = 0; var n = 0
    for (r in ratings) { if (r > 0) { sum += r; n += 1 } }
    if (n == 0) { 0 } else { (sum * 10) / n } // 十分之一制，如 45 = 4.5
}
```

## 运行

```powershell
cd examples/watchlist
cjpm run
```

点每行的圆点给电影评分，再点当前分可清除；顶部汇总随之更新。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot watchlist.bmp"
```
