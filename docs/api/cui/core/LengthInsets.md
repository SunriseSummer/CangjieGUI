[cui](../../index.md) › [cui.core](index.md) › LengthInsets

# LengthInsets

位于 `cui.core` 包的公开结构体

四边各自携带单位的间距，供 padding 类 API 使用，布局时解析为逻辑像素的 `Insets`。[`Widget.padding`](Widget.md#padding) 与 [`VStack`](VStack.md)/[`HStack`](HStack.md) 的 `padding` 构造参数都以它存储边距；解析由 [`UiContext.resolve`](UiContext.md#resolve) 完成，每边限制在非负。

## 声明

```cangjie
public struct LengthInsets
```

## 示例

```cangjie verify
package docexample

import cui.*

main(): Unit {
    let ctx = UiContext(Renderer.headless(), Theme.light())
    let cardPadding = LengthInsets(8.vp, 12.vp) // 水平 8、垂直 12
    let resolved = ctx.resolve(cardPadding)
    println("水平合计 ${Int64(resolved.horizontal())}，垂直合计 ${Int64(resolved.vertical())} 逻辑像素")
    // 输出: 水平合计 16，垂直合计 24 逻辑像素
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init(...)`](#init) | 四边同值；双参数重载分设水平/垂直；命名参数重载逐边指定。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`static zero()`](#zero) | 返回四边均为零的间距。 |
| [`static of(edges: Insets)`](#of) | 包装已解析的逻辑像素间距，每边视为虚拟像素。 |

**字段**

| 成员 | 说明 |
|---|---|
| [`top`](#top) | 上边间距。 |
| [`right`](#right) | 右边间距。 |
| [`bottom`](#bottom) | 下边间距。 |
| [`left`](#left) | 左边间距。 |

## 构造函数

### init

四边同值；双参数重载分设水平/垂直；命名参数重载逐边指定。

```cangjie
public init(all: Length)
```

```cangjie
public init(horizontal: Length, vertical: Length)
```

```cangjie
public init(top!: Length, right!: Length, bottom!: Length, left!: Length)
```

**参数**

- `all`: [`Length`](Length.md) — 同时应用到四边的间距。
- `horizontal`、`vertical`: `Length` — 左右两边与上下两边的间距。
- `top!`、`right!`、`bottom!`、`left!`: `Length` — 各边间距，命名参数、无默认值。

## 方法

### zero

返回四边均为零的间距。栈容器的 `padding` 参数以它为默认值。

```cangjie
public static func zero(): LengthInsets
```

**返回值** `LengthInsets` — 四边均为 [`Length.zero()`](Length.md#zero)。

### of

包装已解析的逻辑像素间距，每边视为虚拟像素。用于把 `Insets` 形式的现成边距送回带单位的 API。

```cangjie
public static func of(edges: Insets): LengthInsets
```

**参数**

- `edges`: `Insets` — 逻辑像素下的四边间距。

**返回值** `LengthInsets` — 每边为 `Length(边值, LengthUnit.Vp)`。

## 字段

### top

上边间距。

```cangjie
public let top: Length
```

### right

右边间距。

```cangjie
public let right: Length
```

### bottom

下边间距。

```cangjie
public let bottom: Length
```

### left

左边间距。

```cangjie
public let left: Length
```

## 另请参阅

- [Widget.padding](Widget.md#padding) — 以本类型存储边距的修饰器。
- [Length](Length.md) — 单边间距的类型。
- [UiContext.resolve](UiContext.md#resolve) — 解析为逻辑像素 `Insets`。
