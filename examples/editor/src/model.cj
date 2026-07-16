/*
 * 编辑器状态：正文、状态栏文案，以及由正文派生的行数与字数。
 *
 * 菜单动作都作用于这里的模型：新建/清空改写正文，追加日期/分隔线在正文末尾追加，打开/保存/退出/关于
 * 仅更新状态栏文案（示例不做真实文件与退出）。正文由 `TextArea` 双向绑定，菜单改动即刻反映到编辑区。
 */
package cui_editor

import cui.{CalendarDate, DerivedState, State}

class EditorModel {
    let text = State<String>(seedText())
    let status = State<String>("就绪")
    let chars: DerivedState<Int64>
    let lines: DerivedState<Int64>

    init() {
        this.chars = this.text.map({t => charCount(t)})
        this.lines = this.text.map({t => lineCount(t)})
    }

    func newDoc(): Unit {
        text.value = ""
        status.value = "新建文档"
    }

    func open(): Unit {
        status.value = "（示例）打开文件对话框"
    }

    func save(): Unit {
        status.value = "已保存：${chars.value} 字 · ${lines.value} 行"
    }

    func quit(): Unit {
        status.value = "（示例中不真正退出）"
    }

    func appendDate(): Unit {
        append(CalendarDate.today().iso())
    }

    func appendRule(): Unit {
        append("————————")
    }

    func clear(): Unit {
        text.value = ""
        status.value = "已清空"
    }

    func about(): Unit {
        status.value = "CUI 菜单栏示例 · v0.1"
    }

    /** 判空供菜单项的动态禁用使用（空文档时保存/清空禁用）。 */
    func isEmpty(): Bool {
        text.value.isEmpty()
    }

    private func append(line: String): Unit {
        let current = text.value
        text.value = if (current.isEmpty()) {
            line
        } else {
            "${current}\n${line}"
        }
        status.value = "已追加"
    }
}
