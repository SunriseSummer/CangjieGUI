<!-- kind: how-to; audience: desktop-app-developer -->

# 只构建大列表的可见部分

## 目标

把千级数据改成视口构建：固定行高用 `LazyColumn`，可变行高优先用自测量 `LazyList`，横向条目用 `LazyRow`，规则网格用 `LazyGrid`。完成约需 15 分钟；先理解[布局与滚动](../concepts/layout-and-scrolling.md)。

## 适用场景

聊天记录、日志、时间线和搜索结果较多，构建及布局全部条目的成本已影响响应时使用。只有几十项、每项构建很轻时，普通 `ForEach` 更简单，不必为“可能变大”提前虚拟化。

## 准备工作

先记录典型数据量、行高是否固定、每行有哪些必须跨滚动保留的业务状态。准备一个稳定业务 id，并确认外层只存在一个负责该方向滚动的容器。迁移前保留普通列表版本，便于比较选择、筛选和滚动位置是否改变。

## 操作步骤

### 1. 先判断高度是否固定

`LazyColumn(count, itemHeight)` 依靠固定行高直接计算可见索引，开销最低。若每行正文长度不同并会换行，改用 `LazyList.measured`；不要给出假的固定高度再让内容溢出，也不必为了框架另建一份逐行高度状态。

### 2. 把业务状态上提

虚拟列表只创建视口附近的行，滚远后行会卸载。选择、编辑草稿、加载状态等必须按业务 id 放进模型。`key` 返回稳定 id，不能返回当前索引。

### 3. 运行固定行高版本

```cangjie verify role=complete profile=gui-visual
package docexample

import cui.*

main(): Unit {
    let app = DesktopApp(WindowSpec("千行收件箱", 640, 420))
    app.run {
        let scroll = rememberState<Float32>("mail-scroll") {0.0}
        LazyColumn(1000, 48.0, spacing: 8.0, scroll: Some(scroll), id: "mail-list") {
            index => HStack(spacing: 12.vp) {
                Label("#${index}").muted().width(70.vp)
                Label("第 ${index} 封邮件").flex()
            }.padding(8.vp)
        }
    }
}
```

### 4. 可观察数据直接交给列表

数据已经由 `State<Array<Message>>` 持有时，使用 `LazyColumn.of(messageState, 52.0, key: {message => message.id}, ...)`。插入、删除或排序后给 State 赋回新数组；不要只原地修改数组，因为那不会产生新的状态版本。行内草稿按业务 ID 放在页面模型中，滚出视口再回来时由新行读取。

数据来自不可观察的外部快照时，可以使用 `Array<T>` 重载并显式传 `revision`。行高不统一时保留相同身份规则，改用 `LazyList`。

### 5. 可变高度先使用自测量

使用 `LazyList.measured(messageState, estimatedHeight: 72.0, key: {message => message.id}, ...)`。只需提供典型行高作为未知区域的初始估计；可见行会自动测量，前序行变高时列表会用顶部业务键保持阅读位置。

行根必须有有限 intrinsic height。可见行中影响高度的普通 State 会由测量依赖自动跟踪。唯一稳定 key 还会让框架在结构变化后把已经学到的高度迁移给同一业务对象；稳定帧不会扫描全部数据。估计不必精确，它只影响从未测量过的区域和新 key 的初始滚动条。

固定高度、State 数据、`LazyListExtents` 与自测量形式都有可观察几何版本。滚动停留在当前物化区间时，框架只更新行坐标；越过预取边界才重新执行列表声明体。不要为了获得这一优化手写滚动节流或缓存 Widget，框架会在布局期复核最新 revision，并在同帧补齐缺少的行。

### 6. 已有高度管线时选择 revision 或 extent 模型

已经有缓存高度时，使用 `LazyList.of` 并让 `heightOf` 返回该高度。State 数据会自动使用赋值修订号复用位置索引；不可观察的 Array 快照应传 `revision: Some(messagesRevision)`。

聊天气泡展开、增量测高等频繁单行变化使用 `LazyListExtents` 和 `LazyList.ofExtents`。单行高度变化调用 `update`；只有插入、删除或重排才调用 `reset`。精确签名和完整示例见 [`LazyList`](../../api/cui/core/LazyList.md) 与 [`LazyListExtents`](../../api/cui/core/LazyListExtents.md)。

### 7. 按索引或业务 key 定位

把 `LazyViewportController` 放进页面模型。已有当前数组索引时调用 `scrollToIndex`；需要在请求期间发生重排后仍定位同一业务对象时调用 `scrollToKey`。控制器和外部 `scroll` 状态二选一。索引越界或键不存在后，可用 `lastTargetFound()` 判断请求是否成功。

## 确认结果

运行完整程序并从第 0 行滚到数百行，滚轮应持续响应，滚动条不跳回顶部。改变窗口高度后列表继续占满剩余空间。代码评审时确认行构建函数没有磁盘读取、网络访问或大型排序；这些工作应在模型层预先完成。

再做一次身份验证：选中一个中部业务对象，改变筛选或排序，然后滚离并滚回。选择与草稿应跟随业务 id；纯行内展开状态若没有上提，则允许在卸载后复位。把这两类结果明确区分，避免把设计边界误报为虚拟化缺陷。

## 常见错误

- 把 `rememberState` 当跨滚动存储：行卸载后状态会被清理。
- 使用数组索引作 key：插入或重排后状态串到别项。
- 在行构建器里筛选整个数组：每个可见行都重复做同一工作。
- 不可观察的 Array 数据/高度已稳定却不给 `LazyList` revision：兼容模式会为正确性随滚动重建并重扫全部高度。
- 原地改写 `State<Array<T>>` 内的数组：没有 State 赋值就不会推进结构版本；应构造并赋回新数组。
- 自测量行使用 `.fillHeight()` 或裸 `Spacer`：无界高度下没有有限 intrinsic height。
- revision 已递增却仍用索引 key：锚定的是槽位，不是业务对象。
- 同时传 `scroll` 和 `controller`：所有权不明确，构造会直接拒绝。
- 外层和内层同时强制消费滚轮：内容不足一屏时形成滚动死区。

## 相关 API

[LazyColumn](../../api/cui/core/LazyColumn.md)、[LazyList](../../api/cui/core/LazyList.md)、[LazyListExtents](../../api/cui/core/LazyListExtents.md)、[LazyViewportController](../../api/cui/core/LazyViewportController.md)、[LazyRow](../../api/cui/core/LazyRow.md)、[LazyGrid](../../api/cui/core/functions.md)。

## 下一步

结构化数据继续看[表格主从界面](table-master-detail.md)，层级数据继续看[树与导航](tree-and-navigation.md)。
