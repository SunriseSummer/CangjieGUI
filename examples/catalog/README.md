# catalog：商品目录（分页导航）

一个商品目录浏览界面，集中演示 `Pagination` 分页导航：140 件商品每页 8 件分为 18 页，配合分类过滤，
展示分页与过滤共存时的正确处理。过滤、分页切片与显示区间都是当前状态的纯函数。

## 演示要点

- `Pagination` 页导航夹在上一页/下一页箭头之间：始终显示首页、末页与当前页附近的页码，中间空缺折叠为省略号
- 上一页/下一页箭头步进一页，并在首页/末页自动禁用；`current`（0 起）双向绑定，页码显示为 1 起
- 顶部 `SegmentedControl` 分类过滤条改变结果集与总页数——切换分类时用 `State.observe` 把页码重置回第一页
- 过滤结果、总页数、当前页切片、显示区间都是当前状态的纯函数，每帧现算，无需缓存
- 商品卡片用嵌套 `Panel` + `Grid(2)` 排布，每张附一块分类色块缩略图，价格与评分各占一行

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Product` 类型、确定性目录生成、分类名与过滤项、评分文案 |
| [model.cj](src/model.cj) | `CatalogModel`：分类/页码状态；过滤、分页、区间的纯函数派生 |
| [views.cj](src/views.cj) | 标题、分类过滤条、商品网格、分页底栏 |
| [theme.cj](src/theme.cj) | 浅色主题与各分类色签色 |

## 关键实现

### 切换分类回到第一页

分类过滤会改变总页数，若停留在旧页码可能越界。用 `State.observe` 在分类变化时把页码归零：

```cangjie
this.categoryObservation = this.category.observe({_, _ => cursor.value = 0})
```

`SegmentedControl` 直接绑定 `model.category` 改分类，观察器负责重置页码，二者解耦。

### 分页是当前状态的纯函数

过滤结果、总页数与当前页切片都由状态现算，视图每帧读取，无缓存、无失效：

```cangjie
let items = model.filtered()                       // 按分类过滤
let pageCount = catalogPageCount(items.size, PAGE_SIZE) // 向上取整
let page = catalogClampPage(model.page.value, pageCount) // 夹到有效范围
let pageItems = catalogPageSlice(items, page, PAGE_SIZE)  // 当前页切片
```

底栏把 `pageCount` 与 `model.page` 交给 `Pagination`，它只显示有效页码并双向读写页码状态。

## 运行

```powershell
cd examples/catalog
cjpm run
```

点底部页码或箭头翻页；切换顶部分类过滤条会回到第一页。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot catalog.bmp"
```
