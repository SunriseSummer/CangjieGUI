# styleguide：设计令牌样式指南

一份“活的样式指南”，集中展示 CUI 的设计令牌尺度：间距 `Spacing`、圆角 `Radii`、动效 `Motion`（时长 + 缓动），
以及既有的字号尺度 `FontSizes` 与高度预设 `Shadow.elevation`。页面自身也用这些令牌排版（间距、圆角、高度），
既是参考也是范例。

## 演示要点

- `Spacing`（4px 栅格：xs..xxl）：每档以一根宽度随其数值增长的示意条呈现，直观对比间距量级
- `Radii`（sm..pill）：一排色块展示各圆角，`pill` 全圆（渲染层把半径钳到短边一半）
- `Shadow.elevation`（e1..e4）：一排卡片展示高度预设的阴影渐大渐柔
- `FontSizes`（Caption..Display）：逐档字号样张；`Motion`（fast/normal/slow）：时长示意条 + 缓动角色
- 页面用 `Spacing` 作间距/内边距、`Radii` 作圆角、`Shadow.elevation` 作卡片——令牌的自我示范

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 各尺度的可迭代数据、毫秒文案与示意条宽度（纯函数） |
| [views.cj](src/views.cj) | 逐节展示间距/圆角/高度/字号/动效 |
| [theme.cj](src/theme.cj) | 浅色主题 + 示意色块令牌 |

## 关键实现

### 令牌即数据，逐档展示

各尺度列成可迭代数据，视图逐档渲染其视觉表现：

```cangjie
for (step in SPACING_STEPS) {
    // 名称 + 宽度=该间距值的示意条 + 数值
    VStack {}.width(step.length).height(14.0).background(ACCENT, Radii.sm)
}
```

### 页面自我示范

本页的间距、内边距用 `Spacing.*`，卡片圆角用 `Radii.*`，高度参考用 `Shadow.elevation`——令牌既被展示也被使用。

## 运行

```powershell
cd examples/styleguide
cjpm run
```

滚动浏览各令牌尺度。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot styleguide.bmp"
```

## 练习与验收

调整一个间距令牌的使用点，检查示意与实际布局一致。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
