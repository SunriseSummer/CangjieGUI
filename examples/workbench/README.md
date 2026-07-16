# workbench：分栏工作台

一个 IDE 式的三区写作工作台，集中演示 `SplitView` 分栏容器：可拖动的分隔条在窗格间自由分配空间，
并可嵌套构成“导航｜编辑｜信息”多区布局。正文按 Markdown 书写，大纲与字数由正文实时派生。

## 演示要点

- 外层横向 `SplitView`：左侧文档导航 | 右侧工作区，拖动竖直分隔条左右分配宽度
- 右侧再嵌纵向 `SplitView`：上方编辑器 / 下方大纲与统计，拖动水平分隔条上下分配高度
- 分隔条是位于两窗格之间的键盘焦点停靠点：`Tab` 聚焦后，横向分栏用 `←/→`、纵向分栏用 `↑/↓` 微调；
  悬停或拖动时显示对应的横向/纵向调整光标
- 两窗格各设最小尺寸，拖到边界即止；窗口过小容纳不下两个最小值时自动退化为按比例分配，窗格不塌缩
- 分栏比例由模型以 `State<Float32>` 持有并交给 `SplitView`，因此拖出的布局在切换文档时延续
- 编辑器用 `docs.project` 双向绑定到选中文档正文，id 含文档 id 实现按文档独立的光标与撤销
- 大纲（以 `#` 开头的小节标题）与统计（行数、小节数、字数、阅读时长）由 `derive` 从正文派生，编辑即刻更新
- `ListView` / `TextArea` / `ScrollView` 在分栏窗格中自然填充可用空间

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Doc`/`Heading` 与种子数据、正文取值与整表替换、Markdown 大纲与统计的纯函数 |
| [model.cj](src/model.cj) | `WorkbenchModel`：`project` 绑定、派生大纲/统计、两条分栏比例、新建文档、每文档编辑器 id |
| [views.cj](src/views.cj) | 抬头栏与嵌套分栏布局、侧栏列表、编辑器、大纲与统计信息面板 |
| [theme.cj](src/theme.cj) | 冷调石板灰主题与字号令牌 |

## 关键实现

### 嵌套分栏构成三区布局

外层横向分栏把导航与工作区分开，工作区本身又是一个纵向分栏，从而以两个 `SplitView` 组合出
“导航｜编辑｜信息”三区，每条边界独立可调：

```cangjie
SplitView(axis: Axis.Horizontal, ratio: model.sidebarRatio, minFirst: 170.0, minSecond: 360.0,
    first: {=> sidebar(model) }) {=>
    SplitView(axis: Axis.Vertical, ratio: model.editorRatio, minFirst: 160.0, minSecond: 120.0,
        first: {=> editorPane(model) }) {=> infoPane(model) }
}
```

每个窗格是独立的构建块，块内可声明任意多个组件（自动纵向堆叠），无需再包一层容器。

### 分栏比例由模型持有

把两条分栏比例交给模型的 `State<Float32>` 而非让 `SplitView` 内部保留，拖动分隔条即写回模型；
好处是这份布局意图成为可观察状态，可跨文档切换延续，也便于将来持久化或做联动动画。

### 大纲与统计随编辑派生

大纲取正文中以 `#` 开头的小节标题（逐字节剥离 `#` 前缀，对其后的中文正文安全），统计计算行数、
小节数与字符数；二者都用 `derive` 从正文与选中项派生，因此编辑正文时右下信息面板实时刷新。

## 运行

```powershell
cd examples/workbench
cjpm run
```

在左侧点击或方向键切换文档，右上编辑正文（`Ctrl+Z` 撤销），观察右下大纲与统计随输入更新；
拖动两条分隔条重分配三区，或 `Tab` 聚焦分隔条后用方向键微调。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot workbench.bmp"
```
