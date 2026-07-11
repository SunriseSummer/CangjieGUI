/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import sdl.{SdlDialogFileFilter}

internal func allocateFileDialogResources(id: Int64, options: FileDialogOptions): FileDialogNativeResources {
    let rawFilters = allocateRawDialogFilters(options.filters.size)
    let names = Array<CString>(options.filters.size, {_ => nullDialogCString()})
    let patterns = Array<CString>(options.filters.size, {_ => nullDialogCString()})
    let defaultLocation = optionalDialogCString(options.defaultLocation)
    let idPtr = unsafe { LibC.malloc<Int64>() }

    try {
        unsafe { idPtr.write(id) }
        fillRawDialogFilters(rawFilters, names, patterns, options.filters)
        FileDialogNativeResources(idPtr, rawFilters, Int32(options.filters.size), names, patterns, defaultLocation)
    } catch (e: Exception) {
        freeDialogCStringArray(names)
        freeDialogCStringArray(patterns)
        freeDialogCString(defaultLocation)
        unsafe {
            if (rawFilters.isNotNull()) {
                LibC.free(rawFilters)
            }
            if (idPtr.isNotNull()) {
                LibC.free(idPtr)
            }
        }
        throw e
    }
}

internal func allocateRawDialogFilters(count: Int64): CPointer<SdlDialogFileFilter> {
    if (count <= 0) {
        CPointer<SdlDialogFileFilter>()
    } else {
        unsafe { LibC.malloc<SdlDialogFileFilter>(count: count) }
    }
}

internal func fillRawDialogFilters(
    rawFilters: CPointer<SdlDialogFileFilter>,
    names: Array<CString>,
    patterns: Array<CString>,
    filters: Array<FileDialogFilter>
): Unit {
    for (i in 0..filters.size) {
        names[i] = unsafe { LibC.mallocCString(filters[i].name) }
        patterns[i] = unsafe { LibC.mallocCString(filters[i].pattern) }
        unsafe { rawFilters.write(i, rawDialogFilter(names[i], patterns[i])) }
    }
}

internal func optionalDialogCString(value: ?String): CString {
    match (value) {
        case Some(text) => unsafe { LibC.mallocCString(text) }
        case None => nullDialogCString()
    }
}

internal func nullDialogCString(): CString {
    CString(CPointer<UInt8>())
}

internal func freeDialogCString(value: CString): Unit {
    if (!value.isNull()) {
        unsafe { LibC.free(value) }
    }
}

internal func freeDialogCStringArray(values: Array<CString>): Unit {
    for (value in values) {
        freeDialogCString(value)
    }
}
