/*
 * 编辑器状态：正文、状态栏文案，以及由正文派生的行数与字数。
 *
 * 新建/清空改写正文，追加日期/分隔线在正文末尾追加；关于动作更新状态文案。
 * 保存记录内存检查点，退出演示可取消的关闭确认，不写磁盘文件。正文由 `TextArea` 双向绑定。
 */
package cui_editor

import cui.{CalendarDate, CloseRequest, DerivedState, State, derive}

class EditorModel {
    let text = State<String>(seedText())
    let status = State<String>("就绪")
    let readOnly = State<Bool>(false)
    let wrapLines = State<Bool>(true)
    let spaciousLines = State<Bool>(false)
    let steadyCaret = State<Bool>(false)
    let closePresented = State<Bool>(false)
    private let checkpoint = State<String>(seedText())
    private var pendingClose: ?CloseRequest = None
    var requestExit: () -> Unit = {=> ()}
    let chars: DerivedState<Int64>
    let lines: DerivedState<Int64>
    let dirty: DerivedState<Bool>

    init() {
        this.chars = this.text.map({t => charCount(t)})
        this.lines = this.text.map({t => lineCount(t)})
        this.dirty = derive(this.text, this.checkpoint, {text, checkpoint => text != checkpoint})
    }

    func newDoc(): Unit {
        text.value = ""
        status.value = "新建文档"
    }

    func save(): Unit {
        checkpoint.value = text.value
        status.value = "已记录内存检查点（未写入文件）：${chars.value} 字 · ${lines.value} 行"
    }

    func quit(): Unit {
        requestExit()
    }

    func confirmClose(request: CloseRequest): Unit {
        if (text.value == checkpoint.value) {
            request.accept();
            return
        }
        pendingClose = Some(request)
        closePresented.value = true
    }

    func cancelClose(): Unit {
        if (let Some(request) <- pendingClose) {
            request.cancel()
        }
        pendingClose = None
        closePresented.value = false
    }

    func acceptClose(checkpointFirst!: Bool = false): Unit {
        if (checkpointFirst) {
            save()
        }
        if (let Some(request) <- pendingClose) {
            request.accept()
        }
        pendingClose = None
        closePresented.value = false
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
        status.value = "CUI 写作空间 · 文本编辑与内存检查点示例"
    }

    /** 判空供菜单项的动态禁用使用（空文档时清空禁用）。 */
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
