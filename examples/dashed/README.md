# dashed：虚线边框（dashedBorder）

一个虚线边框演练场，集中演示 `dashedBorder` 样式修饰符：沿圆角矩形周边等距行进画虚线，转角处仍均匀。
一张预览框随 Stepper 实时调整实线段长/间隔长/圆角，另有拖放区、占位卡等常见用法。

## 演示要点

- `dashedBorder(color, width:, radius:, dash:, gap:)`：沿圆角周边连续行进画虚线，转角处均匀；缺省 `dashedBorder(color)` 为 dash 6/gap 4
- 预览框随 Stepper 调 dash/gap/radius 实时更新
- 常见用法：拖放区（大号虚线框 + 提示文案）、一排占位卡（虚线 + “+”）
- 虚线是既有实线 `border` 的独立可选变体，走逐段绘制路径，不影响实线描边

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 参数描述（纯函数） |
| [model.cj](src/model.cj) | `DashedModel`：实线/间隔/圆角；描述派生 |
| [views.cj](src/views.cj) | 标题、可调预览、控件、常见用法（拖放区/占位卡） |
| [theme.cj](src/theme.cj) | 浅色主题 + 虚线色 |

## 关键实现

### 沿周边行进的虚线

渲染层构建圆角矩形的周边折线，再按 dash/gap 图案沿其连续行进：走完一段实线画一个圆头线段，走完间隔跳过，
余量跨边继承，故转角处虚线仍均匀。既有实线描边（缓存网格）原样不动。

```cangjie
VStack { /* 预览内容 */ }
    .fillWidth().height(130.vp)
    .dashedBorder(DASH_ACCENT, width: 1.5, radius: radius, dash: dash, gap: gap)
```

## 运行

```powershell
cd examples/dashed
cjpm run
```

用 Stepper 调实线段/间隔/圆角，观察预览框虚线变化。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot dashed.bmp"
```

## 练习与验收

改变实线长度、间隔和圆角，检查边角处的衔接。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
