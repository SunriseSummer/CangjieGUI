# cards：样式卡片（阴影 · 圆角 · 边框）

一个样式属性演练场，集中演示通用样式修饰符：`shadow`（可配 offset/blur/spread/color 的软阴影，含 Material 式
`Shadow.elevation` 高度预设）、`background(color, radius)`（圆角填充）与 `border`（圆角描边）。一张预览卡片的
阴影层级、圆角与边框可用 Stepper/Switch 实时调整，下方另有 elevation 阶梯参考。

## 演示要点

- `shadow(Shadow.elevation(level), radius:)`：Material 式高度预设，层级越高阴影越大越柔；阶梯 e1..e6 一眼对比
- `background(fill, radius)` 圆角填充 + `border(color, width:, radius:)` 圆角描边，三者传同一 radius 与圆角吻合
- 绘制顺序固定正确：阴影先于内容绘制（视觉在其下）、边框在内容之上，故按 `background → shadow → border` 链式即可
- 关闭阴影/边框时传透明色（自然不绘制），从而恒链式套三个修饰符、无需条件包装
- Stepper 调层级/圆角、Switch 切边框，样式描述由 `describeStyle` 纯函数派生

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 卡片令牌（填充/边框/阴影色）、阶梯层级、样式描述（纯函数） |
| [model.cj](src/model.cj) | `CardsModel`：阴影层级/圆角/边框开关；描述派生 |
| [views.cj](src/views.cj) | 标题、居中预览卡片、控件、elevation 阶梯参考 |
| [theme.cj](src/theme.cj) | 浅灰主题（凸显白卡阴影） |

## 关键实现

### 恒链式的样式修饰符

阴影、边框绘制顺序天然正确，故预览卡片始终链式套三个修饰符；关闭项以透明色传入，自然不绘制：

```cangjie
VStack { /* 卡片内容 */ }
    .padding(32.vp)
    .background(CARD_FILL, r)                                  // 圆角填充
    .shadow(Shadow.elevation(level, color: shadowColor), radius: r) // 软阴影（关闭时 shadowColor 透明）
    .border(borderColor, width: 1.5, radius: r)               // 圆角描边（关闭时 borderColor 透明）
```

### elevation 阶梯

`Shadow.elevation(level)` 随层级增大偏移与模糊，e1..e6 并排即成 Material 式高度阶梯，直观对比。

## 运行

```powershell
cd examples/cards
cjpm run
```

用 Stepper 调阴影层级与圆角、Switch 切边框，预览卡片实时更新。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot cards.bmp"
```

## 练习与验收

分别关闭阴影和边框，确认卡片布局不变。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
