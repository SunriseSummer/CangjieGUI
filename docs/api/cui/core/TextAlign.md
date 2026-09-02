[cui](../../index.md) › [cui.core](index.md) › TextAlign

# TextAlign

位于 `cui.core` 包的公开枚举

文本在所分配框架内的水平对齐方式：行首、居中或行尾。[`Label`](Label.md) 的 `align` 构造参数与 `textAlign` 方法接受它；多行文本逐行套用同一对齐。

## 声明

```cangjie
public enum TextAlign
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("TextAlign", 640, 420))
    app.run {
        VStack(spacing: 12.vp) {
            Label("起点对齐", align: TextAlign.Leading).width(360.0)
            Label("居中对齐", align: TextAlign.Center).width(360.0)
            Label("末端对齐", align: TextAlign.Trailing).width(360.0)
        }.padding(24.0)
        // 运行时：三行标签分别按起点、居中和末端对齐绘制。
    }
}
```

## 成员概览

**枚举值**

| 成员 | 说明 |
|---|---|
| `Leading` | 对齐到行首（当前实现固定为左缘），`Label` 的默认值。 |
| `Center` | 在框架内水平居中。 |
| `Trailing` | 对齐到行尾（当前实现固定为右缘）。 |

## 另请参阅

- [Label](Label.md) — 消费本类型的文本组件。
