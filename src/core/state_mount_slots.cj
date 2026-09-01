package cui.core

import std.collection.ArrayList

/* Tagged positional product shared by remembered values and lifecycle declarations. */
enum ImplicitSlotKind {
    | RememberedValue
    | MountEffect
    | LifecycleEffect
}

class ImplicitSlotShape {
    let paths: Array<String>
    let kinds: Array<ImplicitSlotKind>

    init(paths: Array<String>, kinds: Array<ImplicitSlotKind>) {
        this.paths = paths
        this.kinds = kinds
    }
}

class ImplicitSlotCursor {
    let namespace: String
    private let committed: ?ImplicitSlotShape
    private var stagedPaths: ?ArrayList<String> = None
    private var stagedKinds: ?ArrayList<ImplicitSlotKind> = None
    var count: Int64

    init(namespace: String, committed: ?ImplicitSlotShape) {
        this.namespace = namespace
        this.committed = committed
        this.count = 0
    }

    func claimPath(kind: ImplicitSlotKind): String {
        let slot = count
        match (committed) {
            case Some(shape) where slot < shape.paths.size =>
                if (!sameImplicitSlotKind(shape.kinds[slot], kind)) {
                    throw IllegalStateException(
                        "Keyless declaration slot #${slot + 1} changed kind from ${implicitSlotKindName(shape.kinds[slot])} to ${implicitSlotKindName(kind)}")
                }
                count += 1
                shape.paths[slot]
            case _ =>
                count += 1
                let path = implicitSlotPath(namespace, slot)
                match (stagedPaths) {
                    case Some(paths) => paths.add(path)
                    case None =>
                        let paths = ArrayList<String>()
                        paths.add(path)
                        stagedPaths = Some(paths)
                }
                match (stagedKinds) {
                    case Some(kinds) => kinds.add(kind)
                    case None =>
                        let kinds = ArrayList<ImplicitSlotKind>()
                        kinds.add(kind)
                        stagedKinds = Some(kinds)
                }
                path
        }
    }

    func committedShape(): ImplicitSlotShape {
        match (committed) {
            case Some(shape) where shape.paths.size == count => shape
            case _ =>
                let paths: Array<String> = match (stagedPaths) {
                    case Some(current) => current.toArray()
                    case None => []
                }
                let kinds: Array<ImplicitSlotKind> = match (stagedKinds) {
                    case Some(current) => current.toArray()
                    case None => []
                }
                ImplicitSlotShape(paths, kinds)
        }
    }
}

private func implicitSlotKindName(kind: ImplicitSlotKind): String {
    match (kind) {
        case ImplicitSlotKind.RememberedValue => "remembered value"
        case ImplicitSlotKind.MountEffect => "mount effect"
        case ImplicitSlotKind.LifecycleEffect => "revisioned lifecycle effect"
    }
}

private func sameImplicitSlotKind(left: ImplicitSlotKind, right: ImplicitSlotKind): Bool {
    implicitSlotKindTag(left) == implicitSlotKindTag(right)
}

private func implicitSlotKindTag(kind: ImplicitSlotKind): Int64 {
    match (kind) {
        case ImplicitSlotKind.RememberedValue => 0
        case ImplicitSlotKind.MountEffect => 1
        case ImplicitSlotKind.LifecycleEffect => 2
    }
}

private func implicitSlotPath(namespace: String, slot: Int64): String {
    let slotKey = "${slot}"
    let result = StringBuilder()
    result.append(namespace)
    result.append(slotKey.size)
    result.append(":")
    result.append(slotKey)
    result.append(";")
    result.toString()
}
