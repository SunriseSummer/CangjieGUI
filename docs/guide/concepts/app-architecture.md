[CUI 指南](../index.md) › 应用结构

# 模型、动作与界面边界

## 核心结论

模型保存事实，动作表达一次用户意图，界面读取模型并发送动作。文件、网络和后台任务位于这条数据流之外，完成后再把结果作为新动作送回。

小页面可以直接使用几个 `State` 和普通方法；当多个入口共享动作、多个字段必须一起更新，或规则需要脱离窗口测试时，再引入 `ModelStore` 和 `Reducer`。

## 从简单结构开始

一个文件也可以有清楚的边界：

- 模型保存用户输入、选择和业务记录。
- 动作方法完成校验和一次完整状态变化。
- 构建函数声明控件，只调用动作，不复制规则。
- 外部服务处理文件、网络、剪贴板和后台计算。

当代码增长时，可以按变化原因拆成 `model.cj`、`views.cj`、`desktop.cj` 和 `main.cj`。文件名不是重点，依赖方向才是重点：模型不引用控件，视图不直接读写文件，工作线程不持有 UI 状态。

## 何时使用 ModelStore

出现以下任一情况时，Store 通常比零散回调更清楚：

- 按钮、菜单和快捷键需要复用同一业务动作。
- 一次动作要原子修改多个字段。
- 动作序列需要记录、回放或独立测试。
- 子功能只应看到自己的局部模型和动作。

`ModelStore<Model, Action>` 保存一个完整模型。界面通过 `get` 或 `select` 读取，通过 `dispatch` 发送动作；只有纯更新函数或 `Reducer` 构造下一模型。

```cangjie verify role=complete
package docexample

import cui.*

class TaskState {
    let selectedId: String
    let status: String

    init(selectedId: String, status: String) {
        this.selectedId = selectedId
        this.status = status
    }
}

main(): Unit {
    let tasks = ModelStore<TaskState, String>(
        TaskState("", "请选择任务"),
        update: {model, action =>
            if (action.isEmpty()) {
                model
            } else {
                TaskState(action, "已选择 ${action}")
            }
        }
    )

    tasks.dispatch("alpha")
    println(tasks.get().status)
}
```

真实应用通常把 `String` 换成有意义的 Action 枚举或带数据的动作类型。更新函数只依赖传入的模型和动作，不读取文件、不访问时钟，也不启动任务。

## 选择和绑定

视图只关心模型的一小部分时，用 `select` 创建缓存的只读值。输入控件要修改字段时，用 Store 的 `binding` 把候选值转换成 Action。这样控件无法绕过更新规则直接替换根模型。

对字符串、枚举、小结构等便宜结果，可以给 `select` 或 `binding` 传状态等价策略，跳过结果未变的通知。昂贵筛选不应依赖深比较补救；应调整数据所有权或建立明确的缓存派生。

## 子功能边界

大型应用不应把根模型和根 Action 传给每个子视图。使用 `Lens` 描述根模型到局部模型的路径，使用 `Prism` 描述根 Action 中的局部分支，再用 `FeaturePath` 把两者组合。

组合根通过 `scope` 创建 `ScopedStore`。子视图只能读取局部模型、发送局部动作，但所有数据仍由同一个根 Store 持有。`FeaturePath.then` 可继续组合更深层的功能。

自定义 Lens 和 Prism 应使用 `cui.testing` 中的定律检查函数验证。这样可以发现“写回字段时意外改变其他字段”或“动作嵌入后无法提取”等隐蔽问题。

## 动态子功能与稳定 ID

可选编辑器、详情页等可能不存在的状态使用 `ifPresent` 组合。重复的行、卡片或文档页使用 `IdentifiedArray` 和 `forEach`，动作携带稳定业务 ID，而不是当前数组下标。

默认情况下，动作命中但局部状态不存在会报错。这通常说明取消或生命周期处理有问题。只有业务明确允许迟到结果时，才选择 `MissingFeaturePolicy.Ignore`。

大量、无顺序的实体可以存入 `EntityTable`；显示顺序另存 ID 数组。`IdentifiedArray` 适合有序 UI 项目，`EntityTable` 适合按 ID 共享同一份实体事实，不应互相替代。

如果一个领域动作要更新多个项目，使用批量 reducer 或 `dispatchAll`，在一个事务中按顺序完成。不要从外部随意合并本来独立的根动作，因为中间模型可能是业务语义的一部分。

## 外部效果

读取文件、保存文档、请求服务等操作不能放进纯 Reducer。需要同时描述模型变化和外部工作时，使用 `EffectReducer<Model, Action, Effect>` 返回 `Transition<Model, Effect>`：

- 模型立即按纯规则更新，便于测试。
- Effect 是应用定义的普通值，只描述要做什么。
- `EffectStore` 提交模型后，把有序效果批次交给应用基础设施。
- 基础设施决定线程、取消、重试和错误处理。
- 工作完成后，通过 `DesktopApp.post` 在 UI 线程发送成功或失败 Action。

CUI 不自动解释 Effect，也不替应用选择线程池或网络库。这个边界让副作用策略保持可见、可替换、可测试。

## 目录与依赖建议

中型项目可以采用以下职责：

| 文件 | 职责 |
|---|---|
| `model.cj` | 领域值、纯查询、Action 和 Reducer |
| `views.cj` | 读取模型并声明组件 |
| `desktop.cj` | 文件、对话框、剪贴板和后台适配 |
| `main.cj` | 创建 Store、服务、主题和 `DesktopApp` |

只有一个小页面时，不必创建空文件；先保持函数边界，出现独立变化原因后再拆分。

## 常见错误

- 把所有状态塞进一个巨型根模型：局部交互状态应留在最低共同所有者。
- 在 Reducer 中读取文件或启动线程：Reducer 必须是纯函数。
- 子视图继续持有根 Store：类型边界仍然泄漏，应创建 `ScopedStore`。
- 动态项目动作携带数组下标：排序或删除后会作用到另一个对象。
- 所有迟到动作都静默忽略：默认报错更容易发现生命周期缺陷。
- Effect 只打印到终端：桌面应用需要把成功、失败和可重试状态写回模型。
- 在构建函数中发起一次性请求：构建会再次执行，请求应由动作触发。

## 相关 API

- [`ModelStore`](../../api/cui/core/ModelStore.md)、[`Reducer`](../../api/cui/core/Reducer.md)、[`ScopedStore`](../../api/cui/core/ScopedStore.md)
- [`Lens`](../../api/cui/core/Lens.md)、[`Prism`](../../api/cui/core/Prism.md)、[`FeaturePath`](../../api/cui/core/FeaturePath.md)
- [`IdentifiedArray`](../../api/cui/core/IdentifiedArray.md)、[`EntityTable`](../../api/cui/core/EntityTable.md)、[`MissingFeaturePolicy`](../../api/cui/core/MissingFeaturePolicy.md)
- [`EffectStore`](../../api/cui/core/EffectStore.md)、[`EffectReducer`](../../api/cui/core/EffectReducer.md)、[`EffectBatch`](../../api/cui/core/EffectBatch.md)
- [`DesktopApp.post`](../../api/cui/desktop/DesktopApp.md#post) — 把后台结果送回 UI 线程。

## 下一步

通过[任务工作台教程](../tutorials/task-workbench.md)练习模型、筛选和主从界面；需要接入文件或后台任务时，继续阅读[桌面文件与后台工作](../how-to/desktop-files-and-background.md)。
