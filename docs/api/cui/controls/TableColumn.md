[cui](../../index.md) › [cui.controls](index.md) › TableColumn

# TableColumn

位于 `cui.controls` 包的公开类

`Table` 数据表格的一列定义：表头标题、固定像素宽度与是否数值列。它被 [`Table`](Table.md) 消费；数值列右对齐并按数值（而非字典序）排序，可选的 `cell` 画笔用自定义绘制取代文本渲染。

## 声明

```cangjie
public class TableColumn
```

## 说明

`cell` 画笔接管该列每个单元格的像素：进度条、色块、徽标都由它画。回调收到原始行索引、单元格字符串值与单元格矩形；表格已先画好行底与选中高亮，并把画笔裁剪在单元格内。排序仍按字符串值走该列的 `numeric` 规则，显示与排序键因此解耦——"87%" 可以画成负载条、仍按 87 排序。画笔只负责绘制，不接收事件；行点击照常选中。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("TableColumn", 640, 420))
    app.run {
        let columns = [
            TableColumn("姓名", 130.0),
            TableColumn("部门", 160.0),
            TableColumn("本周工时", 100.0, numeric: true)
        ]
        let rows = [["张伟", "研发部", "38"], ["李娜", "市场部", "41"]]
        let selected = rememberState<Int64>("selected") {0}
        let sheet = Table(columns, rows, selected)
        // 运行时：窗口显示三列数据表，数值列右对齐并按数值规则排序。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 由标题、列宽与可选的数值标记、单元格画笔构造列定义。 |

## 构造函数

### init

由标题、列宽与可选的数值标记、单元格画笔构造列定义。

```cangjie
public init(
    title: String,
    width: Float32,
    numeric!: Bool = false,
    cell!: ?(UiContext, Int64, String, Rect) -> Unit = None
)
```

**参数**

- `title`: `String` — 表头显示的标题。
- `width`: `Float32` — 列宽，逻辑像素，固定不随内容伸缩。
- `numeric!`: `Bool` — 数值列标记；`true` 时单元格右对齐、点击表头按数值排序。默认 `false`（左对齐、按 UTF-8 字节序排序）。
- `cell!`: `?(UiContext, Int64, String, Rect) -> Unit` — 自定义单元格画笔，参数依次为绘制上下文、原始行索引、单元格字符串值、单元格矩形；只绘制、不接收事件。默认 `None`，按列对齐规则渲染文本。

## 另请参阅

- [Table](Table.md) — 消费本类型的数据表格。
- [DataColumn](DataColumn.md) — `Table.of` 用的类型化列定义。
