/*
 * 笔记主从状态。
 *
 * 编辑器不复制正文，而是用 `notes.project` 把 TextArea 双向绑定到“当前选中笔记的正文”——
 * 读取取选中笔记，写入整表替换该笔记，单一数据源、无需手工同步缓冲区。切换笔记只改 `selected`，
 * 绑定即读到新笔记；编辑器的 id 含笔记 id，避免不同文档共用光标与撤销历史。
 */
package cui_notes

import std.collection.ArrayList
import cui.{Binding, DerivedState, State, derive}

class NotesModel {
    let notes = State<Array<Note>>(seedNotes())
    let selected = State<Int64>(0)
    /** 是否正在弹出「删除确认」对话框。 */
    let confirmDelete = State<Bool>(false)
    let body: Binding<String>
    let stats: DerivedState<String>
    private var nextId: Int64 = 100

    init() {
        let sel = this.selected
        this.body = this.notes.project(
            get: {arr => noteBodyAt(arr, sel.value)},
            set: {arr, value => withBodyAt(arr, sel.value, value)}
        )
        this.stats = derive(this.notes, this.selected, {arr, i => statsText(noteBodyAt(arr, i))})
    }

    func titles(): Array<String> {
        let arr = notes.value
        Array<String>(arr.size, {i => noteTitle(arr[i].body)})
    }

    /*
     * 按笔记区分编辑器身份；切换时不沿用上一条笔记的光标与撤销栈。
     * 卸载的编辑会话由框架回收，本示例不长期缓存每条笔记的编辑历史。
     */
    func editorId(): String {
        if (notes.value.isEmpty()) {
            "notes.editor:none"
        } else {
            "notes.editor:${notes.value[clampNoteIndex(selected.value, notes.value.size)].id}"
        }
    }

    func addNote(): Unit {
        nextId += 1
        let arr = notes.value
        notes.value = Array<Note>(arr.size + 1, {
            i => if (i < arr.size) {
                arr[i]
            } else {
                Note(nextId, "")
            }
        })
        selected.value = notes.value.size - 1
    }

    func duplicateSelected(): Unit {
        let arr = notes.value
        if (arr.isEmpty()) {
            return
        }
        let at = clampNoteIndex(selected.value, arr.size)
        nextId += 1
        let copy = Note(nextId, arr[at].body)
        let result = ArrayList<Note>()
        for (i in 0..arr.size) {
            result.add(arr[i])
            if (i == at) {
                result.add(copy)
            }
        }
        notes.value = result.toArray()
        selected.value = at + 1
    }

    func deleteSelected(): Unit {
        let arr = notes.value
        if (arr.isEmpty()) {
            return
        }
        let target = clampNoteIndex(selected.value, arr.size)
        let remaining = ArrayList<Note>()
        for (i in 0..arr.size) {
            if (i != target) {
                remaining.add(arr[i])
            }
        }
        notes.value = remaining.toArray()
        selected.value = clampNoteIndex(target, notes.value.size)
    }
}

func statsText(body: String): String {
    "${body.split("\n").size} 行 · ${body.size} 字节"
}
