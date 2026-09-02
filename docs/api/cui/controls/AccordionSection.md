[cui](../../index.md) › [cui.controls](index.md) › AccordionSection

# AccordionSection

位于 `cui.controls` 包的公开结构体

`Accordion` 折叠面板的一个分区描述：标题文本加正文的界面构建函数。它被 [`Accordion`](Accordion.md) 消费；正文只在分区展开时构建——折叠时不构建正文，其正文内的局部状态在收起后丢弃、重新展开时复位。

## 声明

```cangjie
public struct AccordionSection
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("AccordionSection", 640, 420))
    app.run {
        let about = AccordionSection("关于") {=> Label("CUI 0.2.0，基于 SDL3。")}
        let panel = Accordion([about], initiallyExpanded: [0])
        // 运行时：窗口先展开“关于”分区，点击标题可收起并再次展开。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(title: String, body: () -> Unit)`](#init) | 由标题与正文构建器构造一个分区描述。 |

## 构造函数

### init

由标题与正文构建器构造一个分区描述。`body` 是界面构建函数（可写尾随 lambda），仅在分区展开时被调用。

```cangjie
public init(title: String, body: () -> Unit)
```

**参数**

- `title`: `String` — 标题条上显示的文本。
- `body`: `() -> Unit` — 分区正文的界面构建函数；其中声明的组件构成展开后显示的内容。

## 另请参阅

- [Accordion](Accordion.md) — 消费本类型的折叠面板。
