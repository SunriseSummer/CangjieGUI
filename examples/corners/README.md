# corners：逐角圆角（Corners）

一个消息会话，集中演示 `Corners`——背景的四个角各自取半径（CSS 四值 `border-radius` 的对应物）。气泡整体圆润，
唯独发送者一侧的下角收成小尾角：我的在右下、对方的在左下，视线自然落回发送者。底部输入条只圆上面两角，
像自屏幕底部升起的抽屉。圆角与尾角可用 Stepper 实时调整，即刻改形。

## 演示要点

- `background(color, corners!: Corners)`：背景四角各自取半径；`Corners(topLeft:, topRight:, bottomRight:, bottomLeft:)` 全控
- `Corners.top(r)`：只圆上面两角（输入条、抽屉、页签）；另有 `all` / `bottom` / `left` / `right` 常用造型
- 不对称气泡：三角圆润 + 发送者一侧下角收窄，是聊天气泡的经典造型；两侧互为镜像
- 逐角圆角是纯装饰：不改变布局尺寸（与 `shadow`/`border` 同为装饰修饰符）
- 造型逻辑与视图分离：纯函数 `bubbleCorners(fromMe, radius, tail)` 产出四角，可单测
- 半径以 vp 计，绘制时随缩放解析为像素；每个角自动钳到短边一半

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Message` 数据、种子对话，纯函数 `bubbleCorners` |
| [model.cj](src/model.cj) | `CornersModel`：消息列表、草稿、可调圆角/尾角、发送 |
| [views.cj](src/views.cj) | 标题、圆角调节、气泡会话、底部输入条 |
| [theme.cj](src/theme.cj) | 浅色主题 + 气泡配色与输入条底色 |

## 关键实现

### 尾角朝向发送者

气泡的四角只有一处与众不同——发送者那侧的下角：

```cangjie
// 我的尾角在右下，对方的在左下；其余三角取整体圆角。
func bubbleCorners(fromMe: Bool, radius: Float32, tail: Float32): Corners {
    if (fromMe) {
        Corners(topLeft: radius, topRight: radius, bottomRight: tail, bottomLeft: radius)
    } else {
        Corners(topLeft: radius, topRight: radius, bottomRight: radius, bottomLeft: tail)
    }
}
```

视图里一行套上即可，四角随 Stepper 实时变化：

```cangjie
Label(message.text).wrap().foregroundColor(fg)
    .padding(12.vp, 9.vp)
    .background(bg, corners: model.cornersFor(message))
    .maxWidth(340.vp)
```

### 只圆上面两角的输入条

`Corners.top(16)` 是「上圆下方」的简写，用于自底部升起的输入条/抽屉：

```cangjie
HStack { TextField(model.draft).flex(); Button("发送", {=> model.send()}).role(ButtonRole.Primary) }
    .padding(14.vp, 10.vp)
    .background(BAR_BG, corners: Corners.top(16.0))
```

### 与统一圆角的关系

逐角圆角走独立的绘制路径（按调用逐次剖分），既有统一圆角的缓存网格热路径分毫未动；`Corners.all(r)` 与
`background(color, r)` 造型等价，按需选用即可。

## 运行

```powershell
cd examples/corners
cjpm run
```

调「圆角」「尾角」两个 Stepper 观察气泡改形（尾角调到与圆角相等即退化为普通圆角气泡），在底部输入条打字并
发送，新气泡带着同样的尾角出现。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot corners.bmp"
```

## 练习与验收

令尾角等于其余圆角，确认恢复普通圆角气泡。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
