package cui.text

import cui.core.clampScrollOffset

internal func textAreaVisibleScroll(row: Int64, previous: Float32, rowHeight: Float32, viewportHeight: Float32,
    contentHeight: Float32): Float32 {
    if (viewportHeight <= 0.0) {
        return previous
    }
    let top = Float32(row) * rowHeight
    var scroll = previous
    if (top < scroll) {
        scroll = top
    } else if (top + rowHeight > scroll + viewportHeight) {
        scroll = top + rowHeight - viewportHeight
    }
    clampScrollOffset(scroll, contentHeight, viewportHeight)
}
