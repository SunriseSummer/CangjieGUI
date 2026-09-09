# gradients：线性渐变（gradientBackground）

一个渐变展示台，集中演示 `gradientBackground(Gradient)` 样式修饰符：两色线性渐变填充圆角背景，可纵向
（顶→底）或横向（左→右）。一张大预览随选中的预设与方向实时更新，下方是全部预设的渐变样本墙。

## 演示要点

- `gradientBackground(Gradient, radius)`：两色线性渐变圆角填充；`Gradient(start, end, vertical)` 选方向，`reversed()` 反转
- 渐变复用与实填相同的缓存网格、逐顶点着色，不额外增加三角剖分，故与实填同等廉价；实际成本仍取决于图形数量与后端
- 大预览随 Stepper（换预设）与 Switch（换方向）实时更新；样本墙固定展示 6 组现代渐变预设
- 预设解析、渐变合成、方向标签都是纯函数，便于单测

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `GradientPreset` 预设、渐变合成、下标钳位、方向标签（纯函数） |
| [model.cj](src/model.cj) | `GradientsModel`：选中预设、方向；当前预设与渐变派生 |
| [views.cj](src/views.cj) | 标题、大预览、控件、全部预设样本墙 |
| [theme.cj](src/theme.cj) | 深色主题（凸显明亮渐变） |

## 关键实现

### 渐变填充圆角背景

预览与样本墙都用 `gradientBackground` 填充圆角背景，纵/横向由 `Gradient.vertical` 决定：

```cangjie
VStack { /* 名称、方向标签 */ }
    .fillWidth().height(160.vp)
    .gradientBackground(model.gradient(), 16.0) // 选中预设 + 方向的两色线性渐变
```

### 复用实填缓存网格

渐变在渲染层复用实填相同的缓存网格（同一形状键，不重复三角剖分），仅逐顶点按沿轴位置在两色标间插值着色；
既有实填路径原样不动。

## 运行

```powershell
cd examples/gradients
cjpm run
```

用 Stepper 换预设、Switch 换方向，观察大预览渐变实时变化。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot gradients.bmp"
```

## 练习与验收

反转颜色或方向，确认布局尺寸保持。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
