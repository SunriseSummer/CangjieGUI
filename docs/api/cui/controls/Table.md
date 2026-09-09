[cui](../../index.md) › [cui.controls](index.md) › Table

# Table

位于 `cui.controls` 包的公开类

多列、可排序的数据表格：固定表头、窗口化滚动的正文与单行选择。行是按列索引的 `Array<Array<String>>` 单元格（类型化数据用 [`Table.of`](#of)），点击表头按该列排序、再点反向；只绘制可见行，长表依然轻量。

## 声明

```cangjie
public class Table <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 说明

排序发生在显示层：选择存的是**原始行索引**，重新排序后高亮仍跟随同一行，应用直接改写 `selected` 也会把该行滚入视区。排序是稳定归并排序，数值列（[`TableColumn`](TableColumn.md) 的 `numeric`）按数值键比较，"100" 排在 "88" 之后。排序状态（列与方向）由控件标识内部保留，不对外暴露；计算出的显示顺序跨帧缓存，排序输入不变时每帧只做 O(n) 校验而非重排，被编辑过的单元格会让缓存失效并触发一次重排。

表格是单个焦点项：聚焦后 ↑/↓/Home/End 移动选择并把选中行滚入视区。行区沿用普通箭头指针（电子表格惯例），不会切换成手形指针。表头高为 `max(32, 有效文字行高 + 8)`，行高为 `max(28, 有效文字行高 + 8)` 逻辑像素。

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Table", 640, 420))
    app.run {
        let columns = [TableColumn("主机", 140.0), TableColumn("负载", 90.0, numeric: true)]
        let rows = [["web-01", "63"], ["web-02", "8"], ["db-01", "87"]]
        let selected = rememberState<Int64>("selected") {0}
        let grid = Table(columns, rows, selected)
        // 运行时：窗口显示可排序数据表；点击行选择，方向键移动当前行。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 由列定义、字符串矩阵行与选择绑定构造表格。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static of<T>(...)`](#of) | 数据驱动的构建形式：由类型化数组与 `DataColumn` 列生成表格。 |
| [`measure(_: UiContext, available: Size)`](#measure) | 占满可用空间（宽高均取 `available`）。 |
| [`layout(_: UiContext, rect: Rect)`](#layout) | 记录分配到的框架。 |
| [`isFlexible()`](#isflexible) | 恒返回 `true`——表格在栈中分得剩余空间。 |
| [`draw(ctx: UiContext)`](#draw) | 画底面、固定表头（含排序箭头）、窗口化的可见行与滚动条；选择变化时把选中行滚入视区。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击表头切换排序、点击行选中、滚轮与滚动条拖动滚动；聚焦时 ↑/↓/Home/End 移动选择。 |
| [`focusableId()`](#focusableid) | 返回本控件的焦点 id。 |

## 构造函数

### init

由列定义、字符串矩阵行与选择绑定构造表格。

```cangjie
public init(columns: Array<TableColumn>, rows: Array<Array<String>>, selected: Bindable<Int64>,
    key!: ?String = None)
```

**参数**

- `columns`: `Array<TableColumn>` — 列定义，见 [`TableColumn`](TableColumn.md)。
- `rows`: `Array<Array<String>>` — 行数据，内层数组按列索引取单元格；缺列按空串处理。
- `selected`: `Bindable<Int64>` — 双向绑定的选中行（**原始行索引**）；外部赋值会把该行滚入视区。
- `key!`: `?String` — 显式控件标识，让排序与滚动状态跨结构变化保持；空串抛 `IllegalArgumentException`。默认 `None`，按构建顺序自动派生。

## 方法

### of

数据驱动的构建形式：由类型化数组与 `DataColumn` 列生成表格。每列的 `value` 抽取器在可见帧运行以生成单元格字符串；选择仍是 `data` 的原始行索引。对持续重绘的超大数据集，建议改用基础构造函数加提升到外部的字符串矩阵。

```cangjie
public static func of<T>(
    data: Array<T>,
    columns: Array<DataColumn<T>>,
    selected: Bindable<Int64>,
    key!: ?String = None
): Table
```

**参数**

- `data`: `Array<T>` — 类型化的行数据。
- `columns`: `Array<DataColumn<T>>` — 类型化列定义，见 [`DataColumn`](DataColumn.md)。
- `selected`: `Bindable<Int64>` — 双向绑定的选中行（`data` 的原始索引）。
- `key!`: `?String` — 显式控件标识；空串抛 `IllegalArgumentException`。默认 `None`。

**返回值** `Table` — 生成的表格组件。

### measure

占满可用空间（宽高均取 `available`）。列宽固定，超出框架的部分被裁剪（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

记录分配到的框架。表头占据顶部，正文从表头下方开始滚动；表头和行高使用测量阶段计算的字体尺寸。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `rect`: `Rect` — 父级最终分配给组件的矩形。

### isFlexible

恒返回 `true`——表格在栈中分得剩余空间。

```cangjie
public func isFlexible(): Bool
```

**返回值** `Bool` — 固定为 `true`，组件可参与父布局的弹性空间分配。

### draw

画底面、固定表头（含排序箭头）、窗口化的可见行与滚动条；选择变化时把选中行滚入视区。只有滚入视口的行才被绘制，奇偶行画斑马纹，选中行画强调色软底。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击表头切换排序、点击行选中、滚轮与滚动条拖动滚动；聚焦时 ↑/↓/Home/End 移动选择。同一表头再次点击反向排序；内容装得下时滚轮不消费，留给外层滚动容器。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableId

返回本控件的焦点 id。构造时已注册为焦点项（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func focusableId(): ?String
```

**返回值** `?String` — 该控件用于参与键盘焦点导航的标识。

## 另请参阅

- [TableColumn](TableColumn.md) — 字符串矩阵形式的列定义。
- [DataColumn](DataColumn.md) — `Table.of` 的类型化列定义。
- [ListView](ListView.md) — 单列的字符串选择列表。
