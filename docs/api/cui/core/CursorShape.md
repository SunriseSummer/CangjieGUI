[cui](../../index.md) › [cui.core](index.md) › CursorShape

# CursorShape

位于 `cui.core` 包的公开枚举

控件在指针悬停期间申请的语义指针形状，由宿主映射为各平台的原生光标。控件代码只声明"这里是什么"（可点击、可编辑、可缩放），不感知平台光标集。

## 声明

```cangjie
public enum CursorShape <: Equatable<CursorShape>
```

## 说明

形状随悬停申请传播：控件在指针落入自己的区域时调用 [`UiContext`](UiContext.md) 的 [`claimHover`](UiContext.md#claimhover)（或工具函数 [`claimHoverIfInside`](functions.md#claimhoverifinside)）附带期望形状；每次指针移动只有第一个申请生效，派发自视觉最上层开始，因此重叠层最终解析为最上层控件的形状。无人申请时宿主回落到 `Default`。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())

    // 指针进入文本编辑区后，申请显示文本输入光标
    ctx.claimHover("editor.body", CursorShape.Text)

    let shape = CursorShape.Text
    let isText = shape == CursorShape.Text
    let notInteractive = shape != CursorShape.Interactive
    println("是文本形状: ${isText}，不是交互形状: ${notInteractive}")
    // 输出: 是文本形状: true，不是交互形状: true
}
```

## 成员概览

**运算符**

| 成员 | 说明 |
|---|---|
| [`operator==(other: CursorShape)`](#operator) | 返回两个形状是否为同一枚举值。 |
| [`operator!=(other: CursorShape)`](#operator-1) | 返回两个形状是否不同，即 `==` 的取反。 |

**枚举值**

| 成员 | 说明 |
|---|---|
| `Default` | 静止形状：宿主显示窗口的基础光标。 |
| `Interactive` | 可点击的交互项（按钮、开关、滑块）——手形光标。 |
| `Text` | 可编辑的文本区域——I 形梁光标。 |
| `ResizeH` | 水平缩放拖拽件（列间的分栏分隔条）——左右箭头光标。 |
| `ResizeV` | 垂直缩放拖拽件（行间的分栏分隔条）——上下箭头光标。 |

## 运算符

### operator==

返回两个形状是否为同一枚举值。

```cangjie
public operator func ==(other: CursorShape): Bool
```

**参数**

- `other`: `CursorShape` — 参与比较的另一个形状。

**返回值** `Bool` — 两个形状为同一枚举值时为 `true`。

### operator!=

返回两个形状是否不同，即 `==` 的取反。

```cangjie
public operator func !=(other: CursorShape): Bool
```

**参数**

- `other`: `CursorShape` — 参与比较的另一个形状。

**返回值** `Bool` — 两个形状不同时为 `true`。

## 另请参阅

- [UiContext](UiContext.md) — `claimHover` 接受形状申请，事件派发结束后由宿主应用。
- [函数 claimHoverIfInside](functions.md#claimhoverifinside) — 指针落入框架时申请悬停与形状的控件辅助函数。
