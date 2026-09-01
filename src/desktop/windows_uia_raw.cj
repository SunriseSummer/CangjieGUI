package cui.desktop

import std.collection.{ArrayList, HashMap}
import sdl.SdlWindow
import sdl.system.ApplicationPaths
import cui.core.{AccessibilityUpdate, SemanticsAction}

private let UIA_API_CREATE_INDEX: Int64 = 3
private let UIA_API_UPDATE_INDEX: Int64 = 4
private let UIA_API_NEXT_ACTION_SIZE_INDEX: Int64 = 5
private let UIA_API_POP_ACTION_INDEX: Int64 = 6
private let UIA_API_COMPLETE_ACTION_INDEX: Int64 = 7
private let UIA_API_REVISION_INDEX: Int64 = 8
private let UIA_API_NODE_COUNT_INDEX: Int64 = 9
private let UIA_API_CLOSE_INDEX: Int64 = 10
private let UIA_ACTION_KIND_ACTIVATE: Int32 = 1
private let UIA_ACTION_KIND_FOCUS: Int32 = 2
private let UIA_ACTION_KIND_INCREMENT: Int32 = 3
private let UIA_ACTION_KIND_DECREMENT: Int32 = 4
private let UIA_ACTION_KIND_SET_VALUE: Int32 = 5

foreign {
    func SDL_LoadObject(path: CString): CPointer<Unit>

    func SDL_LoadFunction(handle: CPointer<Unit>, name: CString): CPointer<Unit>

    func SDL_UnloadObject(handle: CPointer<Unit>): Unit
}

@When[os == "Windows"]
class WindowsUiaApi {
    private let library: CPointer<Unit>
    private let createPointer: CPointer<Unit>
    private let updatePointer: CPointer<Unit>
    private let nextActionValueSizePointer: CPointer<Unit>
    private let popActionPointer: CPointer<Unit>
    private let completeActionPointer: CPointer<Unit>
    private let revisionPointer: CPointer<Unit>
    private let nodeCountPointer: CPointer<Unit>
    private let closePointer: CPointer<Unit>

    init(library: CPointer<Unit>, functions: Array<CPointer<Unit>>) {
        this.library = library
        createPointer = functions[UIA_API_CREATE_INDEX]
        updatePointer = functions[UIA_API_UPDATE_INDEX]
        nextActionValueSizePointer = functions[UIA_API_NEXT_ACTION_SIZE_INDEX]
        popActionPointer = functions[UIA_API_POP_ACTION_INDEX]
        completeActionPointer = functions[UIA_API_COMPLETE_ACTION_INDEX]
        revisionPointer = functions[UIA_API_REVISION_INDEX]
        nodeCountPointer = functions[UIA_API_NODE_COUNT_INDEX]
        closePointer = functions[UIA_API_CLOSE_INDEX]
    }

    func create(windowId: UInt32): CPointer<Unit> {
        unsafe { CFunc<(UInt32) -> CPointer<Unit>>(createPointer)(windowId) }
    }

    func update( // cjcheck-ignore: param-count # method mirrors the stable C ABI; an object would not cross CFunc
        bridge: CPointer<Unit>,
        revision: UInt64,
        viewportWidth: Float64,
        viewportHeight: Float64,
        focusedToken: UInt64,
        strings: CPointer<UInt8>,
        stringByteCount: Int64,
        nodes: CPointer<CuiUiaNode>,
        nodeCount: Int64,
        changes: CPointer<CuiUiaChange>,
        changeCount: Int64
    ): Int32 {
        unsafe {
            CFunc<(CPointer<Unit>, UInt64, Float64, Float64, UInt64, CPointer<UInt8>, Int64, CPointer<CuiUiaNode>, Int64,
                    CPointer<CuiUiaChange>, Int64) -> Int32>(updatePointer)(bridge, revision, viewportWidth,
                viewportHeight, focusedToken, strings, stringByteCount, nodes, nodeCount, changes, changeCount)
        }
    }

    func nextActionValueSize(bridge: CPointer<Unit>): Int64 {
        unsafe { CFunc<(CPointer<Unit>) -> Int64>(nextActionValueSizePointer)(bridge) }
    }

