/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.input

import std.collection.ArrayList

internal func clipboardStringFromOwnedCString(text: CString): String {
    if (text.isNull()) {
        return ""
    }
    try {
        text.toString()
    } finally {
        unsafe { SDL_free(text.getChars()) }
    }
}

internal func clipboardBytesFromPointer(data: CPointer<UInt8>, size: UIntNative): Array<UInt8> {
    if (data.isNull() || size == UIntNative(0)) {
        return []
    }
    let count = Int64(size)
    let bytes = Array<UInt8>(count, {_ => UInt8(0)})
    for (i in 0..count) {
        bytes[i] = unsafe { data.read(i) }
    }
    bytes
}

internal func clipboardMimeTypesFromPointer(
    mimeTypes: CPointer<CPointer<UInt8>>,
    count: UIntNative
): Array<String> {
    let results = ArrayList<String>()
    for (i in 0..Int64(count)) {
        let mimeType = unsafe { mimeTypes.read(i) }
        if (mimeType.isNotNull()) {
            results.add(CString(mimeType).toString())
        }
    }
    results.toArray()
}

internal func copyClipboardBytesToNative(bytes: Array<UInt8>): CPointer<UInt8> {
    if (bytes.size <= 0) {
        return CPointer<UInt8>()
    }
    let buffer = unsafe { LibC.malloc<UInt8>(count: bytes.size) }
    for (i in 0..bytes.size) {
        unsafe { buffer.write(i, bytes[i]) }
    }
    buffer
}

internal func nullClipboardCString(): CString {
    CString(CPointer<UInt8>())
}

internal func freeClipboardCString(value: CString): Unit {
    if (!value.isNull()) {
        unsafe { LibC.free(value) }
    }
}

internal func freeClipboardCStringArray(values: Array<CString>): Unit {
    for (value in values) {
        freeClipboardCString(value)
    }
}
