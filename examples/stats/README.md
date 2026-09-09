# stats：数据看板（RichText 逐段字号）

一个指标看板，集中演示 `RichText` 的逐段字号：每张卡的数值行把「大号粗体数值 + 小号弱化单位」拼在同一行
富文本里——两种字号在按字体基线对齐、行高随最大字号增长。下方一行是按好坏着色的环比变化，顶部分时段切换。

## 演示要点

- `RichSpan.fontSize(...)` 逐段字号：大号数值（30）+ 小号单位（14）同处一行，按字体基线对齐、行高随最大字号增长
- 逐段颜色：环比变化按「变化是否为好」着绿/红（延迟越低越好，故 −8% 显绿）
- `SegmentedControl` 切时段（今日/本周/本月），整组指标随之切换
- 指标网格是 `RetainedSubtree(cachePaint: true)`：自动追踪时段 `State`，稳定帧重放透明绘制命令，切换时只重录该网格
- 时段数据、变化文案、变化好坏都是纯函数，便于单测

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Stat` 类型、分时段数据集、变化文案与好坏（纯函数） |
| [model.cj](src/model.cj) | `StatsModel`：选中时段；当前指标集派生 |
| [views.cj](src/views.cj) | 标题、时段分段、指标卡网格（数值行为逐段字号 RichText） |
| [theme.cj](src/theme.cj) | 深色仪表盘主题 + 变化语义色 |

## 关键实现

### 大号数值 + 小号单位同处一行

数值行是一段 RichText，值与单位各设字号，逐段字号使二者按基线对齐、行高随最大字号增长：

```cangjie
RichText([
    RichSpan.text("${stat.value}").bold().fontSize(30.0), // 大号粗体数值
    RichSpan.muted(" ${stat.unit}").fontSize(14.0)        // 小号弱化单位
])
```

### 变化按好坏着色

环比变化的颜色由「变化方向是否为好」决定（`deltaIsGood`：升且升为好，或降且降为好），故延迟下降显绿而非红。

### 透明 retained paint 边界

四张指标卡的网格用 `RetainedSubtree("stats-grid", cachePaint: true)` 包裹。构建时实际读取的
`period` 会自动登记依赖；稳定帧不再遍历卡片的 draw，而是按原 z 序重放值命令。命令保留
clip 和颜色，但不截取祖先背景，因此网格空隙仍然透明；切换时段时只失效并重录这个边界。

## 运行

```powershell
cd examples/stats
cjpm run
```

切时段观察整组指标切换，留意大号数值与小号单位的行内对齐。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot stats.bmp"
```

## 练习与验收

切换统计时段，检查数值、单位、颜色和基线一致。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
