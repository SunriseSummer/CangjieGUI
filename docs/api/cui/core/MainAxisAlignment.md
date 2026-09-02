[cui](../../index.md) › [cui.core](index.md) › MainAxisAlignment

# MainAxisAlignment

位于 `cui.core` 包的公开枚举

栈沿主轴分配剩余空间的策略：靠端、居中或三种等分间隔。[`VStack`](VStack.md) 与 [`HStack`](HStack.md) 的 `mainAxisAlignment` 方法接受它，默认 `Start`。

## 声明

```cangjie
public enum MainAxisAlignment
```

## 说明

三种间隔策略分出的空隙叠加在栈已配置的 `spacing` 之上。剩余空间按零下限计算：内容超出可用空间时没有可分配的空隙，六种取值的排列结果与 `Start` 相同。弹性子组件（[`Flexible`](Flexible.md) 或 `.flex()`）会先吃掉全部剩余空间，此时主轴对齐没有可分配的余量。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("MainAxisAlignment", 420, 300))
    app.run {
        VStack(spacing: 0.vp) {
            Label("顶部").height(32.0)
            Label("底部").height(32.0)
        }.mainAxisAlignment(MainAxisAlignment.SpaceBetween).padding(24.0)
        // 运行时：首项贴顶、末项贴底，剩余高度由 SpaceBetween 放在两者之间。
    }
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `Start` | 从主轴起点连续排列，剩余空间全部留在末尾（默认值）。 |
| `Center` | 剩余空间平分到首尾两侧，子组件整体居中。 |
| `End` | 剩余空间全部置于起点侧，子组件贴向主轴末端。 |
| `SpaceBetween` | 首末子组件贴住两端，剩余空间均分到相邻子组件之间；只有一个子组件时与 `Start` 相同。 |
| `SpaceAround` | 剩余空间按子组件数均分，每个子组件两侧各得半份——首尾留半份空隙、相邻之间为一整份。 |
| `SpaceEvenly` | 首端、相邻之间与末端共 `count + 1` 个空隙均分剩余空间。 |

## 另请参阅

- [VStack](VStack.md) / [HStack](HStack.md) — 通过 `mainAxisAlignment` 消费本类型的栈容器。
- [CrossAxisAlignment](CrossAxisAlignment.md) — 交叉轴方向的对应策略。
