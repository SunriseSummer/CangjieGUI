# highlight：搜索高亮（RichSpan.highlight）

一个知识卡片阅读器，集中演示 `RichSpan` 的 `<mark>` 式逐段背景高亮：在搜索框输入或点预设标签，命中的
关键词在卡片正文里就地以琥珀色高亮标记——不过滤列表、不跳转，只把匹配处点亮，这正是 `<mark>` 的经典用法。

## 演示要点

- `RichSpan.highlight(background)`：给某段套一个圆角高亮底盒，绘制在文字之下、恰覆盖该段（不加横向留白）；需要连成一体的整段标记写成单个段（相邻两个各自高亮的段在接缝处各圆各的角）
- 高亮是纯视觉层：不改变布局几何，也不改动该段的文字颜色（示例另给命中段配深色文字以保证对比）
- `TextField` 实时输入 + `.autofocus()`：键入即重算高亮；预设标签与搜索框写同一个 `State<String>`，点标签即填入
- 纯匹配逻辑与视图分离：`highlightSpans` 把一段文本按查询词切成常规/高亮片段，`matchCount`/`totalMatches` 统计命中数
- 大小写与中文：切分在 rune 上进行，中文按字整齐切分，拉丁按 ASCII 大小写不敏感匹配（中文无大小写）

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 语料 `Entry`、预设词，以及纯函数 `highlightSpans`/`matchCount`/`totalMatches` |
| [model.cj](src/model.cj) | `SearchModel`：当前 `query`、按 query 产出高亮片段、命中统计文案 |
| [views.cj](src/views.cj) | 标题、搜索框、预设标签行、卡片列表（标题/正文各一条 RichText）、状态条 |
| [theme.cj](src/theme.cj) | 浅色主题 + `<mark>` 琥珀底色与其上的深色文字 |

## 关键实现

### 按命中切分为高亮片段

高亮的关键是把一段文本切成「常规段 / 命中段」交替的 RichSpan 序列，命中段套 `.highlight(...)`：

```cangjie
// 命中处：深色文字 + 琥珀高亮底盒；其余：常规文字。空查询或零命中返回单个常规片段，正文原样呈现。
spans.add(RichSpan.text(runeSlice(hay, plainStart, i)))                       // 命中前的常规段
spans.add(RichSpan.text(matched, color: matchColor).highlight(mark))          // 命中段
```

切分与统计都在 `text.toRuneArray()` 上进行（不重叠、从左到右），故中文按字切分、拉丁大小写不敏感。

### 高亮不改布局

`highlight` 只在绘制时于片段盒后填一个圆角矩形，不参与度量/换行，因此加不加高亮布局几何完全一致（框架
`rich_text_test` 里有一条断言：同一组文本，带高亮与不带高亮的 layout 宽高与各片段 x 逐一相等）。

### 标题用 Stretch 占满卡片宽

卡片内标题与正文都是 RichText，VStack 用 `CrossAxisAlignment.Stretch` 让二者占满卡片宽——短标题因此稳定单行
（一个 `Start` 收缩到自身宽度的短 RichText 可能因亚像素宽度差把末字换行），长正文则在整宽处换行。

## 运行

```powershell
cd examples/highlight
cjpm run
```

搜索框已预填“高亮”，可直接改写或点预设标签（界面 / 动画 / 圆角 / RichText），命中处即时高亮。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot highlight.bmp"
```

## 练习与验收

加入中文、ASCII 大小写和组合字符，说明匹配采用码点而非语言分词。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
