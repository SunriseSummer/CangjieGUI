<!-- kind: how-to; audience: desktop-app-developer -->

# 只构建大列表的可见部分

## 目标

把千级数据改成视口构建：固定行高用 `LazyColumn`，可变行高用 `LazyList`，横向条目用 `LazyRow`，规则网格用 `LazyGrid`。完成约需 15 分钟；先理解[布局与滚动](../concepts/layout-and-scrolling.md)。

## 适用场景

聊天记录、日志、时间线和搜索结果已经多到不能每帧重建全部条目时使用。只有几十项、每项构建很轻时，普通 `ForEach` 更简单，不必为“可能变大”提前虚拟化。

## 准备工作

先记录典型数据量、行高是否固定、每行有哪些必须跨滚动保留的业务状态。准备一个稳定业务 id，并确认外层只存在一个负责该方向滚动的容器。迁移前保留普通列表版本，便于比较选择、筛选和滚动位置是否改变。

## 操作步骤

### 1. 先判断高度是否固定

`LazyColumn(count, itemHeight)` 依靠固定行高直接计算可见索引，开销最低。若每行正文长度不同并会换行，改用 `LazyList`；不要给出假的固定高度再让内容溢出。

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

### 4. 数据数组使用稳定 key

```cangjie role=variation
LazyColumn.of(messages, 52.0,
    key: {message => message.id},
    revision: messagesRevision,
    scroll: Some(scroll), id: "messages") {
    message => MessageRow(message, drafts[message.id])
}
```

这里 `drafts` 属于页面模型。滚出视口再滚回时，新行会从模型取回草稿。插入、删除或排序后递增 `messagesRevision`，列表以顶部稳定 key 做像素锚定，不会让正在阅读的内容跳走。若行高不统一，把同一身份规则迁移到 `LazyList`，而不是在固定高度行里塞入任意高内容。

### 5. 可变高度选择 revision 或 extent 模型

高度只随一批数据更新时，把该批次版本传给 `revision`；版本不变期间 `LazyList` 复用 Fenwick 索引，不再每帧调用全部 `heightOf`：

```cangjie role=variation
LazyList.of(messages, {message => message.cachedHeight},
    key: {message => message.id}, revision: Some(messagesRevision), id: "thread") {
    message => MessageRow(message)
}
```

聊天气泡展开、增量测高等高频单行变化使用 `LazyListExtents`。`update` 为 O(log N) 并自动请求帧；插入/删除/重排才调用 O(N) 的 `reset`：

```cangjie role=variation
let extents = LazyListExtents(cachedHeights, spacing: 6.0)
LazyList.ofExtents(messages, extents, key: {message => message.id}, id: "thread") {
    message => MessageRow(message)
}
let _ = extents.update(changedIndex, measuredHeight)
```

### 6. 按业务 key 定位

把 `LazyViewportController` 放进页面模型，通过 `scrollToKey` 显示搜索命中、恢复阅读位置或先把待聚焦控件物化。控制器与 `scroll` 二选一；请求不存在的 key 后可用 `lastTargetFound()` 诊断。

```cangjie role=variation
controller.scrollToKey(selectedId, alignment: LazyScrollAlignment.Nearest)
LazyColumn.of(messages, 52.0, key: {message => message.id}, controller: controller, id: "messages") {
    message => MessageRow(message)
}
```

## 确认结果

运行完整程序并从第 0 行滚到数百行，滚轮应持续响应，滚动条不跳回顶部。改变窗口高度后列表继续占满剩余空间。代码评审时确认行构建函数没有磁盘读取、网络访问或大型排序；这些工作应在模型层预先完成。

再做一次身份验证：选中一个中部业务对象，改变筛选或排序，然后滚离并滚回。选择与草稿应跟随业务 id；纯行内展开状态若没有上提，则允许在卸载后复位。把这两类结果明确区分，避免把设计边界误报为虚拟化缺陷。

## 常见错误

- 把 `rememberState` 当跨滚动存储：行卸载后状态会被清理。
- 使用数组索引作 key：插入或重排后状态串到别项。
- 在行构建器里筛选整个数组：每个可见行都重复做同一工作。
- 数据/高度已稳定却不给 `LazyList` revision：兼容模式会为正确性每帧重扫全部高度。
- revision 已递增却仍用索引 key：锚定的是槽位，不是业务对象。
- 同时传 `scroll` 和 `controller`：所有权不明确，构造会直接拒绝。
- 外层和内层同时强制消费滚轮：内容不足一屏时形成滚动死区。

## 相关 API

[LazyColumn](../../api/cui/core/LazyColumn.md)、[LazyList](../../api/cui/core/LazyList.md)、[LazyListExtents](../../api/cui/core/LazyListExtents.md)、[LazyViewportController](../../api/cui/core/LazyViewportController.md)、[LazyRow](../../api/cui/core/LazyRow.md)、[LazyGrid](../../api/cui/core/functions.md)。

## 下一步

结构化数据继续看[表格主从界面](table-master-detail.md)，层级数据继续看[树与导航](tree-and-navigation.md)。
