/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.input

@Test
func systemCursorCodeMapsSdlValues(): Unit {
    @Expect(systemCursorCode(SystemCursor.Default), 0)
    @Expect(systemCursorCode(SystemCursor.Text), 1)
    @Expect(systemCursorCode(SystemCursor.Wait), 2)
    @Expect(systemCursorCode(SystemCursor.Crosshair), 3)
    @Expect(systemCursorCode(SystemCursor.Progress), 4)
    @Expect(systemCursorCode(SystemCursor.NwseResize), 5)
    @Expect(systemCursorCode(SystemCursor.NeswResize), 6)
    @Expect(systemCursorCode(SystemCursor.EwResize), 7)
    @Expect(systemCursorCode(SystemCursor.NsResize), 8)
    @Expect(systemCursorCode(SystemCursor.Move), 9)
    @Expect(systemCursorCode(SystemCursor.NotAllowed), 10)
    @Expect(systemCursorCode(SystemCursor.Pointer), 11)
    @Expect(systemCursorCode(SystemCursor.NwResize), 12)
    @Expect(systemCursorCode(SystemCursor.NResize), 13)
    @Expect(systemCursorCode(SystemCursor.NeResize), 14)
    @Expect(systemCursorCode(SystemCursor.EResize), 15)
    @Expect(systemCursorCode(SystemCursor.SeResize), 16)
    @Expect(systemCursorCode(SystemCursor.SResize), 17)
    @Expect(systemCursorCode(SystemCursor.SwResize), 18)
    @Expect(systemCursorCode(SystemCursor.WResize), 19)
}
