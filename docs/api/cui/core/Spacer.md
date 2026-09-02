[cui](../../index.md) › [cui.core](index.md) › Spacer

# Spacer

位于 `cui.core` 包的公开类

测量为零并吸收所在栈剩余空间的空白弹性组件，把兄弟组件推向两端。在 [`HStack`](HStack.md) 尾部放一个 Spacer 即可把行尾控件推到最右，是右对齐行尾或分隔工具栏的惯用手段。

## 声明

```cangjie
public class Spacer <: Widget
```

## 继承

Spacer <: [`Widget`](Widget.md)

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Spacer", 640, 420))
    app.run {
        let gap = Spacer()
        let _ = HStack {
            Label("报表.xlsx")
            Spacer()
            Button("导出", {=> ()})
        }
        // 运行时：Spacer 吸收工具栏剩余宽度，把“导出”按钮推到最右。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init()`](#init) | 创建一个空白弹性组件。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(...)`](#measure) | 返回零尺寸：Spacer 没有固有大小，实际尺寸完全来自栈的弹性分配。 |
| [`layout(...)`](#layout) | 空操作：Spacer 不记录几何。 |
| [`draw(...)`](#draw) | 空操作：Spacer 不绘制任何内容。 |
| [`handle(...)`](#handle) | 恒返回 `false`：Spacer 不消费任何事件。 |
| [`isFlexible()`](#isflexible) | 恒返回 `true`：参与所在栈的剩余空间分配，权重为默认的 1.0。 |

## 构造函数

### init

创建一个空白弹性组件。构造时自动注册进包围它的界面构建函数。

```cangjie
public init()
```

## 方法

### measure

返回零尺寸：Spacer 没有固有大小，实际尺寸完全来自栈的弹性分配。

```cangjie
public func measure(_: UiContext, _: Size): Size
```

**返回值** `Size` — 恒为 `Size.zero()`。

### layout

空操作：Spacer 不记录几何。

```cangjie
public func layout(_: UiContext, _: Rect): Unit
```

### draw

空操作：Spacer 不绘制任何内容。

```cangjie
public func draw(_: UiContext): Unit
```

### handle

恒返回 `false`：Spacer 不消费任何事件。

```cangjie
public func handle(_: UiContext, _: UiEvent): Bool
```

**返回值** `Bool` — 恒为 `false`。

### isFlexible

恒返回 `true`：参与所在栈的剩余空间分配，权重为默认的 1.0。同一栈里放两个 Spacer 可把中间内容居中。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 恒为 `true`。

## 另请参阅

- [Flexible](Flexible.md) — 把任意组件包装成弹性组件并指定权重。
- [HStack](HStack.md) / [VStack](VStack.md) — 分配剩余空间的水平/垂直栈。
