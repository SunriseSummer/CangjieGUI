# timeline：横向日期时间轴

一条横向滚动的日期带，集中演示 `LazyRow` 横向虚拟列表：400 天只渲染视口附近的十几个日格，滚动成本
恒为一屏。日期运算全部复用 `CalendarDate`，选中项驱动详情。

## 演示要点

- `LazyRow` 横向虚拟化：400 个日格只物化视口附近的十几个，构建/布局/绘制都是 O(可见) 而非 O(总数)
- 鼠标滚轮横向滚动（滚轮远离身体即向右前进），内容溢出时底部出现横向滚动条（与纵向对称）
- 每个日格：上排星期（今天用强调色标记）、中间可点选的日号 `Button`（选中用 `Primary` 主色）、下排月份
- 点日号即选中，选中项驱动详情面板：完整日期、星期全称与相对今天的天数（今天/N 天后/N 天前）
- 日期全部由 `CalendarDate` 算出：`start.addingDays(i)` 取第 i 天、`weekdayIndex()` 取星期、`compareTo` 取天数差
- 横向滚动偏移由模型以 `State<Float32>` 持有，初始滚到今天使其开箱可见；“回到今天”按钮复位选中与滚动
- 今天在入口读取后传入模型，使模型逻辑可用固定日期确定性地测试

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口；读取今日并注入模型 |
| [data.cj](src/data.cj) | 星期名表与相对日期措辞（纯函数） |
| [model.cj](src/model.cj) | `TimelineModel`：日期带起点、选中位置、滚动偏移、按索引取日期、回到今天 |
| [views.cj](src/views.cj) | 抬头（含“回到今天”）、`LazyRow` 日期带、选中详情 |
| [theme.cj](src/theme.cj) | 冷调浅底 + 蓝紫强调色主题与色彩令牌 |

## 关键实现

### 横向虚拟化，日期按需算出

日期带不预生成 400 个日期，而是把它们交给 `LazyRow` 按索引惰性构建，索引再经 `CalendarDate` 即时换算：

```cangjie
LazyRow(model.count, TIMELINE_CELL_W, spacing: TIMELINE_SPACING, scroll: Some(model.scroll)) {
    index => dayCell(model, index) // dayCell 内 model.dateAt(index) = start.addingDays(index)
}
```

只有视口附近的日格会被构建，滚动上千天也只付出一屏的代价。

### 滚动偏移由模型持有

把 `LazyRow` 的横向偏移交给模型的 `State<Float32>` 而非让其内部保留，好处有二：初始化时即可滚到今天
（`todayScrollOffset()` 让今天落在左侧第三格），“回到今天”也能一并复位选中与滚动位置。

### 与 LazyColumn 对称

`LazyRow` 与 `LazyColumn` 共享同一套窗口范围计算与逐项 `Keyed` 构建逻辑（仅轴向不同），横向滚动条
（轨道、滑块、拖动、翻页）也与纵向对称。因此两个方向的虚拟列表行为一致，维护一处、两向受益。

## 运行

```powershell
cd examples/timeline
cjpm run
```

滚轮左右滚动日期带，点日号选中查看详情，点“回到今天”跳回。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot timeline.bmp"
```
