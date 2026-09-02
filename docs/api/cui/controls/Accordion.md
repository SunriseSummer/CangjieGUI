[cui](../../index.md) › [cui.controls](index.md) › Accordion

# Accordion

位于 `cui.controls` 包的公开类

可折叠分区的竖向堆叠：每个分区一条可点击的标题与一个展开时才构建的正文。适合设置分组、FAQ 与属性检查器；分区由 [`AccordionSection`](AccordionSection.md) 描述，`single` 开启后展开一个分区会收起其余分区（严格手风琴）。

## 声明

```cangjie
public class Accordion <: Widget
```

## 继承

- [`Widget`](../core/Widget.md) — 组件协议（measure/layout/draw/handle 与焦点遍历）。

## 说明

展开状态有三种归属：默认由控件内部状态保留（可用 `initiallyExpanded` 设置初值）；传入 `expanded` 后由外部 [`State`](../core/State.md) 持有，应用可读写并跨结构变化保存。集合里的元素是分区下标，`single` 模式下最多含一个。

只有展开的分区体才会构建：收起时不构建正文，但其正文里的局部状态也随之丢弃，重新展开时会复位——需要跨折叠保留的状态应提升到分区体之外。每条标题都是焦点项，Tab 依声明顺序走过"标题、其展开正文内的控件、下一条标题"。

## 示例

```cangjie verify
package docexample

import std.collection.HashSet
import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("Accordion", 640, 420))
    app.run {
        let expanded = rememberState<HashSet<Int64>>("settings.expanded") {HashSet<Int64>()}
        let sections = [
            AccordionSection("外观") {=> Label("主题与字号设置。")},
            AccordionSection("通知") {=> Label("推送与免打扰设置。")}
        ]
        let settings = Accordion(sections, single: true, expanded: expanded)
        // 运行时：点击任一标题可展开或收起分区；single 模式始终只保留一个展开项。
    }
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 由分区数组构造折叠面板，可选单开模式、外部展开状态与初始展开集。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`measure(ctx: UiContext, available: Size)`](#measure) | 高度为各标题条（每条 42 逻辑像素）加所有展开正文的测量高度之和，宽度取满可用宽。 |
| [`layout(ctx: UiContext, rect: Rect)`](#layout) | 自上而下排布标题条与展开的正文。 |
| [`draw(ctx: UiContext)`](#draw) | 绘制每条标题（底色、展开箭头、焦点环）与展开的正文。 |
| [`handle(ctx: UiContext, event: UiEvent)`](#handle) | 点击标题切换其分区；聚焦标题上 Enter/Space 同效；其余事件转发给展开的正文。 |
| [`focusableIds()`](#focusableids) | 按声明顺序返回各标题的焦点 id，与展开正文内控件的焦点 id 交错排列。 |

## 构造函数

### init

由分区数组构造折叠面板，可选单开模式、外部展开状态与初始展开集。

```cangjie
public init(
    sections: Array<AccordionSection>,
    single!: Bool = false,
    expanded!: ?State<HashSet<Int64>> = None,
    initiallyExpanded!: Array<Int64> = [],
    key!: ?String = None
)
```

**参数**

- `sections`: `Array<AccordionSection>` — 分区描述，声明顺序即显示顺序。
- `single!`: `Bool` — 单开模式；`true` 时展开一个分区会收起其余分区。默认 `false`，各分区独立开合。
- `expanded!`: `?State<HashSet<Int64>>` — 外部持有的展开集（元素为分区下标）。默认 `None`，状态由视图标识内部保留。
- `initiallyExpanded!`: `Array<Int64>` — 首次构建时的展开下标种子；`single` 为 `true` 时只取第一个。仅在未传 `expanded` 时生效。默认为空（全部折叠）。
- `key!`: `?String` — 显式控件标识，用于跨结构变化保持状态；空串抛 `IllegalArgumentException`。默认 `None`，按构建顺序自动派生。

## 方法

### measure

高度为各标题条（每条 42 逻辑像素）加所有展开正文的测量高度之和，宽度取满可用宽。

```cangjie
public func measure(ctx: UiContext, available: Size): Size
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮测量使用的 UI 上下文。
- `available`: `Size` — 父级给出的可用尺寸约束。

**返回值** `Size` — 组件请求的尺寸；方法接收 `available` 时，该尺寸在父级给出的可用约束内计算。

### layout

自上而下排布标题条与展开的正文。正文高度按无界高度重新测量，随内容伸展。

```cangjie
public func layout(ctx: UiContext, rect: Rect): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮布局使用的 UI 上下文。
- `rect`: `Rect` — 父级最终分配给组件的矩形。

### draw

绘制每条标题（底色、展开箭头、焦点环）与展开的正文。展开或悬停的标题使用主题的活跃字段底色。

```cangjie
public func draw(ctx: UiContext): Unit
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮绘制使用的 UI 上下文。

### handle

点击标题切换其分区；聚焦标题上 Enter/Space 同效；其余事件转发给展开的正文。帧事件总是转发给全部展开正文（保持其中的动画运行）且不消费。

```cangjie
public func handle(ctx: UiContext, event: UiEvent): Bool
```

**参数**

- `ctx`: [`UiContext`](../core/UiContext.md) — 本轮事件处理使用的 UI 上下文。
- `event`: `UiEvent` — 本轮待处理的 UI 事件。

**返回值** `Bool` — 是否已消费该事件；`true` 表示调用方不应再继续分发。

### focusableIds

按声明顺序返回各标题的焦点 id，与展开正文内控件的焦点 id 交错排列。Tab 因此依"标题、正文控件、下一条标题"的顺序遍历（见 [`Widget`](../core/Widget.md)）。

```cangjie
public func focusableIds(): Array<String>
```

**返回值** `Array<String>` — 按声明顺序排列的标题标识及已展开正文中的焦点标识。

## 另请参阅

- [AccordionSection](AccordionSection.md) — 单个分区的描述。
- [TabView](TabView.md) — 平级内容的页签式切换。
