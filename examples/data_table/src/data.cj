/*
 * 表格的列定义与种子数据。数据是一份强类型的 `Server` 数组；`Table.of` 的每个 `DataColumn` 用 `value`
 * 抽取器从 `Server` 取出单元格字符串，数值列声明 `numeric: true`，由 `Table` 右对齐并按数值（而非
 * 字典序）排序——数据保持类型化，无需手搭 `Array<Array<String>>` 字符串矩阵。
 *
 * “CPU %” 列演示自定义单元格（`DataColumn.cell`）：抽取器仍产出 “23” 这样的数值文本，numeric 排序照常
 * 生效，绘制则由回调接管——迷你负载条 + 右对齐数值，负载越高颜色越警示。表格先画好行底与选中高亮并
 * 把回调裁剪在单元格内，回调只负责内容。
 */
package cui_data_table

import cui.{Color, DataColumn, FontSizes, Rect, UiContext, clampF32}

/** 一台服务器的类型化行数据；表格列由此抽取字段。 */
struct Server {
    let host: String
    let region: String
    let cpu: Int64
    let memory: Int64
    let connections: Int64
    let status: String

    init(host: String, region: String, cpu: Int64, memory: Int64, connections: Int64, status: String) {
        this.host = host
        this.region = region
        this.cpu = cpu
        this.memory = memory
        this.connections = connections
        this.status = status
    }
}

func serverColumns(): Array<DataColumn<Server>> {
    [
        DataColumn<Server>("主机名", 180.0) {s => s.host},
        DataColumn<Server>("区域", 100.0) {s => s.region},
        DataColumn<Server>("CPU %", 100.0, numeric: true, cell: cpuCellPainter) {s => "${s.cpu}"},
        DataColumn<Server>("内存 %", 100.0, numeric: true) {s => "${s.memory}"},
        DataColumn<Server>("连接数", 120.0, numeric: true) {s => "${s.connections}"},
        DataColumn<Server>("状态", 110.0) {s => s.status}
    ]
}

/** “CPU %” 单元格：左侧负载条按百分比填充，右侧保留数值文本。 */
func cpuCellPainter(ctx: UiContext, _: Int64, value: String, cell: Rect): Unit {
    let percent = clampF32(Float32(leadingInt(value)) / 100.0, 0.0, 1.0)
    let track = Rect(cell.x + 10.0, cell.centerY() - 3.0, max(0.0, cell.w - 56.0), 6.0)
    ctx.renderer.fillRoundedRect(track, 3.0, ctx.theme.panelEdge.withAlpha(90))
    if (percent > 0.0) {
        ctx.renderer.fillRoundedRect(Rect(track.x, track.y, track.w * percent, track.h), 3.0, loadColor(ctx, percent))
    }
    let ty = cell.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CAPTION) / 2.0
    let tw = ctx.renderer.textWidth(value, pointSize: FontSizes.CAPTION)
    ctx.renderer.text(value, cell.right() - 10.0 - tw, ty, ctx.theme.mutedText, pointSize: FontSizes.CAPTION)
}

/** 负载配色：85% 以上用主题危险色，60% 以上用琥珀警示，其余用平稳的绿色。 */
func loadColor(ctx: UiContext, percent: Float32): Color {
    if (percent >= 0.85) {
        ctx.theme.danger
    } else if (percent >= 0.6) {
        Color.rgb(228, 146, 34)
    } else {
        Color.rgb(58, 165, 102)
    }
}

/** 解析单元格开头的十进制整数（“23” → 23）；无数字时为 0。 */
func leadingInt(text: String): Int64 {
    var value = 0
    var i = 0
    while (i < text.size && text[i] >= UInt8(48) && text[i] <= UInt8(57)) {
        value = value * 10 + Int64(text[i]) - 48
        i += 1
    }
    value
}

func seedServers(): Array<Server> {
    [
        Server("web-01", "华东", 23, 41, 1280, "正常"),
        Server("web-02", "华东", 67, 58, 3410, "正常"),
        Server("web-03", "华南", 45, 39, 2050, "正常"),
        Server("api-01", "华北", 88, 72, 5120, "繁忙"),
        Server("api-02", "华北", 12, 33, 540, "正常"),
        Server("api-03", "华东", 76, 64, 4300, "繁忙"),
        Server("db-master", "华东", 54, 81, 220, "正常"),
        Server("db-replica-1", "华南", 9, 48, 180, "正常"),
        Server("db-replica-2", "华北", 7, 46, 160, "正常"),
        Server("cache-01", "华东", 31, 88, 9600, "正常"),
        Server("cache-02", "华南", 28, 85, 8700, "正常"),
        Server("queue-01", "华北", 19, 52, 760, "正常"),
        Server("worker-01", "华东", 94, 77, 40, "繁忙"),
        Server("worker-02", "华南", 5, 22, 0, "离线"),
        Server("gateway-01", "华北", 61, 55, 6100, "正常"),
        Server("monitor-01", "华东", 14, 29, 95, "正常")
    ]
}

func serverSummary(servers: Array<Server>, index: Int64): String {
    if (index < 0 || index >= servers.size) {
        return "未选择 · 点击任意行查看详情"
    }
    let s = servers[index]
    "${s.host} · ${s.region} · CPU ${s.cpu}% · 内存 ${s.memory}% · ${s.connections} 连接 · ${s.status}"
}