    func popAction(
        bridge: CPointer<Unit>,
        value: CPointer<UInt8>,
        valueCapacity: Int64
    ): (Int32, UInt64, Int32) {
        var token = UInt64(0)
        var kind: Int32 = 0
        let popped = unsafe {
            CFunc<(CPointer<Unit>, CPointer<UInt64>, CPointer<Int32>, CPointer<UInt8>, Int64) -> Int32>(
                popActionPointer)(bridge, inout token, inout kind, value, valueCapacity)
        }
        (popped, token, kind)
    }

    func completeAction(bridge: CPointer<Unit>, token: UInt64, kind: Int32, succeeded: Int32): Unit {
        unsafe {
            CFunc<(CPointer<Unit>, UInt64, Int32, Int32) -> Unit>(completeActionPointer)(bridge, token, kind, succeeded)
        }
    }

    func revision(bridge: CPointer<Unit>): UInt64 {
        unsafe { CFunc<(CPointer<Unit>) -> UInt64>(revisionPointer)(bridge) }
    }

    func nodeCount(bridge: CPointer<Unit>): Int64 {
        unsafe { CFunc<(CPointer<Unit>) -> Int64>(nodeCountPointer)(bridge) }
    }

    func closeBridge(bridge: CPointer<Unit>): Unit {
        unsafe { CFunc<(CPointer<Unit>) -> Unit>(closePointer)(bridge) }
    }
}

@When[os == "Windows"]
class WindowsUiaBridge <: DesktopAccessibilityBridge {
    private let window: SdlWindow
    private let api: WindowsUiaApi
    private var bridge: CPointer<Unit>
    private let tokenById = HashMap<String, UInt64>()
    private let idByToken = HashMap<UInt64, String>()
    private var nextToken: UInt64 = UInt64(1)
    private var latestUpdate: ?AccessibilityUpdate = None
    private var closed = false

    init(window: SdlWindow, api: WindowsUiaApi, bridge: CPointer<Unit>) {
        this.window = window
        this.api = api
        this.bridge = bridge
    }

    /**
     * Publishes one semantic revision. Throws `IllegalStateException` when the bridge is closed or
     * the native provider rejects the revision; DesktopApp isolates that failure domain.
     */
    public func update(value: AccessibilityUpdate): Unit {
        ensureOpen("publish accessibility")
        let nodes = value.snapshot.nodes
        let stringArena = createStringArena(nodes)
        let nodeBuffer = nativeNodeBuffer(nodes.size)
        try {
            let changeBuffer = nativeChangeBuffer(value.changes.size)
            try {
                let removedIds = ArrayList<String>()
                writeNativeNodes(value, stringArena, nodeBuffer)
                writeNativeChanges(value, changeBuffer, removedIds)
                let focusedToken = existingToken(value.snapshot.focusedId)
                let revision = value.snapshot.revision
                let viewportWidth = Float64(window.width)
                let viewportHeight = Float64(window.height)
                let stringHandle = unsafe { acquireArrayRawData(stringArena.bytes) }
                let updated = try {
                    api.update(bridge, revision, viewportWidth, viewportHeight, focusedToken,
                        unsafe { stringHandle.pointer }, stringArena.bytes.size, nodeBuffer, nodes.size, changeBuffer,
                        value.changes.size)
                } finally {
                    unsafe { releaseArrayRawData(stringHandle) }
                }
                if (updated == 0) {
                    throw IllegalStateException("Windows UIA rejected accessibility revision ${revision}")
                }
                latestUpdate = Some(value)
                removeTokens(removedIds)
            } finally {
                freeNativeBuffer(changeBuffer)
            }
        } finally {
            freeNativeBuffer(nodeBuffer)
        }
    }

    /** Drains native COM requests onto the UI thread and dispatches them to the latest semantic action targets. */
    public func drainActions(): Unit {
        ensureOpen("drain accessibility actions")
        var valueSize = api.nextActionValueSize(bridge)
        while (valueSize >= 0) {
            let buffer = nativeByteBuffer(max(Int64(1), valueSize))
            try {
                let (popped, token, kind) = api.popAction(bridge, buffer, valueSize)
                if (popped == 0) {
                    return
                }
                dispatchAction(token, kind, CString(buffer).toString())
            } finally {
                unsafe { LibC.free(buffer) }
            }
            valueSize = api.nextActionValueSize(bridge)
        }
    }

