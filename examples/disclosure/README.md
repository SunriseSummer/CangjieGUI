# disclosure：折叠问答（Reveal 动画 + 自定义折叠行）

一份 FAQ，集中演示两件事：`Reveal` 动画折叠容器，以及一个示例内定义的自绘可交互控件 `FaqRow`。
点问题行（或 Tab 聚焦后按 Enter/空格）展开收起答案——答案由 `Reveal` 包裹，切换时用 `Animator`
缓动自身高度，内容裁剪着从顶部滑入滑出，其下卡片随之平滑让位。标题栏提供全部展开/收起与计数摘要。

## 演示要点

- `Reveal(shown:) {=> 答案 }` 声明式过渡容器：切换 `shown` 即缓动展开/收起，是「条件显示」的动画对应物
- 自定义控件 `FaqRow`：`focusableControlIdentity` 进 Tab 焦点序、`claimHoverIfInside` 认领悬停光标、
  `ctx.isHovered`/`ctx.showFocusRing` 画悬停底与焦点环、`ctx.hasFocus` 响应 Enter/空格——应用层控件与
  内置控件走同一套协议
- chevron 随展开态右指/下指（`strokeLine` 自绘，不依赖字体字形）；答案左缩进与问题文本对齐
- 展开集合 `State<HashSet<Int64>>`，切换以复制+增删+整体重赋触发重建；全部展开/收起与计数为纯查询

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `FaqItem` 数据 |
| [model.cj](src/model.cj) | `DisclosureModel`：展开集合、逐条/全部切换、计数查询 |
| [row.cj](src/row.cj) | `FaqRow` 自绘折叠行（悬停/焦点/键盘激活） |
| [views.cj](src/views.cj) | 标题栏、问答卡片列表（`FaqRow` + `Reveal` 包裹的答案） |
| [theme.cj](src/theme.cj) | 浅色主题 |

## 关键实现

### 自定义可交互控件

`FaqRow` 实现 `Widget` 四方法，构造期取焦点身份，事件与绘制各接一半交互协议：

```cangjie
init(...) {
    this.id = focusableControlIdentity("FaqRow:${index}")
    emit(this)
}
// handle：claimHoverIfInside(...)；点击/Enter/空格时 onToggle()
// draw：isHovered 亮底、showFocusRing 画环、strokeLine 画 chevron
```

### 用 Reveal 包裹答案

```cangjie
FaqRow(index, item.question, open, {=> model.toggle(index)})
Reveal(shown: open, key: "faq-${index}") {
    VStack {
        Label(item.answer).muted().wrap()
    }.padding(40.vp, 0.vp, 16.vp, 12.vp)
}
```

`Reveal` 内部以 `localState` 持有 `Animator`，所属声明重新构建也不丢动画进度；创建即处于目标态时
不产生动画（静态快照稳定）。

## 运行

```powershell
cd examples/disclosure
cjpm run
```

点问题行或 Tab + Enter 展开收起，观察高度缓动与其下卡片的平滑让位。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot disclosure.bmp"
```

## 练习与验收

用鼠标和键盘展开同一项，检查高度动画与焦点反馈。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
