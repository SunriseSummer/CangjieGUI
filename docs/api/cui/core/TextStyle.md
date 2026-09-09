[cui.core](index.md) › TextStyle

# TextStyle

控件子树继承的字体默认值。fontFamily、fontSize、fontWeight、italic、underline、strikethrough、fontVariations 分别继承；显式 fontStyle 整组覆盖，然后应用同一 TextStyle 中的独立字段。Label/RichSpan 的 bold、italic 等构建器只修改各自字段；fontStyle(FontStyle.regular) 可明确重置整组样式。

```cangjie
public struct TextStyle
public let fontFamily: ?String
public let fontSize: ?Length
public let fontStyle: ?FontStyle
public let fontVariations: ?FontVariations
public let fontWeight: ?FontWeight
public let italic: ?Bool
public let underline: ?Bool
public let strikethrough: ?Bool
public init(fontFamily!: ?String = None, fontSize!: ?Length = None, fontStyle!: ?FontStyle = None,
        fontWeight!: ?FontWeight = None, italic!: ?Bool = None, underline!: ?Bool = None, strikethrough!: ?Bool = None, fontVariations!: ?FontVariations = None)
```

Widget.textStyle 覆盖测量、布局、绘制、事件及捕获的浮层环境；UiContext.withTextStyle 用于同步作用域。字体缓存区分数值字重和规范化轴坐标。参见[字体与排版](../../../guide/how-to/fonts-and-typography.md)。
