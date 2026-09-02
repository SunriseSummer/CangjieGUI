[CUI 指南](../index.md) › 状态与绑定

# 状态、绑定与派生值

## 核心结论

状态保存事实，绑定把事实的一部分交给控件读写，派生值只负责计算，不保存第二份事实。

先回答三个问题：

1. 这个值的所有者是谁？
2. 哪些代码可以修改它？
3. 它能否完全由其他值计算出来？

这三个答案决定应该使用 `State`、`Binding`、`DerivedState`，还是普通局部值。

## 四种常用角色

| 角色 | 适用场景 | 是否可写 | 是否跨构建保留 |
|---|---|---:|---:|
| `State<T>` | 用户输入、选择、业务数据等事实 | 是 | 由其所有者决定 |
| `rememberState<T>` | 展开状态、局部输入、临时选择 | 是 | 是，跟随声明身份 |
| `Binding<T>` | 控件编辑整体模型中的一个字段 | 是 | 不单独存值 |
| `DerivedState<T>` | 总价、筛选结果、按钮是否可用 | 否 | 缓存计算结果 |

`Observable<T>` 是只读、可观察接口；`Bindable<T>` 在它之上增加写入能力。展示型组件只需要 `Observable`，输入控件接收 `Bindable`，因此同一个控件既能连接独立 `State`，也能连接模型字段的 `Binding`。

## 单一事实来源

不要同时在模型和控件旁保存两份姓名、选中项或校验结果。两份值需要手工同步，过滤、删除、取消编辑或错误恢复时很容易分叉。

例如，姓名和订阅状态是事实，“可以提交”是计算结果：

```cangjie verify role=complete
package docexample

import cui.*

class Profile {
    let name: String
    let subscribed: Bool

    init(name: String, subscribed: Bool) {
        this.name = name
        this.subscribed = subscribed
    }
}

main(): Unit {
    let profile = State<Profile>(Profile("", false))
    let name = profile.project(
        get: {value => value.name},
        set: {value, next => Profile(next, value.subscribed)}
    )
    let subscribed = profile.project(
        get: {value => value.subscribed},
        set: {value, next => Profile(value.name, next)}
    )
    let canSubmit = derive(name, subscribed) {
        text, accepted => !text.trimAscii().isEmpty() && accepted
    }

    name.value = "林"
    subscribed.value = true
    println(canSubmit.get())
}
```

`name` 和 `subscribed` 都把写入送回同一个 `profile`；`canSubmit` 每次从最新事实计算。程序没有额外维护“表单是否有效”的状态。

## `State` 的更新规则

直接给 `value` 赋值会推进修订号并通知依赖。默认策略把每次赋值都视为变化，包括相等值；如果相等写入很常见，可以创建 `State<String>("", policy: structuralEqualityPolicy<String>())`。

自定义 `stateMutationPolicy` 只应表达“两个值对观察者来说是否相同”。比较必须快速、稳定且没有副作用。不要把输入校验、日志或业务动作放进比较函数。

一次用户事件、`DesktopApp.post` 动作或显式 `batch` 中，对同一状态的多次写入会合并成一次通知，观察者只看到事务开始前的值和最终值。这样派生状态不会暴露“部分字段已更新”的中间界面。

观察回调面向后续变化，注册时不会立即收到当前值。需要初始值时直接调用 `get()` 或读取 `value`。

## 局部状态与稳定身份

固定、无条件的声明可以写成 `rememberState<Bool> {false}`，按声明位置保留。条件分支、循环、插入、删除和重排会改变位置，因此动态结构应使用稳定业务键，并结合 `Keyed` 或 `ForEach`。完整写法见[构建稳定身份的数据列表](../how-to/data-list.md)。

键应非空、同级唯一，并且只代表业务对象身份。不要使用数组下标、随机值或会变化的显示文字。

`remember<T>` 用于保留控制器、格式化器、动画器或派生图等稳定对象；需要在卸载时关闭的资源应使用 `mountEffect` 或 `lifecycleEffect`，不要只依赖对象被丢弃。

## Binding 与 Lens

`Bindable.project` 适合只用一次的字段绑定。相同投影需要复用、组合或独立测试时，使用 `Lens<S, A>`，再通过 `profile.project(profileName)` 创建 Binding。

合法 Lens 应满足三条规则：读出后原样写回不改变整体；写入后能读回该值；连续写入等同于只保留最后一次。可以用 `cui.testing.checkLensLaws` 检查代表值。

修改当前值时优先调用 `update`，例如 `name.update({value => value.trimAscii()})`。

嵌套 Binding 会把修改合并为根模型的一次读写，避免深层投影重复读取根状态。

## 派生状态

`map` 适合单个源，`derive` 适合一至五个不同类型的源，`deriveStates` 适合同类型 `State` 数组。派生计算应保持纯函数：只读取参数并返回结果，不写状态、不访问文件、不启动任务。

如果源经常变化，而派生结果通常不变，可以给 `map` 或固定参数的 `derive` 传结果比较策略。比较本身也有成本，只适合字符串、枚举、小结构等便宜值。昂贵筛选应通过更合适的数据所有权或缓存边界解决。

在构建函数中长期使用的复杂派生图，可以用 `remember<DerivedState<T>> { ... }` 保留对象身份。

普通的一次性计算直接使用 `let` 即可，不必把所有表达式都变成派生状态。

## 线程边界

进入桌面应用后的 UI 状态由该应用的 UI 线程持有。后台任务应产生普通结果，再通过 `DesktopApp.post` 回到 UI 线程更新状态。不要从工作线程直接读写 `State` 或修改观察关系。

## 选择顺序

遇到新值时按以下顺序判断：

1. 能从现有事实算出：使用普通 `let` 或 `DerivedState`。
2. 只服务固定界面位置：使用 `rememberState`。
3. 属于业务模型或被多个区域共享：由显式 `State` 或 Store 持有。
4. 控件只编辑整体模型的一部分：提供 `Binding`。
5. 字段路径需要复用或组合：定义 `Lens`。

## 常见错误

- 把 `Binding` 当作状态副本：它只转发读写，不另存数据。
- 为计算结果再建 `State`：会增加同步责任。
- 在动态列表中使用位置身份：重排后状态会跟错项目。
- 在状态比较策略中执行副作用：比较次数不是业务契约。
- 从后台线程直接写 UI 状态：应通过 `DesktopApp.post` 投递结果。
- 只修改普通对象字段，却期待界面自动刷新：可见事实必须通过可观察状态进入依赖图。

## 相关 API

- [`State`](../../api/cui/core/State.md)、[`Binding`](../../api/cui/core/Binding.md)、[`DerivedState`](../../api/cui/core/DerivedState.md)
- [`Bindable.project`](../../api/cui/core/Bindable.md#project)、[`Lens`](../../api/cui/core/Lens.md)
- [`remember`](../../api/cui/core/functions.md#remember)、[`rememberState`](../../api/cui/core/functions.md#rememberstate)
- [`derive`](../../api/cui/core/functions.md#derive)、[`deriveStates`](../../api/cui/core/functions.md#derivestates)

## 下一步

继续阅读[模型、动作与界面边界](app-architecture.md)，把状态所有权扩展为可测试的应用结构；需要完整练习时完成[设置表单](../tutorials/settings-form.md)。
