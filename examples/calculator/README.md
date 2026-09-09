# calculator：桌面计算器

一个深色主题的标准与科学计算器，演示 CUI 中等权网格键盘、枚举化输入与键盘直控的组合，
以及计算器必须具备的数值边界保护。

## 演示要点

- 用 `.flex(weight)` 权重构成严格对齐的键盘网格，以及“0”键如何精确横跨两列
- 用枚举替代字符串标签：按键行为的 `match` 穷尽，新增按键时编译器强制补全 `press` 分支
- `EventHandler` 把键盘输入翻译成与鼠标点击完全相同的动作
- 用 `State` 保存显示值和待定运算，保证按钮回调产生的结果在同一帧重建并绘制
- 除零、`Int64` 溢出、错误态恢复三类数值保护的写法

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口：创建模型与窗口，挂接键盘事件包装器 |
| [state.cj](src/state.cj) | `CalcModel` 数据模型、`CalcKey`/`CalcOp` 枚举、数值边界常量、键盘区行定义 |
| [logic.cj](src/logic.cj) | 纯状态转换：按键分发、四则运算、错误态与格式化（不含任何渲染） |
| [views.cj](src/views.cj) | 视图：显示屏、键盘行、键面角色与样式的集中映射 |
| [keyboard.cj](src/keyboard.cj) | 键盘映射：文本输入/Enter/Backspace 到 `CalcKey` |
| [theme.cj](src/theme.cj) | 深色主题与三类键面 `SurfaceStyle` |
| [interaction_test.cj](src/interaction_test.cj) | 点击后可视状态在同一帧重建的回归测试 |

## 关键实现

### 等权网格与跨列按键

每个键都是一个 `flex` 单元，等权自然形成等宽列；“0”键传 `weight: 2.0`，除获得两份空间
外还会吸收跨越的列间距，因此与上方两列严格对齐：

```cangjie
HStack {
    calcKey(model, CalcKey.Digit("0"), weight: 2.0)
    calcKey(model, CalcKey.Dot)
    calcKey(model, CalcKey.Equals)
}.spacing(10.vp)
```

### 枚举化按键：一处映射，处处穷尽

按键身份、标题、角色、样式全部围绕 `CalcKey` 展开。`press` 与 `caption` 的 `match` 为穷尽匹配，
增删按键时若遗漏分支将无法编译；`keyStyle`/`keyRole` 则用 `case _` 兜底通用样式：

```cangjie
case CalcKey.Op(_) => Some(operatorKeySurface())
case CalcKey.AllClear | CalcKey.Negate | CalcKey.Percent => Some(functionKeySurface())
```

### 键盘输入与鼠标共用同一逻辑

`EventHandler` 在视图树之前接收事件，把 `TextInput`/`Enter`/`Backspace` 翻译成 `CalcKey`
后调用同一个 `press`，因此键盘与鼠标行为始终一致：

```cangjie
app.run {
    EventHandler(onEvent: {event => handleCalculatorEvent(model, event)}) {
        calculatorView(model)
    }
}
```

### 数值边界保护

- 除零：`abs(rhs) < Limit.DIVIDE_EPSILON` 时进入 ERROR 态而非产生 Inf。
- 整数显示溢出：仅当 `abs(value) < 1.0e15` 才尝试 `Int64` 转换，超出范围保持浮点显示，
  避免 `9999999999²` 这类结果触发转换异常。
- 错误态恢复：每条输入路径先调用 `recoverFromError`，ERROR 保持到下一次交互，任何后续按键都从干净状态继续。
- 响应刷新：显示值与待定运算使用 `State`；写入会使当前事件事务失效，DesktopApp 在本帧绘制前重建一次视图，
  因此不会出现显示内容滞后一拍。

## 运行

```powershell
cd examples/calculator
cjpm run
```

支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot calc.bmp"
```

## 练习与验收

增加一个共享鼠标与键盘入口的计算操作，验证错误恢复与显示更新。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
