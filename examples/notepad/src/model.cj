/*
 * 记事本的共享状态：正文缓冲、光标/滚动位置、文件路径与状态栏提示。
 *
 * 行数/字节统计是 DerivedState —— 正文一变，统计随之刷新，视图直接读取，
 * 无需在每帧里手工重算，也不可能与文档内容脱节。
 */
package cui_notepad

import cui.{DerivedState, FileDialogRequest, State, derive}

class NotepadModel {
    let body = State<String>("欢迎使用 CUI 记事本。\n中文与 English 均使用系统 UI 字体清晰显示。")
    /** 外部载入文档时光标与锚点同步移动；粘贴交由 TextArea 命令维护选区与历史。 */
    let bodyCursor = State<Int64>(body.value.size)
    let bodyAnchor = State<Int64>(body.value.size)
    let bodyScroll = State<Float32>(0.0)
    let currentPath = State<String>("")
    let status = State<String>("就绪")
    let readOnly = State<Bool>(false)
    /**
     * “新建”确认条是否可见。用状态驱动的应用内确认条代替系统 MessageBox，
     * 因为同步弹窗会阻塞事件循环，让打开/保存对话框的帧内轮询停摆。
     */
    let confirmingNew = State<Bool>(false)
    let openDialog = State<?FileDialogRequest>(None<FileDialogRequest>)
    let saveDialog = State<?FileDialogRequest>(None<FileDialogRequest>)
    /** 状态栏统计行，由正文派生：行数、字节数。 */
    let stats: DerivedState<String>
    private let savedBody = State<String>("")
    let dirty: DerivedState<Bool>

    init() {
        this.stats = this.body.map<String>({text => "${text.split("\n").size} 行  ·  ${text.size} 字节"})
        this.dirty = derive(this.body, this.savedBody, {body, saved => body != saved})
    }

    func markSaved(): Unit {
        savedBody.value = body.value
        // 保存或载入成功后，旧的“未保存修改”确认已失去前提。
        confirmingNew.value = false
    }
    func hasDialog(): Bool {
        openDialog.value.isSome() || saveDialog.value.isSome()
    }
}
