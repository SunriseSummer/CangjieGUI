[cui](../../index.md) › [cui.controls](index.md) › DataColumn

# DataColumn

位于 `cui.controls` 包的公开类

`Table.of` 的类型化列定义：表头、列宽、数值标记与从行数据 `T` 抽取单元格文本的 `value` 抽取器。源数据保持强类型，每列的表头与取值逻辑写在一起，无需手搭 `Array<Array<String>>` 字符串矩阵（见 [`Table`](Table.md)）。

## 声明

```cangjie
public class DataColumn<T>
```

## 说明

抽取出的字符串同时用于显示与排序（按该列的 `numeric` 规则），抽取器在每个可见帧运行一次以生成基础表格的单元格；对持续重绘的超大数据集，改用 [`TableColumn`](TableColumn.md) 加提升到外部的字符串矩阵更省。`cell` 画笔与 `TableColumn.cell` 契约完全相同——只绘制、不接收事件、被裁剪在单元格内——数值可以按数字排序、却画成负载条。

## 示例

```cangjie verify
package docexample

import cui.*

struct Server {
    let host: String
    let cpu: Int64

    init(host: String, cpu: Int64) {
        this.host = host
        this.cpu = cpu
    }
}

main(): Unit {
    let app = DesktopApp(WindowSpec("DataColumn", 640, 420))
    app.run {
        let servers = [Server("web-01", 23), Server("db-01", 87)]
        let selected = rememberState<Int64>("selected") {0}
        let grid = Table.of(
            servers,
            [
                DataColumn<Server>("主机", 160.0) {s => s.host},
                DataColumn<Server>("CPU %", 90.0, numeric: true) {s => "${s.cpu}"}
            ],
            selected
        )
        // 运行时：窗口显示由 DataColumn 提取字段的类型化表格，点击表头可排序。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 由标题、列宽、`value` 抽取器与可选的数值标记、单元格画笔构造类型化列。 |

## 构造函数

### init

由标题、列宽、`value` 抽取器与可选的数值标记、单元格画笔构造类型化列。`value` 习惯上写成尾随 lambda：`DataColumn<Server>("主机", 160.0) {s => s.host}`。

```cangjie
public init(
    title: String,
    width: Float32,
    numeric!: Bool = false,
    cell!: ?(UiContext, Int64, String, Rect) -> Unit = None,
    value!: (T) -> String
)
```

**参数**

- `title`: `String` — 表头显示的标题。
- `width`: `Float32` — 列宽，逻辑像素，固定不随内容伸缩。
- `numeric!`: `Bool` — 数值列标记；`true` 时右对齐、按数值排序。默认 `false`（左对齐、按 UTF-8 字节序排序）。
- `cell!`: `?(UiContext, Int64, String, Rect) -> Unit` — 自定义单元格画笔，契约同 [`TableColumn`](TableColumn.md) 的 `cell`。默认 `None`，渲染抽取出的文本。
- `value!`: `(T) -> String` — 从一行数据抽取单元格字符串；结果同时用于显示与排序。

## 另请参阅

- [Table](Table.md) — `Table.of` 消费本类型构建数据驱动的表格。
- [TableColumn](TableColumn.md) — 字符串矩阵形式的列定义。
