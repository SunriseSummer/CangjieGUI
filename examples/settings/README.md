# settings：设置面板（折叠分区）

一个应用设置屏，集中演示 `Accordion` 折叠面板：把设置分成若干可折叠分区，分区体是真实控件，只在展开时构建。

## 演示要点

- `Accordion` 把设置分成外观/通知/隐私/关于四个可折叠分区，点击标题或聚焦后 `Enter`/`Space` 展开收起
- 每个分区体是任意控件子树（`SegmentedControl`/`Slider`/`Switch`/`Checkbox`/`RadioButton`/`Button`），绑定到模型字段
- 只有展开的分区体会被构建（收起分区零成本，其局部状态在重开时重置）
- 抬头的“单开模式”开关驱动 `Accordion` 的 `single`：开启后展开一个分区会自动收起其它（手风琴模式）
- 每个分区标题是键盘焦点停靠点，`Tab` 遍历标题与展开体内的控件
- 抬头摘要由主题与数据共享范围 `derive` 得到，改动即刻反映；`initiallyExpanded: [0]` 让“外观”默认展开

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | 主题/共享范围选项文案与取值到文字的映射 |
| [model.cj](src/model.cj) | `SettingsModel`：各分区字段、单开开关、派生摘要 |
| [views.cj](src/views.cj) | 抬头、`Accordion` 分区与各分区体的控件 |
| [theme.cj](src/theme.cj) | 中性浅色 + 靛蓝强调主题 |

## 关键实现

### 分区体是任意控件子树，且惰性构建

`Accordion` 接收一组 `AccordionSection`，每个分区用尾随闭包声明其内容体：

```cangjie
Accordion([
    AccordionSection("外观") {=> appearanceBody(model) },
    AccordionSection("通知") {=> notifyBody(model) }
    // ……
], single: model.singleMode.value, initiallyExpanded: [0])
```

内容体只在分区展开时才构建，所以收起的分区不占构建成本；分区体里放什么控件都行，绑定到模型即双向联动。

### 单开由一个开关驱动

抬头的“单开模式”开关写入 `model.singleMode`，视图每帧据此把 `single` 传给 `Accordion`；开启后再展开某个
分区，其它分区会自动收起。

## 运行

```powershell
cd examples/settings
cjpm run
```

点击分区标题展开/收起，调整里面的控件；打开“单开模式”后再展开分区，观察其它分区自动收起。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot settings.bmp"
```
