/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.input

import sdl.{CuiException}

internal let CLIPBOARD_MAX_MIME_TYPES: Int64 = 64

/**
 * Throws `CuiException` when clipboard data cannot be safely offered to SDL.
 */
internal func ensureClipboardDataItems(items: Array<ClipboardData>): Unit {
    if (items.size <= 0) {
        throw CuiException("Clipboard data must include at least one MIME item.")
    }
    if (items.size > CLIPBOARD_MAX_MIME_TYPES) {
        throw CuiException("Clipboard data cannot include more than ${CLIPBOARD_MAX_MIME_TYPES} MIME items.")
    }
    for (i in 0..items.size) {
        ensureClipboardMimeType(items[i].mimeType)
        ensureClipboardMimeTypeUnique(items, i)
    }
}

/**
 * Throws `CuiException` when a MIME type is empty or contains unsafe control bytes.
 */
internal func ensureClipboardMimeType(mimeType: String): Unit {
    if (mimeType.size <= 0) {
        throw CuiException("Clipboard MIME type cannot be empty.")
    }
    for (byte in mimeType) {
        if (!isClipboardMimeTypeByte(byte)) {
            throw CuiException("Clipboard MIME type contains an invalid byte.")
        }
    }
}

/**
 * Throws `CuiException` when the current item repeats an earlier MIME type.
 */
private func ensureClipboardMimeTypeUnique(items: Array<ClipboardData>, index: Int64): Unit {
    let mimeType = items[index].mimeType
    for (i in 0..index) {
        if (items[i].mimeType == mimeType) {
            throw CuiException("Clipboard MIME types must be unique.")
        }
    }
}

private func isClipboardMimeTypeByte(byte: UInt8): Bool {
    byte > UInt8(32) && byte < UInt8(127)
}
