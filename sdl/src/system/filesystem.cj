/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import std.collection.ArrayList
import sdl.{CuiException, ensureSdl, lastSdlError, SDL_GLOB_CASEINSENSITIVE, SDL_PATHTYPE_DIRECTORY, SDL_PATHTYPE_FILE, 
    SDL_PATHTYPE_NONE, SDL_PATHTYPE_OTHER, SdlPathInfo}

public enum FileSystemEntryType {
    | Missing
    | File
    | Directory
    | Other
}

public struct PathInfo {
    public let entryType: FileSystemEntryType
    public let size: UInt64
    public let createTime: Int64
    public let modifyTime: Int64
    public let accessTime: Int64

    public init(
        entryType: FileSystemEntryType,
        size: UInt64,
        createTime: Int64,
        modifyTime: Int64,
        accessTime: Int64
    ) {
        this.entryType = entryType
        this.size = size
        this.createTime = createTime
        this.modifyTime = modifyTime
        this.accessTime = accessTime
    }
}

public class FileSystem {
    /**
     * Throws `CuiException` when the path is empty or SDL cannot create the directory tree.
     */
    public static func createDirectory(path: String): Unit {
        ensurePathValue(path, "Path")
        let cPath = unsafe { LibC.mallocCString(path) }
        try (pathResource = cPath.asResource()) {
            ensureSdl(unsafe { SDL_CreateDirectory(pathResource.value) }, "SDL_CreateDirectory")
        }
    }

    /**
     * Throws `CuiException` when the path is empty or SDL cannot remove the file or empty directory.
     */
    public static func remove(path: String): Unit {
        ensurePathValue(path, "Path")
        let cPath = unsafe { LibC.mallocCString(path) }
        try (pathResource = cPath.asResource()) {
            ensureSdl(unsafe { SDL_RemovePath(pathResource.value) }, "SDL_RemovePath")
        }
    }

    /**
     * Throws `CuiException` when either path is empty or SDL cannot rename the file or directory.
     */
    public static func rename(oldPath: String, newPath: String): Unit {
        ensurePathValue(oldPath, "Old path")
        ensurePathValue(newPath, "New path")
        let cOldPath = unsafe { LibC.mallocCString(oldPath) }
        let cNewPath = unsafe { LibC.mallocCString(newPath) }
        try (oldPathResource = cOldPath.asResource()) {
            try (newPathResource = cNewPath.asResource()) {
                ensureSdl(unsafe { SDL_RenamePath(oldPathResource.value, newPathResource.value) }, "SDL_RenamePath")
            }
        }
    }

    /**
     * Throws `CuiException` when either path is empty or SDL cannot copy the source file.
     */
    public static func copyFile(source: String, destination: String): Unit {
        ensurePathValue(source, "Source path")
        ensurePathValue(destination, "Destination path")
        let cSource = unsafe { LibC.mallocCString(source) }
        let cDestination = unsafe { LibC.mallocCString(destination) }
        try (sourceResource = cSource.asResource()) {
            try (destinationResource = cDestination.asResource()) {
                ensureSdl(unsafe { SDL_CopyFile(sourceResource.value, destinationResource.value) }, "SDL_CopyFile")
            }
        }
    }

    /**
     * Throws `CuiException` when the path is empty.
     */
    public static func pathInfo(path: String): ?PathInfo {
        ensurePathValue(path, "Path")
        let cPath = unsafe { LibC.mallocCString(path) }
        var raw = SdlPathInfo()
        var found = false
        try (pathResource = cPath.asResource()) {
            found = unsafe { SDL_GetPathInfo(pathResource.value, inout raw) }
        }
        if (!found) {
            return None
        }
        Some(PathInfo(entryTypeFromCode(raw.pathType), raw.size, raw.createTime, raw.modifyTime, raw.accessTime))
    }

    /**
     * Throws `CuiException` when the path is empty.
     */
    public static func exists(path: String): Bool {
        match (pathInfo(path)) {
            case Some(_) => true
            case None => false
        }
    }

    /**
     * Throws `CuiException` when the path is empty or SDL cannot enumerate the directory.
     */
    public static func globDirectory(
        path: String,
        pattern!: ?String = None,
        caseInsensitive!: Bool = false
    ): Array<String> {
        ensurePathValue(path, "Path")
        let cPath = unsafe { LibC.mallocCString(path) }
        let flags = globFlags(caseInsensitive)
        var results: Array<String> = []
        try (pathResource = cPath.asResource()) {
            match (pattern) {
                case Some(value) =>
                    let cPattern = unsafe { LibC.mallocCString(value) }
                    try (patternResource = cPattern.asResource()) {
                        results = globDirectoryRaw(pathResource.value, patternResource.value, flags)
                    }
                case None => results = globDirectoryRaw(pathResource.value, nullCString(), flags)
            }
        }
        results
    }
}

internal func entryTypeFromCode(code: Int32): FileSystemEntryType {
    if (code == SDL_PATHTYPE_NONE) {
        FileSystemEntryType.Missing
    } else if (code == SDL_PATHTYPE_FILE) {
        FileSystemEntryType.File
    } else if (code == SDL_PATHTYPE_DIRECTORY) {
        FileSystemEntryType.Directory
    } else if (code == SDL_PATHTYPE_OTHER) {
        FileSystemEntryType.Other
    } else {
        FileSystemEntryType.Missing
    }
}

internal func globFlags(caseInsensitive: Bool): UInt32 {
    if (caseInsensitive) {
        SDL_GLOB_CASEINSENSITIVE
    } else {
        UInt32(0)
    }
}

/**
 * Throws `CuiException` when SDL cannot enumerate the directory.
 */
private func globDirectoryRaw(path: CString, pattern: CString, flags: UInt32): Array<String> {
    var count: Int32 = 0
    let entries = unsafe { SDL_GlobDirectory(path, pattern, flags, inout count) }
    if (entries.isNull()) {
        throw CuiException("SDL_GlobDirectory failed: ${lastSdlError()}")
    }

    try {
        let results = ArrayList<String>()
        for (i in 0..Int64(count)) {
            let entry = unsafe { entries.read(i) }
            if (entry.isNotNull()) {
                results.add(CString(entry).toString())
            }
        }
        results.toArray()
    } finally {
        unsafe { SDL_free(CPointer<UInt8>(entries)) }
    }
}

private func nullCString(): CString {
    CString(CPointer<UInt8>())
}

/**
 * Throws `CuiException` when a filesystem path argument is empty.
 */
private func ensurePathValue(value: String, name: String): Unit {
    if (value.size <= 0) {
        throw CuiException("${name} cannot be empty.")
    }
}
