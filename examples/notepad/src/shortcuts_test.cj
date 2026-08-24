package cui_notepad

import cui.EventKeyModifiers

private let CTRL_MASK: UInt16 = UInt16(0x0040)
private let SHIFT_MASK: UInt16 = UInt16(0x0001)

@Test
func notepadShortcutRequiresEventTimeCommandModifier(): Unit {
    @Expect(notepadShortcutFor(KEY_S, EventKeyModifiers()).isNone())
    @Expect(notepadShortcutFor(KEY_S, EventKeyModifiers(raw: CTRL_MASK)), Some(NotepadShortcut.SaveFile))
}

@Test
func notepadShortcutDistinguishesSaveAsAndLeavesEditorKeysAlone(): Unit {
    let commandShift = EventKeyModifiers(raw: CTRL_MASK | SHIFT_MASK)
    @Expect(notepadShortcutFor(KEY_S, commandShift), Some(NotepadShortcut.SaveFileAs))
    @Expect(notepadShortcutFor(UInt8(65), EventKeyModifiers(raw: CTRL_MASK)).isNone())
}
