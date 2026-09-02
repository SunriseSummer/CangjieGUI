[cui](../../index.md) › [cui.core](index.md) › Axis

# Axis

位于 `cui.core` 包的公开枚举

布局方向轴：水平或垂直。[`Divider`](Divider.md) 用它选择走向，[`Widget.acceptsStretch`](Widget.md#acceptsstretch) 用它询问某个轴上能否拉伸，`cui.controls` 的拆分视图用它选择分割方向。

## 声明

```cangjie
public enum Axis
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Axis", 640, 420))
    app.run {
        let rule = Divider(axis: Axis.Vertical)
        // 运行时：窗口显示一条竖直 Divider，Axis.Vertical 把厚度放在横轴。
    }
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `Horizontal` | 水平方向——[`HStack`](HStack.md) 的主轴，也是 `Divider` 的默认走向。 |
| `Vertical` | 垂直方向——[`VStack`](VStack.md) 的主轴。 |

## 另请参阅

- [Divider](Divider.md) — 按 `Axis` 决定走向的分隔线。
- [Widget.acceptsStretch](Widget.md#acceptsstretch) — 以 `Axis` 为参数的拉伸询问。
