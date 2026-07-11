/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.dialogs

import std.sync.Mutex
import sdl.{SdlDialogFileFilter}

public enum FileDialogResult {
    | FileDialogPending
    | FileDialogCanceled
    | FileDialogSelected(Array<String>, ?Int32)
    | FileDialogFailed(String)
}

public struct FileDialogFilter {
    public let name: String
    public let pattern: String

    public init(name: String, pattern: String) {
        this.name = name
        this.pattern = pattern
    }
}

public struct FileDialogOptions {
    public var filters: Array<FileDialogFilter>
    public var defaultLocation: ?String
    public var allowMany: Bool

    public init(
        filters!: Array<FileDialogFilter> = [],
        defaultLocation!: ?String = None,
        allowMany!: Bool = false
    ) {
        this.filters = filters
        this.defaultLocation = defaultLocation
        this.allowMany = allowMany
    }
}

public class FileDialogRequest {
    private let lock = Mutex()
    private var current = FileDialogResult.FileDialogPending
    private var nativeResources: ?FileDialogNativeResources
    internal let id: Int64

    internal init(id: Int64, nativeResources: FileDialogNativeResources) {
        this.id = id
        this.nativeResources = Some(nativeResources)
    }

    public func result(): FileDialogResult {
        var value = FileDialogResult.FileDialogPending
        synchronized(lock) {
            value = current
        }
        value
    }

    public func isDone(): Bool {
        match (result()) {
            case FileDialogResult.FileDialogPending => false
            case _ => true
        }
    }

    internal func complete(value: FileDialogResult): Unit {
        synchronized(lock) {
            current = value
        }
    }

    internal func userdata(): CPointer<Unit> {
        match (nativeResources) {
            case Some(resources) => resources.userdata()
            case None => CPointer<Unit>()
        }
    }

    internal func rawFilters(): CPointer<SdlDialogFileFilter> {
        match (nativeResources) {
            case Some(resources) => resources.rawFilters
            case None => CPointer<SdlDialogFileFilter>()
        }
    }

    internal func filterCount(): Int32 {
        match (nativeResources) {
            case Some(resources) => resources.filterCount
            case None => 0
        }
    }

    internal func defaultLocation(): CString {
        match (nativeResources) {
            case Some(resources) => resources.defaultLocation
            case None => nullDialogCString()
        }
    }

    internal func releaseNativeResources(): Unit {
        match (nativeResources) {
            case Some(resources) =>
                resources.close()
                nativeResources = None<FileDialogNativeResources>
            case None => ()
        }
    }
}
