/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl

internal let SDL_FOLDER_HOME: Int32 = 0
internal let SDL_FOLDER_DESKTOP: Int32 = 1
internal let SDL_FOLDER_DOCUMENTS: Int32 = 2
internal let SDL_FOLDER_DOWNLOADS: Int32 = 3
internal let SDL_FOLDER_MUSIC: Int32 = 4
internal let SDL_FOLDER_PICTURES: Int32 = 5
internal let SDL_FOLDER_PUBLICSHARE: Int32 = 6
internal let SDL_FOLDER_SAVEDGAMES: Int32 = 7
internal let SDL_FOLDER_SCREENSHOTS: Int32 = 8
internal let SDL_FOLDER_TEMPLATES: Int32 = 9
internal let SDL_FOLDER_VIDEOS: Int32 = 10
internal let SDL_PATHTYPE_NONE: Int32 = 0
internal let SDL_PATHTYPE_FILE: Int32 = 1
internal let SDL_PATHTYPE_DIRECTORY: Int32 = 2
internal let SDL_PATHTYPE_OTHER: Int32 = 3
internal let SDL_GLOB_CASEINSENSITIVE: UInt32 = UInt32(0x00000001)

@C
internal struct SdlPathInfo {
    var pathType: Int32 = 0
    var size: UInt64 = 0
    var createTime: Int64 = 0
    var modifyTime: Int64 = 0
    var accessTime: Int64 = 0
}

foreign {
    func SDL_GetBasePath(): CString

    func SDL_GetPrefPath(org: CString, app: CString): CString

    func SDL_GetUserFolder(folder: Int32): CString

    func SDL_GetCurrentDirectory(): CString

    func SDL_CreateDirectory(path: CString): Bool

    func SDL_RemovePath(path: CString): Bool

    func SDL_RenamePath(oldpath: CString, newpath: CString): Bool

    func SDL_CopyFile(oldpath: CString, newpath: CString): Bool

    func SDL_GetPathInfo(path: CString, info: CPointer<SdlPathInfo>): Bool

    func SDL_GlobDirectory(
        path: CString,
        pattern: CString,
        flags: UInt32,
        count: CPointer<Int32>
    ): CPointer<CPointer<UInt8>>
}
