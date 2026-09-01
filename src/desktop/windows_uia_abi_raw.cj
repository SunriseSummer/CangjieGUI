package cui.desktop

import cui.core.SemanticsNode

private let UIA_NATIVE_ABI_VERSION: UInt64 = UInt64(2)
let UIA_NODE_STRING_FIELD_COUNT: Int64 = 4
private let C_LAYOUT_ALIGN_SHIFT: UInt64 = UInt64(32)

/** C-compatible node snapshot shared with the native Windows UI Automation provider. */
@C
struct CuiUiaNode {
    var token: UInt64 = UInt64(0)
    var idOffset: Int64 = 0
    var labelOffset: Int64 = 0
    var valueOffset: Int64 = 0
    var hintOffset: Int64 = 0
    var role: Int32 = 0
    var enabled: Int32 = 0
    var selected: Int32 = -1
    var checked: Int32 = -1
    var actionMask: UInt32 = UInt32(0)
    var x: Float64 = 0.0
    var y: Float64 = 0.0
    var width: Float64 = 0.0
    var height: Float64 = 0.0
    var parentIndex: Int64 = -1
}

/** C-compatible semantic change shared with the native Windows UI Automation provider. */
@C
struct CuiUiaChange {
    var token: UInt64 = UInt64(0)
    var kind: Int32 = 0
}

@When[os == "Windows"]
func windowsUiaNodeLayout(): UInt64 {
    cTypeLayout<CuiUiaNode>()
}

@When[os == "Windows"]
func windowsUiaChangeLayout(): UInt64 {
    cTypeLayout<CuiUiaChange>()
}

@When[os == "Windows"]
func windowsUiaAbiCompatible(version: UInt64, nodeLayout: UInt64, changeLayout: UInt64): Bool {
    version == UIA_NATIVE_ABI_VERSION && nodeLayout == windowsUiaNodeLayout() && changeLayout == windowsUiaChangeLayout()
}

@When[os == "Windows"]
private func cTypeLayout<T>(): UInt64 where T <: CType {
    UInt64(sizeOf<T>()) | (UInt64(alignOf<T>()) << C_LAYOUT_ALIGN_SHIFT)
}

func nativeNodeBuffer(count: Int64): CPointer<CuiUiaNode> {
    if (count <= 0) {
        CPointer<CuiUiaNode>()
    } else {
        let buffer = unsafe { LibC.malloc<CuiUiaNode>(count: count) }
        if (buffer.isNull()) {
            throw IllegalStateException("Cannot allocate Windows UIA native node buffer")
        }
        buffer
    }
}

func nativeChangeBuffer(count: Int64): CPointer<CuiUiaChange> {
    if (count <= 0) {
        CPointer<CuiUiaChange>()
    } else {
        let buffer = unsafe { LibC.malloc<CuiUiaChange>(count: count) }
        if (buffer.isNull()) {
            throw IllegalStateException("Cannot allocate Windows UIA native change buffer")
        }
        buffer
    }
}

func nativeByteBuffer(count: Int64): CPointer<UInt8> {
    let buffer = unsafe { LibC.malloc<UInt8>(count: count) }
    if (buffer.isNull()) {
        throw IllegalStateException("Cannot allocate Windows UIA native action buffer")
    }
    buffer
}

func freeNativeBuffer<T>(buffer: CPointer<T>): Unit where T <: CType {
    if (buffer.isNotNull()) {
        unsafe { LibC.free(buffer) }
    }
}

class NativeStringArena {
    let bytes: Array<UInt8>
    let offsets: Array<Int64>

    init(bytes: Array<UInt8>, offsets: Array<Int64>) {
        this.bytes = bytes
        this.offsets = offsets
    }
}

func createStringArena(nodes: Array<SemanticsNode>): NativeStringArena {
    var byteCount: Int64 = 1
    for (node in nodes) {
        byteCount += node.id.size + node.properties.label.size + node.properties.value.size + node
            .properties
            .hint
            .size + UIA_NODE_STRING_FIELD_COUNT
    }
    let bytes = Array<UInt8>(byteCount, {_ => UInt8(0)})
    let offsets = Array<Int64>(nodes.size * UIA_NODE_STRING_FIELD_COUNT, {_ => Int64(0)})
    var offset: Int64 = 0
    for (index in 0..nodes.size) {
        let node = nodes[index]
        let base = index * UIA_NODE_STRING_FIELD_COUNT
        offsets[base] = offset
        offset = writeUtf8String(bytes, offset, node.id)
        offsets[base + 1] = offset
        offset = writeUtf8String(bytes, offset, node.properties.label)
        offsets[base + 2] = offset
        offset = writeUtf8String(bytes, offset, node.properties.value)
        offsets[base + 3] = offset
        offset = writeUtf8String(bytes, offset, node.properties.hint)
    }
    NativeStringArena(bytes, offsets)
}

private func writeUtf8String(bytes: Array<UInt8>, offset: Int64, value: String): Int64 {
    for (index in 0..value.size) {
        bytes[offset + index] = value[index]
    }
    let end = offset + value.size
    bytes[end] = UInt8(0)
    end + 1
}
