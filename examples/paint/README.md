# paint：画板

一个自由绘画应用，演示标准控件组合、`CanvasWidget` 画布手势，以及
指针事件“消费还是放行”的边界决策，这是自绘控件最容易出错的地方。

## 演示要点

- 用标准 `Button` 组合带名称、选中状态和键盘操作的色板，避免重复实现交互协议
- `CanvasWidget` 的绘制回调与事件回调分工
- 画布手势的事件边界：`MouseUp` 为何必须区分“结束绘制”与“消费事件”
- `map` 派生的工具栏文本（“画笔 N px”“N 条笔迹”）
- `Slider` 双向驱动画笔粗细、系统十字光标的托管

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口：窗口、最小尺寸、十字光标托管 |
| [state.cj](src/state.cj) | `Stroke` 线段、`PaintModel`（起笔/采样/收笔）与派生文本 |
| [canvas.cj](src/canvas.cj) | 画布渲染与手势事件策略 |
| [color_swatch.cj](src/color_swatch.cj) | 标准按钮组成的可选中色板与语义标签 |
| [views.cj](src/views.cj) | 根布局与工具栏 |
| [theme.cj](src/theme.cj) | 调色板与主题 |

## 关键实现

### 事件边界：收笔与消费分离

事件按绘制层级自顶向下分发（后声明者先收到）。画布在工具栏之后声明，总是先拿到
`MouseUp`；若无条件消费，工具栏“清空”按钮（按下与松开两段手势）的松开半程会被吞掉，
按钮永远无法触发。正确策略是收笔不看坐标、消费必须判界：

```cangjie
case UiEvent.MouseUp(MouseButton.Left, x, y) =>
    // 收笔：笔迹拖出画布外再松开也要结束本次绘制
    let wasDrawing = model.endStroke()
    // 消费：只有属于本次绘制、或落在画布内的松开才归画布，其余放行
    if (wasDrawing || frame.contains(x, y)) {
        return true
    }
```

### 组合标准控件

`colorSwatch` 使用 28 vp 方形 `Button`，以 `SurfaceStyle` 表示颜色和选中环，
`Tooltip` 提供颜色名称，`Semantics` 提供同样的名称及选中状态。Tab 可聚焦，Enter／Space 选择；
鼠标按下后在按钮外松开不会选择。无需重新编写焦点、命中与按压协议。选中判定比较 RGBA 四个通道。

工具栏用 `FlowRow` 在窄窗口换行，颜色和尺寸为两个自然分组。笔迹保存画布局部坐标，
绘制时再加画布原点，避免工具栏换行或窗口布局变化导致笔迹错位。清空同时结束当前手势，
后续移动不会接着绘制已清除的笔迹；空画布禁用清空按钮。

### 派生的工具栏文本

画笔粗细与笔迹计数都是 `DerivedState`，滑块拖动、画布落笔后文本自动刷新：

```cangjie
let brushText: DerivedState<String>       // "画笔 5 px"
let strokeCountText: DerivedState<String> // "12 条笔迹"
```

## 运行

```powershell
cd examples/paint
cjpm run
```

支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot paint.bmp"
```

## 练习与验收

将笔迹拖出画布后松开，再点击清空，确认手势结束且按钮可用。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
