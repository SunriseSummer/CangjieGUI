/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import std.sync.AtomicInt64
import sdl.{lastSdlError, SdlDialogFileFilter, SdlWindow}

internal let FILE_DIALOG_MAX_FILTERS: Int64 = 64
private let FILE_DIALOG_NEXT_ID = AtomicInt64(1)
private let FILE_DIALOG_REQUESTS = ConcurrentHashMap<Int64, FileDialogRequest>(concurrencyLevel: 8)

internal class FileDialogNativeResources {
    internal let idPtr: CPointer<Int64>
    internal let rawFilters: CPointer<SdlDialogFileFilter>
    internal let filterCount: Int32
    internal let filterNames: Array<CString>
    internal let filterPatterns: Array<CString>
    internal let defaultLocation: CString
    private var closed = false

    init(
        idPtr: CPointer<Int64>,
        rawFilters: CPointer<SdlDialogFileFilter>,
        filterCount: Int32,
        filterNames: Array<CString>,
        filterPatterns: Array<CString>,
        defaultLocation: CString
    ) {
        this.idPtr = idPtr
        this.rawFilters = rawFilters
        this.filterCount = filterCount
        this.filterNames = filterNames
        this.filterPatterns = filterPatterns
        this.defaultLocation = defaultLocation
    }

    func userdata(): CPointer<Unit> {
        CPointer<Unit>(idPtr)
    }

    func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        freeDialogCStringArray(filterNames)
        freeDialogCStringArray(filterPatterns)
        freeDialogCString(defaultLocation)
        unsafe {
            if (rawFilters.isNotNull()) {
                LibC.free(rawFilters)
            }
            if (idPtr.isNotNull()) {
                LibC.free(idPtr)
            }
        }
    }
}

internal func createFileDialogRequest(options: FileDialogOptions): FileDialogRequest {
    ensureFileDialogOptions(options)
    let id = FILE_DIALOG_NEXT_ID.fetchAdd(1)
    let resources = allocateFileDialogResources(id, options)
    let request = FileDialogRequest(id, resources)
    let _ = FILE_DIALOG_REQUESTS.add(id, request)
    request
}

internal func fileDialogWindow(window: ?SdlWindow): CPointer<Unit> {
    match (window) {
        case Some(parent) => parent.windowPtr
        case None => CPointer<Unit>()
    }
}

@C
func cuiFileDialogCallback(
    userdata: CPointer<Unit>,
    filelist: CPointer<CPointer<UInt8>>,
    filter: Int32
): Unit {
    if (userdata.isNull()) {
        return
    }
    let id = unsafe { CPointer<Int64>(userdata).read() }
    match (FILE_DIALOG_REQUESTS.remove(id)) {
        case Some(request) =>
            request.complete(fileDialogResultFromPointer(filelist, filter))
            request.releaseNativeResources()
        case None => ()
    }
}

internal func fileDialogResultFromPointer(filelist: CPointer<CPointer<UInt8>>, filter: Int32): FileDialogResult {
    if (filelist.isNull()) {
        return FileDialogResult.FileDialogFailed(lastSdlError())
    }
    let first = unsafe { filelist.read(0) }
    if (first.isNull()) {
        return FileDialogResult.FileDialogCanceled
    }
    FileDialogResult.FileDialogSelected(fileDialogPaths(filelist), selectedDialogFilter(filter))
}

internal func selectedDialogFilter(filter: Int32): ?Int32 {
    if (filter < 0) {
        None<Int32>
    } else {
        Some(filter)
    }
}

internal func fileDialogPaths(filelist: CPointer<CPointer<UInt8>>): Array<String> {
    let paths = ArrayList<String>()
    var i: Int64 = 0
    var path = unsafe { filelist.read(i) }
    while (path.isNotNull()) {
        paths.add(CString(path).toString())
        i += 1
        path = unsafe { filelist.read(i) }
    }
    paths.toArray()
}

internal func rawDialogFilter(name: CString, pattern: CString): SdlDialogFileFilter {
    var raw = SdlDialogFileFilter()
    raw.name = name
    raw.pattern = pattern
    raw
}
