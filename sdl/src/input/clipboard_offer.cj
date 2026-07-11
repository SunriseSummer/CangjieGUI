/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.input

import std.collection.concurrent.ConcurrentHashMap
import std.sync.AtomicInt64

private let CLIPBOARD_NEXT_ID = AtomicInt64(1)
private let CLIPBOARD_OFFERS = ConcurrentHashMap<Int64, ClipboardOffer>(concurrencyLevel: 8)

internal class ClipboardOffer {
    internal let id: Int64
    internal let idPtr: CPointer<Int64>
    internal let rawMimeTypes: CPointer<CPointer<UInt8>>
    internal let mimeTypeStrings: Array<CString>
    internal let mimeTypes: Array<String>
    internal let buffers: Array<CPointer<UInt8>>
    internal let sizes: Array<UIntNative>
    private var closed = false

    init(
        id: Int64,
        idPtr: CPointer<Int64>,
        rawMimeTypes: CPointer<CPointer<UInt8>>,
        mimeTypeStrings: Array<CString>,
        mimeTypes: Array<String>,
        buffers: Array<CPointer<UInt8>>,
        sizes: Array<UIntNative>
    ) {
        this.id = id
        this.idPtr = idPtr
        this.rawMimeTypes = rawMimeTypes
        this.mimeTypeStrings = mimeTypeStrings
        this.mimeTypes = mimeTypes
        this.buffers = buffers
        this.sizes = sizes
    }

    func userdata(): CPointer<Unit> {
        CPointer<Unit>(idPtr)
    }

    func mimeCount(): Int64 {
        mimeTypes.size
    }

    func dataFor(mimeType: CPointer<UInt8>, size: CPointer<UIntNative>): CPointer<Unit> {
        if (mimeType.isNull() || size.isNull()) {
            return CPointer<Unit>()
        }
        let requested = CString(mimeType).toString()
        for (i in 0..mimeTypes.size) {
            if (mimeTypes[i] == requested) {
                unsafe { size.write(sizes[i]) }
                return CPointer<Unit>(buffers[i])
            }
        }
        unsafe { size.write(UIntNative(0)) }
        CPointer<Unit>()
    }

    func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        for (buffer in buffers) {
            if (buffer.isNotNull()) {
                unsafe { LibC.free(buffer) }
            }
        }
        freeClipboardCStringArray(mimeTypeStrings)
        unsafe {
            if (rawMimeTypes.isNotNull()) {
                LibC.free(rawMimeTypes)
            }
            if (idPtr.isNotNull()) {
                LibC.free(idPtr)
            }
        }
    }
}

internal func createClipboardOffer(items: Array<ClipboardData>): ClipboardOffer {
    let id = CLIPBOARD_NEXT_ID.fetchAdd(1)
    let idPtr = unsafe { LibC.malloc<Int64>() }
    let rawMimeTypes = unsafe { LibC.malloc<CPointer<UInt8>>(count: items.size) }
    let mimeTypeStrings = Array<CString>(items.size, {_ => nullClipboardCString()})
    let mimeTypes = Array<String>(items.size, {i => items[i].mimeType})
    let buffers = Array<CPointer<UInt8>>(items.size, {i => copyClipboardBytesToNative(items[i].bytes)})
    let sizes = Array<UIntNative>(items.size, {i => UIntNative(items[i].bytes.size)})

    try {
        unsafe { idPtr.write(id) }
        for (i in 0..items.size) {
            mimeTypeStrings[i] = unsafe { LibC.mallocCString(items[i].mimeType) }
            unsafe { rawMimeTypes.write(i, mimeTypeStrings[i].getChars()) }
        }
        ClipboardOffer(id, idPtr, rawMimeTypes, mimeTypeStrings, mimeTypes, buffers, sizes)
    } catch (e: Exception) {
        freeClipboardOfferParts(idPtr, rawMimeTypes, mimeTypeStrings, buffers)
        throw e
    }
}

internal func registerClipboardOffer(offer: ClipboardOffer): Unit {
    match (CLIPBOARD_OFFERS.add(offer.id, offer)) {
        case Some(oldOffer) => oldOffer.close()
        case None => ()
    }
}

internal func unregisterClipboardOffer(id: Int64): Unit {
    let _ = CLIPBOARD_OFFERS.remove(id)
}

@C
func cuiClipboardDataCallback(
    userdata: CPointer<Unit>,
    mimeType: CPointer<UInt8>,
    size: CPointer<UIntNative>
): CPointer<Unit> {
    if (userdata.isNull()) {
        return CPointer<Unit>()
    }
    let id = unsafe { CPointer<Int64>(userdata).read() }
    match (CLIPBOARD_OFFERS.get(id)) {
        case Some(offer) => offer.dataFor(mimeType, size)
        case None => CPointer<Unit>()
    }
}

@C
func cuiClipboardCleanupCallback(userdata: CPointer<Unit>): Unit {
    if (userdata.isNull()) {
        return
    }
    let id = unsafe { CPointer<Int64>(userdata).read() }
    match (CLIPBOARD_OFFERS.remove(id)) {
        case Some(offer) => offer.close()
        case None => ()
    }
}

private func freeClipboardOfferParts(
    idPtr: CPointer<Int64>,
    rawMimeTypes: CPointer<CPointer<UInt8>>,
    mimeTypeStrings: Array<CString>,
    buffers: Array<CPointer<UInt8>>
): Unit {
    for (buffer in buffers) {
        if (buffer.isNotNull()) {
            unsafe { LibC.free(buffer) }
        }
    }
    freeClipboardCStringArray(mimeTypeStrings)
    unsafe {
        if (rawMimeTypes.isNotNull()) {
            LibC.free(rawMimeTypes)
        }
        if (idPtr.isNotNull()) {
            LibC.free(idPtr)
        }
    }
}