    /** Disconnects the native provider and releases all bridge-owned semantic identities. */
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        latestUpdate = None
        tokenById.clear()
        idByToken.clear()
        if (bridge.isNotNull()) {
            api.closeBridge(bridge)
            bridge = CPointer<Unit>()
        }
    }

    /** Returns the revision published to the native snapshot for diagnostics and tests. */
    public func nativeRevision(): UInt64 {
        ensureOpen("inspect accessibility revision")
        api.revision(bridge)
    }

    /** Returns the native snapshot node count for diagnostics and tests. */
    public func nativeNodeCount(): Int64 {
        ensureOpen("inspect accessibility node count")
        api.nodeCount(bridge)
    }

    private func tokenFor(id: String): UInt64 {
        match (tokenById.get(id)) {
            case Some(token) => token
            case None =>
                let token = nextToken
                nextToken += UInt64(1)
                let _ = tokenById.add(id, token) // cjcheck-ignore: ignore-result # id was checked absent
                let _ = idByToken.add(token, id) // cjcheck-ignore: ignore-result # tokens are monotonic and never reused
                token
        }
    }

    private func existingToken(id: String): UInt64 {
        match (tokenById.get(id)) {
            case Some(token) => token
            case None => UInt64(0)
        }
    }

    private func writeNativeNodes(
        update: AccessibilityUpdate,
        strings: NativeStringArena,
        buffer: CPointer<CuiUiaNode>
    ): Unit {
        for (index in 0..update.snapshot.nodes.size) {
            let node = update.snapshot.nodes[index]
            let base = index * UIA_NODE_STRING_FIELD_COUNT
            var raw = CuiUiaNode()
            raw.token = tokenFor(node.id)
            raw.idOffset = strings.offsets[base]
            raw.labelOffset = strings.offsets[base + 1]
            raw.valueOffset = strings.offsets[base + 2]
            raw.hintOffset = strings.offsets[base + 3]
            raw.role = semanticRoleCode(node.properties.role)
            raw.enabled = if (node.properties.enabled) {
                1
            } else {
                0
            }
            raw.selected = optionalBoolCode(node.properties.selected)
            raw.checked = optionalBoolCode(node.properties.checked)
            raw.actionMask = semanticsActionMask(node.actions)
            raw.x = Float64(node.visibleBounds.x)
            raw.y = Float64(node.visibleBounds.y)
            raw.width = Float64(node.visibleBounds.w)
            raw.height = Float64(node.visibleBounds.h)
            raw.parentIndex = update.snapshot.parentIndexAt(index)
            unsafe { buffer.write(index, raw) }
        }
    }

    private func writeNativeChanges(
        update: AccessibilityUpdate,
        buffer: CPointer<CuiUiaChange>,
        removedIds: ArrayList<String>
    ): Unit {
        for (index in 0..update.changes.size) {
            let (id, kind) = nativeChange(update.changes[index])
            if (kind == UIA_CHANGE_REMOVED) {
                removedIds.add(id)
            }
            var raw = CuiUiaChange()
            raw.token = existingToken(id)
            raw.kind = kind
            unsafe { buffer.write(index, raw) }
        }
    }

    private func removeTokens(ids: ArrayList<String>): Unit {
        for (id in ids) {
            match (tokenById.remove(id)) {
                case Some(token) => let _ = idByToken.remove(token)
                case None => ()
            }
        }
    }

    private func dispatchAction(token: UInt64, kind: Int32, value: String): Unit {
        let id = match (idByToken.get(token)) {
            case Some(found) => found
            case None => return
        }
        let action: SemanticsAction = if (kind == UIA_ACTION_KIND_ACTIVATE) {
            SemanticsAction.Activate
        } else if (kind == UIA_ACTION_KIND_FOCUS) {
            SemanticsAction.Focus
        } else if (kind == UIA_ACTION_KIND_INCREMENT) {
            SemanticsAction.Increment
        } else if (kind == UIA_ACTION_KIND_DECREMENT) {
            SemanticsAction.Decrement
        } else if (kind == UIA_ACTION_KIND_SET_VALUE) {
            SemanticsAction.SetValue(value)
        } else {
            return
        }
        match (latestUpdate) {
            case Some(update) =>
                let succeeded = update.performAction(id, action)
                api.completeAction(bridge, token, kind, if (succeeded) {
                    1
                } else {
                    0
                })
            case None => ()
        }
    }

    /* Throws `IllegalStateException` when a native bridge operation follows `close`. */
    private func ensureOpen(operation: String): Unit {
        if (closed || bridge.isNull()) {
            throw IllegalStateException("Cannot ${operation} through a closed Windows UIA bridge")
        }
    }
}

