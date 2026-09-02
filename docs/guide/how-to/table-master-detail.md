[CUI 指南](../index.md) › 表格与详情

# 构建可排序表格与详情面板

## 目标

用 `Table` 展示多列数据，支持排序和行选择，并在旁边显示选中对象详情。表头排序只改变显示顺序，`selected` 仍保存原始数据行索引；应用层在过滤或替换数据时再用业务 id 重新映射这个索引。

## 适用场景

服务器、联系人、进程、订单等结构化记录适合表格。若每项主要是标题/摘要且没有列比较，使用 `ListView` 更简单；若数据量巨大，确认表格的窗口化行为和行模型满足规模。

## 准备工作

每条业务记录有稳定 id。基础 `Table` 接收字符串矩阵和 `TableColumn`；`Table.of` 配合 `DataColumn<T>` 从类型化记录提取显示字符串。当前 `DataColumn` 没有独立排序键：同一字符串用于显示和排序，`numeric: true` 时按数值解释。模型可另外保存业务 id，并在数据变化后映射为表格需要的原始行索引。

## 操作步骤

### 1. 定义列语义

基础形式由 `TableColumn` 定义标题、宽度和是否数值排序；类型化形式由 `DataColumn<T>` 再提供字段提取函数。数值列交给表格的字符串应能解析为数值。若想显示 `%` 等格式，可用 painter 改绘制外观，但当前没有单独的任意排序键回调。

### 2. 让选择跟随数据

`Table.selected` 的公开契约是**原始输入数组索引**，不是业务 id，也不是当前排序后的屏幕行号。点击列头时，表格保持这个原始索引，因此高亮仍是同一输入行。应用自己过滤、删除或替换数组时，应先保存业务 id，再在新数组中查找并写回新索引。

### 3. 组合主从布局

用 `SplitView` 或 `HStack` 把表格与详情分开。表格区域伸缩，详情设置合理最小宽度。未选择时显示引导，不要访问不存在的记录。

只使用 `Table.selected` 时，选择第二行再按“负载”表头排序，详情仍读取原始索引 1；但应用过滤或删除输入数组后，
这个索引可能指向另一条记录。下面的完整方案把选择提升为业务 id，再使用 `Binding.project` 在 `Table` 读写索引时完成
双向转换。“只看高负载”会把 `web-02` 从索引 1 移到索引 0，“删除 db-01”再次替换数组，但详情仍追踪
`web-02`：

