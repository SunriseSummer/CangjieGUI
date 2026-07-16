/*
 * 工作台状态：文档列表、选中项、编辑绑定，以及两条分栏比例。
 *
 * 与笔记示例一致，编辑器用 `docs.project` 双向绑定到“当前选中文档的正文”，单一数据源、无缓冲副本。
 * 大纲与统计经 `derive` 从正文与选中项派生，编辑即刻更新。两条分栏比例（侧栏／编辑区）作为可观察
 * 状态由模型持有并交给 `SplitView`，因此拖动分隔条得到的布局在切换文档、乃至保存/恢复时都可延续。
 */
package cui_workbench

import cui.{Binding, DerivedState, State, derive}

class WorkbenchModel {
    let docs = State<Array<Doc>>(seedDocs())
    let selected = State<Int64>(0)
    let body: Binding<String>
    let outline: DerivedState<Array<Heading>>
    let stats: DerivedState<String>
    // 分栏比例：外层横向分栏（侧栏占比）与右侧纵向分栏（编辑区占比）。
    let sidebarRatio = State<Float32>(0.24)
    let editorRatio = State<Float32>(0.62)
    private var nextId: Int64 = 100

    init() {
        let sel = this.selected
        this.body = this.docs.project(
            get: {arr => docBodyAt(arr, sel.value)},
            set: {arr, value => withBodyAt(arr, sel.value, value)}
        )
        this.outline = derive(this.docs, this.selected, {arr, i => outlineOf(docBodyAt(arr, i))})
        this.stats = derive(this.docs, this.selected, {arr, i => statsText(docBodyAt(arr, i))})
    }

    func titles(): Array<String> {
        let arr = docs.value
        Array<String>(arr.size, {i => docTitle(arr[i].body)})
    }

    /*
     * 按文档区分的编辑器 id，让 TextArea 的光标与撤销历史各自保留，切换文档即重置为全新会话。
     */
    func editorId(): String {
        if (docs.value.isEmpty()) {
            "workbench.editor:none"
        } else {
            "workbench.editor:${docs.value[clampDocIndex(selected.value, docs.value.size)].id}"
        }
    }

    /** 选中文档标题，用作编辑区抬头。 */
    func currentTitle(): String {
        if (docs.value.isEmpty()) {
            "（无文档）"
        } else {
            docTitle(docs.value[clampDocIndex(selected.value, docs.value.size)].body)
        }
    }

    func addDoc(): Unit {
        nextId += 1
        let arr = docs.value
        docs.value = Array<Doc>(arr.size + 1, {i => if (i < arr.size) {
            arr[i]
        } else {
            Doc(nextId, "# 新文档\n")
        }})
        selected.value = docs.value.size - 1
    }
}