@When[os == "Windows"]
func createDesktopAccessibilityBridge(window: SdlWindow): ?DesktopAccessibilityBridge {
    match (windowsUiaApi()) {
        case Some(api) =>
            let bridge = api.create(window.id)
            if (bridge.isNull()) {
                None
            } else {
                Some(WindowsUiaBridge(window, api, bridge))
            }
        case None => None
    }
}

@When[os == "Windows"]
private var cachedWindowsUiaApi: ?WindowsUiaApi = None // cjcheck-ignore: global-var # process-lifetime loaded module cache

@When[os == "Windows"]
private func windowsUiaApi(): ?WindowsUiaApi {
    match (cachedWindowsUiaApi) {
        case Some(api) => Some(api)
        case None =>
            let library = loadWindowsUiaLibrary()
            if (library.isNull()) {
                return None
            }
            let names = [
                "cui_uia_abi_version",
                "cui_uia_node_layout",
                "cui_uia_change_layout",
                "cui_uia_create",
                "cui_uia_update",
                "cui_uia_next_action_value_size",
                "cui_uia_pop_action",
                "cui_uia_complete_action",
                "cui_uia_revision",
                "cui_uia_node_count",
                "cui_uia_close"
            ]
            let functions = Array<CPointer<Unit>>(names.size, {_ => CPointer<Unit>()})
            for (index in 0..names.size) {
                functions[index] = loadWindowsUiaFunction(library, names[index])
                if (functions[index].isNull()) {
                    unsafe { SDL_UnloadObject(library) }
                    return None
                }
            }
            let version = callWindowsUiaAbiScalar(functions[0])
            let nodeLayout = callWindowsUiaAbiScalar(functions[1])
            let changeLayout = callWindowsUiaAbiScalar(functions[2])
            if (!windowsUiaAbiCompatible(version, nodeLayout, changeLayout)) {
                unsafe { SDL_UnloadObject(library) }
                return None
            }
            let api = WindowsUiaApi(library, functions)
            cachedWindowsUiaApi = Some(api)
            Some(api)
    }
}

@When[os == "Windows"]
private func callWindowsUiaAbiScalar(function: CPointer<Unit>): UInt64 {
    unsafe { CFunc<() -> UInt64>(function)() }
}

@When[os == "Windows"]
private func loadWindowsUiaLibrary(): CPointer<Unit> {
    let candidates = ArrayList<String>()
    match (ApplicationPaths.basePath()) {
        case Some(base) => candidates.add("${base}cui_uia.dll")
        case None => ()
    }
    candidates.add("target/native/windows/x86_64/cui_uia.dll")
    candidates.add("target/native/windows/arm64/cui_uia.dll")
    for (candidate in candidates) {
        let path = unsafe { LibC.mallocCString(candidate) }
        let library = try {
            unsafe { SDL_LoadObject(path) }
        } finally {
            unsafe { LibC.free(path) }
        }
        if (library.isNotNull()) {
            return library
        }
    }
    CPointer<Unit>()
}

@When[os == "Windows"]
private func loadWindowsUiaFunction(library: CPointer<Unit>, name: String): CPointer<Unit> {
    let symbol = unsafe { LibC.mallocCString(name) }
    try {
        unsafe { SDL_LoadFunction(library, symbol) }
    } finally {
        unsafe { LibC.free(symbol) }
    }
}
