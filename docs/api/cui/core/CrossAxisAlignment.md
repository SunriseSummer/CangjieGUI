[cui](../../index.md) › [cui.core](index.md) › CrossAxisAlignment

# CrossAxisAlignment

位于 `cui.core` 包的公开枚举

栈在交叉轴上放置子组件的策略：靠端、居中或拉伸填满。[`VStack`](VStack.md) 与 [`HStack`](HStack.md) 的 `crossAxisAlignment` 方法接受它，默认 `Stretch`。

## 声明

```cangjie
public enum CrossAxisAlignment
```

## 说明

交叉轴指与排列方向垂直的轴：`VStack` 的水平方向、`HStack` 的垂直方向。子组件的交叉轴尺寸始终不超过栈的可用尺寸；`Stretch` 只拉伸 [`acceptsStretch`](Widget.md#acceptsstretch) 在该轴返回 `true` 的子组件，被 `width`/`maxWidth`（或 `height`/`maxHeight`）修饰而在该轴定死的子组件按测量尺寸贴起点放置。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("CrossAxisAlignment", 420, 260))
    app.run {
        VStack(spacing: 12.vp) {
            Label("短标签").width(96.0).background(Color.rgb(224, 236, 255))
            Label("右侧对齐").width(128.0).background(Color.rgb(224, 236, 255))
        }.crossAxisAlignment(CrossAxisAlignment.End).padding(24.0)
        // 运行时：窄标签贴到列的右缘，体现 CrossAxisAlignment.End。
    }
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `Start` | 贴交叉轴起点：`VStack` 的左缘、`HStack` 的上缘。 |
| `Center` | 在交叉轴上居中。 |
| `End` | 贴交叉轴末端：`VStack` 的右缘、`HStack` 的下缘。 |
| `Stretch` | 把接受拉伸的子组件拉满交叉轴（默认值）；拒绝拉伸的子组件按测量尺寸贴起点放置。 |

## 另请参阅

- [VStack](VStack.md) / [HStack](HStack.md) — 通过 `crossAxisAlignment` 消费本类型的栈容器。
- [MainAxisAlignment](MainAxisAlignment.md) — 主轴方向的对应策略。
- [Widget.acceptsStretch](Widget.md#acceptsstretch) — `Stretch` 是否生效的判定协议。
