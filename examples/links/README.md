# links：可点击链接（RichSpan.onTap）

一个活动通知流，集中演示 `RichSpan` 的可点击链接：每条通知里的人名、文件、频道等以链接色 + 下划线呈现，
`RichSpan.onTap` 让它们可点击——鼠标悬停变手型光标、点击运行回调，也可 `Tab` 逐个聚焦、`Enter`/空格激活，
这里把被点/激活的链接显示到底部详情条。

## 演示要点

- `RichSpan.onTap(action)`：把某段变为可点击链接，按下并在同一段释放即运行回调；链接样式由既有构建器设置（链接色 + 下划线）
- 悬停手型光标：指针移到链接片段上时显示 `Interactive` 光标
- 键盘可达：每个链接段是一个焦点停靠点，`Tab` 依声明序在链接间移动，`Enter`/空格激活，聚焦时绘制焦点环
- 一条通知是一行 RichText，链接与连接词、图标混排；点任一链接把其文本设为“已选择”，显示在详情条
- 无链接段的 RichText 保持惰性、不拦截事件（对既有富文本零影响）
- 循环内为每个链接绑定独立闭包（`let label = segment.text`），避免闭包共享捕获

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Segment`/`Notice` 数据、链接计数（纯函数） |
| [model.cj](src/model.cj) | `LinksModel`：已选择链接；选择与详情文案 |
| [views.cj](src/views.cj) | 标题、通知卡列表（片段拼 RichText，链接段 onTap）、详情条 |
| [theme.cj](src/theme.cj) | 浅色主题 + 链接色 |

## 关键实现

### 链接段 = 样式 + onTap

链接的“可点击”与“样式”分离：`onTap` 赋予交互，颜色/下划线用既有构建器：

```cangjie
let label = segment.text // 每次迭代绑定独立文本，供闭包捕获
RichSpan.text(label, color: LINK_COLOR).underline().onTap({=> model.select(label)})
```

### 惰性回退

`RichText` 的 `handle` 只在指针命中带 `onTap` 的片段时消费事件；没有链接段时找不到命中片段，返回 false，
与旧的惰性富文本行为一致。

## 运行

```powershell
cd examples/links
cjpm run
```

把鼠标移到彩色链接上（变手型）点击，或用 `Tab` 聚焦链接后按 `Enter`/空格激活，底部详情条随之显示被点击或激活的链接。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot links.bmp"
```

## 练习与验收

用鼠标和 Tab／Enter 激活同一链接，确认反馈一致。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
