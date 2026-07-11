/*
 * Copyright (c) 2026. CangjieGUI contributors. All rights reserved.
 */
package sdl.system

import std.fs.File
import std.fs.Path
import sdl.{CuiException, SDL_GLOB_CASEINSENSITIVE, SDL_PATHTYPE_DIRECTORY, SDL_PATHTYPE_FILE, SDL_PATHTYPE_NONE, 
    SDL_PATHTYPE_OTHER}

@Test
func entryTypeFromCodeMapsSdlValues(): Unit {
    expectMissingEntry(entryTypeFromCode(SDL_PATHTYPE_NONE))
    expectFileEntry(entryTypeFromCode(SDL_PATHTYPE_FILE))
    expectDirectoryEntry(entryTypeFromCode(SDL_PATHTYPE_DIRECTORY))
    expectOtherEntry(entryTypeFromCode(SDL_PATHTYPE_OTHER))
    expectMissingEntry(entryTypeFromCode(99))
}

@Test
func globFlagsMapCaseInsensitiveOption(): Unit {
    @Expect(globFlags(false), UInt32(0))
    @Expect(globFlags(true), SDL_GLOB_CASEINSENSITIVE)
}

@Test
func filesystemRejectsEmptyPaths(): Unit {
    @Expect(filesystemPathInfoFails(""))
    @Expect(filesystemCreateDirectoryFails(""))
    @Expect(filesystemGlobDirectoryFails(""))
}

@Test
func pathInfoReportsCurrentDirectory(): Unit {
    let path = ApplicationPaths.currentDirectory()

    match (FileSystem.pathInfo(path)) {
        case Some(info) => expectDirectoryEntry(info.entryType)
        case None => @Fail("Current directory should have path info.")
    }
}

@Test
func globDirectoryFiltersDirectoryEntries(): Unit {
    let dir = globFixtureDirectory()
    cleanupGlobFixture(dir)
    FileSystem.createDirectory(dir)
    File.writeTo(Path(fixturePath(dir, "alpha.txt")), "alpha".toArray())
    File.writeTo(Path(fixturePath(dir, "notes.md")), "notes".toArray())
    File.writeTo(Path(fixturePath(dir, "REPORT.TXT")), "report".toArray())

    try {
        let textFiles = FileSystem.globDirectory(dir, pattern: Some("*.txt"), caseInsensitive: true)
        @Expect(containsEntry(textFiles, "alpha.txt"))
        @Expect(containsEntry(textFiles, "REPORT.TXT"))
        @Expect(!containsEntry(textFiles, "notes.md"))

        let allFiles = FileSystem.globDirectory(dir)
        @Expect(containsEntry(allFiles, "alpha.txt"))
        @Expect(containsEntry(allFiles, "notes.md"))
    } finally {
        cleanupGlobFixture(dir)
    }
}

private func expectMissingEntry(entryType: FileSystemEntryType): Unit {
    match (entryType) {
        case FileSystemEntryType.Missing => @Expect(true)
        case _ => @Fail("Path type should map to Missing.")
    }
}

private func expectFileEntry(entryType: FileSystemEntryType): Unit {
    match (entryType) {
        case FileSystemEntryType.File => @Expect(true)
        case _ => @Fail("Path type should map to File.")
    }
}

private func expectDirectoryEntry(entryType: FileSystemEntryType): Unit {
    match (entryType) {
        case FileSystemEntryType.Directory => @Expect(true)
        case _ => @Fail("Path type should map to Directory.")
    }
}

private func expectOtherEntry(entryType: FileSystemEntryType): Unit {
    match (entryType) {
        case FileSystemEntryType.Other => @Expect(true)
        case _ => @Fail("Path type should map to Other.")
    }
}

private func containsEntry(entries: Array<String>, fileName: String): Bool {
    for (entry in entries) {
        if (entry == fileName || entry.endsWith("/" + fileName) || entry.endsWith("\\" + fileName)) {
            return true
        }
    }
    false
}

private func filesystemPathInfoFails(path: String): Bool {
    try {
        let _ = FileSystem.pathInfo(path)
        false
    } catch (e: CuiException) {
        true
    }
}

private func filesystemCreateDirectoryFails(path: String): Bool {
    try {
        FileSystem.createDirectory(path)
        false
    } catch (e: CuiException) {
        true
    }
}

private func filesystemGlobDirectoryFails(path: String): Bool {
    try {
        let _ = FileSystem.globDirectory(path)
        false
    } catch (e: CuiException) {
        true
    }
}

private func globFixtureDirectory(): String {
    ApplicationPaths.preferencePath("CUI", "FilesystemTests") + "glob"
}

private func fixturePath(dir: String, fileName: String): String {
    dir + "/" + fileName
}

private func cleanupGlobFixture(dir: String): Unit {
    removeFixturePath(fixturePath(dir, "alpha.txt"))
    removeFixturePath(fixturePath(dir, "notes.md"))
    removeFixturePath(fixturePath(dir, "REPORT.TXT"))
    removeFixturePath(dir)
}

private func removeFixturePath(path: String): Unit {
    try {
        if (FileSystem.exists(path)) {
            FileSystem.remove(path)
        }
    } catch (e: CuiException) {
        ()
    }
}
