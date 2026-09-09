package cui.text

import cui.core.{ImeComposition, UiContext}

// IME text replaces the active selection visually, without changing the document/undo history.
internal class TextEditorDisplay {
    let text: String
    let cursor: Int64
    let selectionStart: Int64
    let selectionEnd: Int64
    let compositionStart: Int64
    let compositionEnd: Int64
    private let replacedStart: Int64
    private let replacedEnd: Int64

    init(ctx: UiContext, id: String, edit: TextEditState, editable: Bool) {
        let original = edit.text.value
        let composition = if (editable) {
            ctx.imeComposition(id)
        } else {
            None<ImeComposition>
        }
        match (composition) {
            case Some(value) =>
                this.replacedStart = edit.selectionStart()
                this.replacedEnd = edit.selectionEnd()
                this.text = original[0..replacedStart] + value.text + original[replacedEnd..original.size]
                this.compositionStart = replacedStart
                this.compositionEnd = replacedStart + value.text.size
                let a = if (value.selectionStart < 0) {
                    value.text.size
                } else {
                    compositionByteAt(value.text, Int64(value.selectionStart))
                }
                let b = compositionByteAt(value.text, if (value.selectionStart < 0) {
                    Int64.Max
                } else {
                    Int64(value.selectionStart) + max(0, Int64(value.selectionLength))
                })
                this.cursor = replacedStart + b
                this.selectionStart = replacedStart + a
                this.selectionEnd = replacedStart + b
            case None =>
                this.text = original
                this.cursor = edit.cursor.value
                this.selectionStart = edit.selectionStart()
                this.selectionEnd = edit.selectionEnd()
                this.compositionStart = -1
                this.compositionEnd = -1
                this.replacedStart = 0
                this.replacedEnd = 0
        }
    }

    func composing(): Bool {
        compositionStart >= 0
    }
    func documentOffset(displayOffset: Int64): Int64 {
        if (!composing() || displayOffset <= replacedStart) {
            return displayOffset
        }
        if (displayOffset < compositionEnd) {
            return replacedStart
        }
        displayOffset - (compositionEnd - replacedEnd)
    }
}

private func compositionByteAt(text: String, scalar: Int64): Int64 {
    var byte: Int64 = 0;
    var index: Int64 = 0
    for (rune in text.runes()) {
        if (index >= scalar) {
            break
        }
        let value = UInt32(rune)
        byte += if (value < 0x80) {
            1
        } else if (value < 0x800) {
            2
        } else if (value < 0x10000) {
            3
        } else {
            4
        }
        index += 1
    }
    byte
}
