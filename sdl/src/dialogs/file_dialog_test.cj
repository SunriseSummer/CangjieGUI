/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import sdl.{CuiException}

@Test
func fileDialogFilterPatternsValidateSdlRules(): Unit {
    @Expect(isValidDialogFilterPattern("*"))
    @Expect(isValidDialogFilterPattern("txt;md;log"))
    @Expect(isValidDialogFilterPattern("tar.gz"))
    @Expect(!isValidDialogFilterPattern(""))
    @Expect(!isValidDialogFilterPattern(";txt"))
    @Expect(!isValidDialogFilterPattern("txt;"))
    @Expect(!isValidDialogFilterPattern("*.txt"))
}

@Test
func fileDialogOptionsRejectInvalidFilters(): Unit {
    @Expect(fileDialogOptionsFail([FileDialogFilter("", "txt")]))
    @Expect(fileDialogOptionsFail([FileDialogFilter("Text", "*.txt")]))
}

@Test
func fileDialogResultConvertsNullAndCancelStates(): Unit {
    expectDialogFailed(fileDialogResultFromPointer(CPointer<CPointer<UInt8>>(), -1))

    let list = unsafe { LibC.malloc<CPointer<UInt8>>(count: 1) }
    try (resource = list.asResource()) {
        unsafe { resource.value.write(0, CPointer<UInt8>()) }
        expectDialogCanceled(fileDialogResultFromPointer(resource.value, -1))
    }
}

@Test
func fileDialogResultCopiesSelectedPaths(): Unit {
    let list = unsafe { LibC.malloc<CPointer<UInt8>>(count: 3) }
    let first = unsafe { LibC.mallocCString("C:/tmp/one.txt") }
    let second = unsafe { LibC.mallocCString("C:/tmp/two.txt") }
    try (listResource = list.asResource()) {
        try (firstResource = first.asResource()) {
            try (secondResource = second.asResource()) {
                unsafe {
                    listResource.value.write(0, firstResource.value.getChars())
                    listResource.value.write(1, secondResource.value.getChars())
                    listResource.value.write(2, CPointer<UInt8>())
                }
                match (fileDialogResultFromPointer(listResource.value, 2)) {
                    case FileDialogResult.FileDialogSelected(paths, filter) =>
                        @Expect(paths.size, Int64(2))
                        @Expect(paths[0], "C:/tmp/one.txt")
                        @Expect(paths[1], "C:/tmp/two.txt")
                        expectSelectedFilter(filter, 2)
                    case _ => @Fail("Dialog file list should convert to selected paths.")
                }
            }
        }
    }
}

private func fileDialogOptionsFail(filters: Array<FileDialogFilter>): Bool {
    try {
        ensureFileDialogOptions(FileDialogOptions(filters: filters))
        false
    } catch (e: CuiException) {
        true
    }
}

private func expectDialogFailed(result: FileDialogResult): Unit {
    match (result) {
        case FileDialogResult.FileDialogFailed(_) => @Expect(true)
        case _ => @Fail("Null file list should become a dialog failure.")
    }
}

private func expectDialogCanceled(result: FileDialogResult): Unit {
    match (result) {
        case FileDialogResult.FileDialogCanceled => @Expect(true)
        case _ => @Fail("Empty file list should become a canceled dialog.")
    }
}

private func expectSelectedFilter(filter: ?Int32, expected: Int32): Unit {
    match (filter) {
        case Some(value) => @Expect(value, expected)
        case None => @Fail("Selected filter should be present.")
    }
}
