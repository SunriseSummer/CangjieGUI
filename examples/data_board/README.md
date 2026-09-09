# data_board：数据看板

一个三列产品看板，演示 CUI 状态体系的核心主张：单一数据源与派生展示。列头计数、
超限警示、筛选结果全部由卡片数据派生，界面上的数字不会与数据脱节。

## 演示要点

- 把样例数据收拢为唯一事实源（`data.cj`），展示层零硬编码数字
- `derive` 多来源派生：计数文本依赖“卡片 + 筛选”，超限标志依赖“卡片 + 筛选 + 上限”
- `ForEach` 按业务 id 维持卡片身份，插入新卡不扰动其余卡片
- 筛选器、新增按钮真正接线的交互闭环
- 紧凑与舒适两档密度，以及泛型 `pick` 辅助函数
- 列内 `ScrollView`：窗口调矮时卡片在列内滚动而非溢出面板，“添加”按钮固定在列底；
  混排头部行用 `crossAxisAlignment(Center)` 让定高控件保持自然高度

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Task` 数据类、筛选谓词、三列种子数据 |
| [model.cj](src/model.cj) | `BoardModel`：三列状态、派生计数、超限标志、追加卡片 |
| [views.cj](src/views.cj) | 头部工具条、列、卡片、标签胶囊 |
| [theme.cj](src/theme.cj) | 蓝色主题、列/卡片表面、警示色 |

## 关键实现

### 计数永远等于卡片数

列头文本不是手写字符串，而是从数据派生。卡片增删、筛选切换、上限调整，数字都随
下一帧自动正确：

```cangjie
this.plannedCount = derive(this.planned, filter, {tasks, f => "${filterTasks(tasks, f).size} 项"})
this.doingCount = derive(this.doing, filter, this.wipLimit,
    {tasks, f, limit => "${filterTasks(tasks, f).size} / ${limit}"})
this.wipExceeded = derive(this.doing, filter, this.wipLimit,
    {tasks, f, limit => filterTasks(tasks, f).size > limit})
```

“进行中”数量超过在制上限时，`doingAccent` 切换为警示红；把上限步进器调低或向“进行中”列添加卡片即可触发。

### ForEach 与卡片身份

卡片列表按任务 id 建立 `Keyed` 子树。新增卡片只是在数组尾部多一个身份，
其余卡片的局部状态与交互身份保持不动：

```cangjie
ForEach(visible, key: {task => "task.${task.id}"}) {
    task => taskCard(task, model.compact.value)
}
```

### 状态更新以整列替换触发通知

`State<Array<Task>>` 的通知发生在赋值时，因此追加卡片构造新数组整体写回：

```cangjie
column.value = appended   // 整列替换 → revision 递增 → 派生计数失效重算
```

### 密度二选一

三处“紧凑/舒适”分支收拢为一个泛型辅助函数，配合单位字面量使用：

```cangjie
.spacing(pick(compact, 5.vp, 8.vp))
.contentPadding(pick(compact, 10.vp, 14.vp))
```

## 运行

```powershell
cd examples/data_board
cjpm run
```

支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot data_board.bmp"
```

## 练习与验收

追加卡片后切换筛选，确认计数与可见卡片一致。

[返回示例学习路线](../README.md) · [运行准备](../README.md#运行准备) · [API 参考](../../docs/api/index.md)
