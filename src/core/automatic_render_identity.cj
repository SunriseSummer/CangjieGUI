package cui.core

import sdl.{Rect, Size}

func sameWidget(left: Widget, right: Widget): Bool {
    if (let Some(leftObject) <- (left as Object)) {
        if (let Some(rightObject) <- (right as Object)) {
            return sameObjectReference(leftObject, rightObject)
        }
    }
    false
}

func sameObjectReference(left: Object, right: Object): Bool {
    refEq(left, right)
}

func sameAutomaticNode(left: AutomaticRenderNode, right: AutomaticRenderNode): Bool {
    refEq((left as Object).getOrThrow(), (right as Object).getOrThrow()) // cjcheck-ignore: unchecked-cast # both values are internal class instances
}

func sameAutomaticSize(left: Size, right: Size): Bool {
    left.w == right.w && left.h == right.h
}

func sameAutomaticRect(left: Rect, right: Rect): Bool {
    left.x == right.x && left.y == right.y && left.w == right.w && left.h == right.h
}