```cangjie verify role=complete profile=gui-visual
package docexample

import std.collection.ArrayList
import cui.*

class Server {
    let id: String
    let host: String
    let load: Int64

    init(id: String, host: String, load: Int64) {
        this.id = id
        this.host = host
        this.load = load
    }
}

class FleetState {
    let rows: Array<Server>
    let selectedId: String

    init(rows: Array<Server>, selectedId: String) {
        this.rows = rows
        this.selectedId = selectedId
    }
}

func rowIndexOfId(rows: Array<Server>, id: String): Int64 {
    for (i in 0..rows.size) {
        if (rows[i].id == id) {
            return i
        }
    }
    -1
}

func replaceRows(state: FleetState, rows: Array<Server>): FleetState {
    let nextId = if (rowIndexOfId(rows, state.selectedId) >= 0) {
        state.selectedId
    } else if (rows.size > 0) {
        rows[0].id
    } else {
        ""
    }
    FleetState(rows, nextId)
}

func highLoad(rows: Array<Server>): Array<Server> {
    let result = ArrayList<Server>()
    for (server in rows) {
        if (server.load >= 50) {
            result.add(server)
        }
    }
    result.toArray()
}

func withoutId(rows: Array<Server>, targetId: String): Array<Server> {
    let result = ArrayList<Server>()
    for (server in rows) {
        if (server.id != targetId) {
            result.add(server)
        }
    }
    result.toArray()
}

// 第一排序条件是负载从高到低；负载相同时再按主机名升序。
func hostLess(a: String, b: String): Bool {
    var i = 0
    while (i < a.size && i < b.size) {
        if (a[i] != b[i]) {
            return a[i] < b[i]
        }
        i += 1
    }
    a.size < b.size
}

func serverLess(a: Server, b: Server): Bool {
    if (a.load != b.load) {
        return a.load > b.load
    }
    hostLess(a.host, b.host)
}

func sortByLoadAndHost(rows: Array<Server>): Array<Server> {
    let remaining = ArrayList<Server>()
    for (server in rows) {
        remaining.add(server)
    }
    let result = ArrayList<Server>()
    while (remaining.size > 0) {
        var first = 0
        var i = 1
        while (i < remaining.size) {
            if (serverLess(remaining[i], remaining[first])) {
                first = i
            }
            i += 1
        }
        result.add(remaining[first])
        remaining.remove(at: first)
    }
    result.toArray()
}

main(): Unit {
    let fleet = State<FleetState>(
        FleetState(
            [
                Server("web-01", "web-01", 8),
                Server("web-02", "web-02", 63),
                Server("api-02", "api-02", 63),
                Server("db-01", "db-01", 100)
            ],
            "web-02"
        )
    )
    let sorted = sortByLoadAndHost(fleet.value.rows)
    fleet.value = replaceRows(fleet.value, sorted)
    if (sorted[0].host != "db-01" || sorted[1].host != "api-02" || sorted[2].host != "web-02" ||
        fleet.value.selectedId != "web-02") {
        throw IllegalStateException("双键排序后必须按业务 id 保持选择")
    }
    let app = DesktopApp(WindowSpec("业务 id 重映射", 780, 440))
    app.run {
        let selectedIndex = fleet.project<Int64>(
            get: {state => rowIndexOfId(state.rows, state.selectedId)},
            set: {
                state, index =>
                    let id = if (index >= 0 && index < state.rows.size) {
                        state.rows[index].id
                    } else {
                        ""
                    }
                    FleetState(state.rows, id)
            }
        )
        VStack(spacing: 10.vp) {
            HStack {
                Button("只看高负载", {
                    => fleet.value = replaceRows(fleet.value, highLoad(fleet.value.rows))
                })
                Button("按负载、主机排序", {
                    => fleet.value = replaceRows(fleet.value, sortByLoadAndHost(fleet.value.rows))
                })
                Button("删除 db-01", {
                    => fleet.value = replaceRows(fleet.value, withoutId(fleet.value.rows, "db-01"))
                })
            }.spacing(8.vp)
            Table.of(
                fleet.value.rows,
                [
                    DataColumn<Server>("主机", 150.0) {server => server.host},
                    DataColumn<Server>("负载", 90.0, numeric: true) {server => "${server.load}"}
                ],
                selectedIndex
            ).flex()
            Label(
                "先按负载降序，同负载按主机升序；业务 id：${fleet.value.selectedId}；当前索引：${selectedIndex.value}")
        }.padding(16.vp)
    }
}
```

### 4. 派生详情

详情标题、统计和操作按钮从 `selected` 对应的原始记录得到。若应用还保存业务 id，删除或过滤后先用 id 在新数据中查找索引，再更新 `selected`；不要把旧索引直接套到新数组。

### 5. 验证键盘操作

Tab 进入表格后用方向键、Home/End 改变行选择，确认详情同步。鼠标和键盘都应调用同一选择动作。

## 确认结果

在完整程序中，初始标签显示业务 id `web-02`、索引 1；点击“只看高负载”后索引变为 0，点击“删除 db-01”后仍是 `web-02`、索引 0。再按“负载”列升/降序，高亮与详情也应仍显示 `web-02`。若删除当前业务 id，`replaceRows` 会按页面策略选择首项或清空。前面的基础变化只用于观察表格内部排序边界；它不能替代这条过滤与删除验收。

## 常见错误

- 对“100%”“9%”按字符串排序，得到错误顺序。
- 保存当前屏幕行号，排序后选择跳到别的记录。
- 以为 painter 能提供另一套排序键；当前排序仍读取列字符串。
- 详情复制一份记录，编辑后与表格模型分叉。
- 表格和详情都固定宽度，小窗口无法到达操作。
- 过滤后继续操作隐藏的旧选择。

## 相关 API

- [`Table`](../../api/cui/controls/Table.md)、[`TableColumn`](../../api/cui/controls/TableColumn.md) 与 [`DataColumn`](../../api/cui/controls/DataColumn.md) — 两种行模型、排序、选择和窗口化。
- [`SplitView`](../../api/cui/controls/SplitView.md) — 可调主从布局。
- [`State`](../../api/cui/core/State.md) 与 [`DerivedState`](../../api/cui/core/DerivedState.md) — 选择和详情派生。

## 下一步

层级数据继续[树形导航与详情](tree-and-navigation.md)。

需要编辑或删除确认时继续[模态确认与 Toast](modal-and-toast.md)。如果排序后状态跟错行，回到[数据列表](data-list.md)检查 id 与屏幕位置是否混用。
