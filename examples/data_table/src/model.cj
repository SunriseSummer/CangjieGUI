/*
 * 机群监控模型：一份固定的服务器行数据、一个选中行索引，以及由选中行派生的详情文本。
 * 选择由 `Table` 以“原始行索引”存储，故排序改变显示顺序时高亮仍跟随同一台服务器。
 */
package cui_data_table

import cui.{DerivedState, State}

class FleetModel {
    let servers = seedServers()
    let selected = State<Int64>(0)
    let summary: DerivedState<String>

    init() {
        let data = this.servers
        this.summary = this.selected.map<String>({index => serverSummary(data, index)})
    }
}
