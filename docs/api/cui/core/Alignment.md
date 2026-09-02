[cui](../../index.md) › [cui.core](index.md) › Alignment

# Alignment

位于 `cui.core` 包的公开枚举

九宫格式的二维对齐，供 [`ZStack`](ZStack.md) 这类把子组件放进同一框架的容器定位不拉伸的子组件。九个取值覆盖四角、四边中点与正中。

## 声明

```cangjie
public enum Alignment
```

## 说明

对齐只作用于在相应轴上拒绝拉伸（[`acceptsStretch`](Widget.md#acceptsstretch) 返回 `false`，例如被 `width`/`height` 定死）的子组件；接受拉伸的子组件直接填满整个框架，无所谓对齐。`Leading`/`Trailing` 在当前实现中固定对应左缘/右缘。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Alignment", 420, 260))
    app.run {
        ZStack {
            Panel {Label("内容卡片").width(300.0).height(140.0)}
            Badge("右下角", kind: BadgeKind.Info)
        }.alignment(Alignment.BottomTrailing).padding(24.0)
        // 运行时：角标位于卡片右下角，Alignment.BottomTrailing 同时控制两轴。
    }
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `TopLeading` | 左上角。 |
| `Top` | 顶边中点。 |
| `TopTrailing` | 右上角。 |
| `Leading` | 左边中点（垂直居中、贴左缘）。 |
| `Center` | 正中，`ZStack` 的默认值。 |
| `Trailing` | 右边中点（垂直居中、贴右缘）。 |
| `BottomLeading` | 左下角。 |
| `Bottom` | 底边中点。 |
| `BottomTrailing` | 右下角。 |

## 另请参阅

- [ZStack](ZStack.md) — 通过 `alignment` 消费本类型的层叠容器。
