# chat：聊天（变高虚拟列表）

一个仿主流社交软件的群聊界面，集中演示 `LazyList` 变高虚拟列表：每条气泡按预估高度定位，只渲染视口附近的
十几条，上翻几百条历史消息仍只付出一屏成本。

## 演示要点

- 贴边三段布局：顶栏（群头像 + 名称/人数）、消息区、底部输入栏，栏间以 `Divider` 分隔，符合聊天软件惯例
- 气泡左右分列：我方靠右（蓝底白字）、对方靠左（白底深字带细边）；圆形头像在气泡外侧（自定义 `Avatar`
  组件，按人取色、白色首字居中），对方名字置于气泡上方，自己的消息不显示名字
- 与上一条间隔达到 10 分钟时，该条上方插入居中的时间分隔条锚定时间线——分隔条、名字行都叠进该条的预估高度
- `LazyList` 变高虚拟化：行偏移是各高度的累加和、可见窗口由二分定位，只构建可见行；`heightOf` 只需 O(1)
- 正文用 `maxLines(lines)` 封顶：估算恒不小于实绘，故气泡绝不超高裁切；短消息短气泡、长消息高气泡
- 回车或点“发送”追加消息并把滚动置到底部（`LazyList` 会把超出的偏移钳到底），最新消息始终可见；
  回车在应用根部以 `EventHandler` 拦截，焦点在输入框或按钮上都能发送

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Message` 与高度估算、时间线/分隔条判定、群聊脚本种子、总高度 |
| [model.cj](src/model.cj) | `ChatModel`：消息列表、成员数、输入草稿、滚动偏移、发送 |
| [views.cj](src/views.cj) | 顶栏、`LazyList` 消息区（头像/名字/气泡/时间条）、输入栏、回车发送 |
| [avatar.cj](src/avatar.cj) | 自定义 `Avatar` 组件：圆形底 + 白色首字居中 |
| [theme.cj](src/theme.cj) | 浅蓝底 + 蓝色气泡主题、气泡/头像/栏底色令牌 |

## 关键实现

### 预估高度必须与实绘吻合

变高虚拟列表的关键约定：每行给出的高度要 O(1) 且与实际绘制吻合，否则会重叠或留隙。这里按字符数估算
行数，再由行数算出高度，并让正文按同一行数封顶：

```cangjie
this.lines = estimateLines(text) // 字符数 / 每行容量，钳到 [1, MAX_LINES]
// 可选段（时间分隔条、他人消息的名字行）也叠进预估，虚拟化照常工作
let textBlock = max(BUBBLE_MIN_TEXT_H, Float32(this.lines) * TEXT_LINE_H)
this.height = sepH + nameH + textBlock + BUBBLE_PAD * 2.0 + ROW_GAP
// 渲染：Label(text).maxLines(lines) —— 正文封顶到 lines 行，故实绘恒不高于预估
```

各段预算都取实绘下限（如 Label 单行最小高 28、名字行 28 + 间距 4），正文按行数封顶，二者相互保证：
估算永不小于实绘，气泡不会被行裁掉，短文本至多留一点余白。

### 发送即滚到底部

`LazyList` 会在布局时把滚动偏移钳到内容底部，因此发送后只需把偏移设为总高度这样一个足够大的值：

```cangjie
messages.value = appended.toArray()
scroll.value = totalHeight(messages.value) // 布局钳到底 → 最新消息可见
```

初始化时同样把偏移设为总高度，于是聊天打开即停在最新消息。

## 运行

```powershell
cd examples/chat
cjpm run
```

滚轮上翻查看历史消息（只渲染视口附近，几百条也很稳），在底部输入后回车或点“发送”追加消息。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot chat.bmp"
```
