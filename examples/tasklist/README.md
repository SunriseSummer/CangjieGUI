# tasklist：任务优先级（拖动重排）

一份顺序即优先级的任务清单，集中演示 `ReorderableList` 拖放重排：按住每行左侧手柄上下拖动即改变任务顺序，
松手提交。行内容的复选框仍可正常勾选，与拖动互不干扰。

## 演示要点

- `ReorderableList` 每行左侧是拖动手柄（两列握点），按住手柄上下拖动即改变顺序；拖动时其它行让开、被拖行悬浮
- 松手回调 `onMove(from, to)`：列表只报告移动，数据仍由模型持有，模型据此重排任务表、下一帧显示新序
- 行内容是复选框（显示任务标题、切换完成态）：点手柄拖动、点手柄以外命中复选框，二者互不干扰
- 完成态用 `tasks.project` 双向绑定到任务的 done 字段；行以 `key: {t => t.id}` 迁移，故重排后完成态仍跟随该任务
- 顺序即优先级（越靠上越优先）；顶部“已完成 N”计数由任务表 `map` 派生

## 文件结构

| 文件 | 职责 |
|---|---|
| [main.cj](src/main.cj) | 入口 |
| [data.cj](src/data.cj) | `Task`、种子、通用 `moveItem` 重排、按 id 取/改完成态、完成计数 |
| [model.cj](src/model.cj) | `TaskModel`：有序任务表、`move`、每任务完成态绑定、派生摘要 |
| [views.cj](src/views.cj) | 抬头、`ReorderableList` 任务行（复选框） |
| [theme.cj](src/theme.cj) | 浅底 + 靛蓝强调主题 |

## 关键实现

### 列表报告移动，数据由模型持有

`ReorderableList` 不拥有数据，只在松手时报告一次移动，模型对自己的 `State<Array<Task>>` 施加重排：

```cangjie
ReorderableList.of(model.tasks.value, 48.0, {from, to => model.move(from, to)}, key: {t => "task${t.id}"}) {
    task => taskRow(model, task)
}
// model.move(from, to) { tasks.value = moveItem(tasks.value, from, to) }
```

### 手柄拖动与内容点击互不干扰

每行左侧固定宽度是拖动手柄，按住手柄才发起拖动；手柄以外的按压落到行内容，于是行里的复选框照常点选。
完成态用 `project` 双向绑定、以 `id` 为行键，重排后完成态跟随任务而非槽位。

## 运行

```powershell
cd examples/tasklist
cjpm run
```

按住每行左侧握点上下拖动改变优先级顺序；点任务标题勾选/取消完成。支持视觉回归快照：

```powershell
cjpm run --run-args "--snapshot tasklist.bmp"
```
