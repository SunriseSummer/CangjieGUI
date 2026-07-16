# tracker：问题追踪（徽标与过滤标签）

一个问题追踪界面，集中演示 `Badge` 状态徽标与 `Chip` 过滤标签：语义色徽标标注状态与优先级，成排过滤标签
切换列表显示，配合镜头绑定与派生列表。

## 演示要点

- `Badge` 圆角药丸、柔和底色 + 同色文字，纯展示；以语义色（中性/强调/成功/警告/危险）标注每条问题的状态与优先级
- `Chip` 可选过滤标签，绑定 `Bindable<Bool>`：点击（或聚焦后 Space/Enter）切换选中，选中填充强调色、未选中描边
- 顶部一排状态 `Chip` 决定各状态是否显示；过滤开关是唯一数据源，可见列表由它与问题列表纯函数派生
- 每个状态的过滤开关是开关数组在该下标上的镜头（`State.project`），各 `Chip` 双向读写、互不干扰

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Issue` 类型、状态/优先级名、状态位更新与按状态过滤（纯函数） |
| [model.cj](src/model.cj) | `TrackerModel`：问题列表 + 过滤开关；逐状态镜头与可见列表派生 |
| [views.cj](src/views.cj) | 标题、过滤 Chip 行、问题列表（状态/优先级 Badge）、状态→徽标色映射 |
| [theme.cj](src/theme.cj) | 浅色主题（语义色由 Badge 自带） |

## 关键实现

### 过滤开关逐状态镜头绑定 Chip

四个状态开关放在一个 `State<Array<Bool>>`，每个过滤 `Chip` 绑定它在该状态下标上的双向镜头（`project`），
点选自动落到对应位置，各 Chip 解耦：

```cangjie
func filterLens(status: Int64): Binding<Bool> {
    statusFilters.project(get: {arr => arr[status]}, set: {arr, v => withUpdatedBool(arr, status, v)})
}
```

### 可见列表是开关与问题的纯函数

可见问题由过滤开关与问题列表现算，视图每帧读取，无缓存、无失效：

```cangjie
func filterIssues(issues: Array<Issue>, filters: Array<Bool>): Array<Issue> {
    // 仅保留状态开关为真的问题
}
```

状态与优先级各映射到一个 `BadgeKind` 语义色，由 `Badge` 以柔和底色 + 同色文字呈现。

## 运行

```powershell
cd examples/tracker
cjpm run
```

点顶部状态标签切换该状态是否显示，列表随之过滤。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot tracker.bmp"
```
