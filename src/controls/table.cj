package cui.controls

import sdl.{Color, FontSizes, Key, MouseButton, Pen, Rect, Size, UiEvent}
import cui.core.{Bindable, CUI_SMALL_H, ScrollBar, State, UiContext, Widget, requireControlId, clampScrollOffset, drawSurface,
    drawVerticalScrollBar, emit, localState, registerFocusable, scrollLineIndex, scrollLineRemainder,
    scrollOffsetAfterWheel}

private let TABLE_HEADER_H: Float32 = 32.0
private let TABLE_CELL_PAD: Float32 = 10.0

/*
 * One column of a `Table`: a header title, a fixed pixel width, and whether its cells hold
 * numbers. Numeric columns are right-aligned and sort by numeric value rather than lexically.
 *
 * `cell` optionally replaces the text rendering with a custom painter — progress bars, colour
 * chips, badges. It receives the original row index, the cell's string value, and the cell
 * rectangle, and owns those pixels (the table has already painted the row background/selection
 * and clips the painter to the cell). Sorting still uses the string value under the column's
 * `numeric` rule, so what a cell shows and what it sorts by stay decoupled: "87%" can render as
 * a bar yet sort as 87. Painters draw only — cells receive no events; the row click still
 * selects, like every other cell.
 */
public class TableColumn {
    let title: String
    let width: Float32
    let numeric: Bool
    let cell: ?(UiContext, Int64, String, Rect) -> Unit

    public init(
        title: String,
        width: Float32,
        numeric!: Bool = false,
        cell!: ?(UiContext, Int64, String, Rect) -> Unit = None
    ) {
        this.title = title
        this.width = width
        this.numeric = numeric
        this.cell = cell
    }
}

/*
 * A typed column for `Table.of`: header, width, numeric flag, and a `value` extractor that produces
 * the cell string from a row of type `T` (used for both display and sorting, under the numeric rule).
 * `cell` optionally paints the cell instead of drawing the string, exactly as `TableColumn.cell` —
 * so a value can sort as a number yet render as a bar, with the source data staying typed.
 */
public class DataColumn<T> {
    let title: String
    let width: Float32
    let numeric: Bool
    let value: (T) -> String
    let cell: ?(UiContext, Int64, String, Rect) -> Unit

    public init(
        title: String,
        width: Float32,
        numeric!: Bool = false,
        cell!: ?(UiContext, Int64, String, Rect) -> Unit = None,
        value!: (T) -> String
    ) {
        this.title = title
        this.width = width
        this.numeric = numeric
        this.value = value
        this.cell = cell
    }
}

/*
 * A multi-column, sortable data table. Rows are `Array<String>` cells indexed by column. The
 * header stays fixed while the body scrolls; only visible rows are drawn (windowed), so a long
 * table stays cheap. Clicking a header sorts by that column (click again to reverse); the
 * selection is stored as an original row index, so it follows its row across re-sorts. Keyboard
 * Up/Down/Home/End move the selection when the table holds focus, scrolling it into view.
 * A column can replace its text rendering with a custom painter (`TableColumn.cell`) for
 * progress bars, badges and the like, without changing how the column sorts.
 *
 * Sorting is a stable merge sort that still reflects live cell values, but the computed order is
 * cached and reused across frames: each frame extracts the sort column's keys (as before) and, when
 * they and the sort column/direction are unchanged, reuses the cached order instead of re-sorting.
 * So a stable table costs O(n) per frame rather than O(n log n) — a large sorted grid stays cheap,
 * yet an edit to a sorted cell is still picked up (the changed key invalidates the cache).
 */
public class Table <: Widget {
    private let id: String
    private let columns: Array<TableColumn>
    private let rows: Array<Array<String>>
    private let selected: Bindable<Int64>
    private let scrollOffset: State<Float32>
    private let sortCol: State<Int64>
    private let sortAsc: State<Bool>
    private let scrollBar: ScrollBar
    // The selection last scrolled into view, retained across rebuilds — so a changed selection
    // (however it changed, including an app setting it directly) is revealed, like ListView does.
    private let lastRevealed: State<Int64>
    // The cached display order and the sort inputs it was computed from, retained across the
    // per-frame rebuild so a stable table is not re-sorted every frame. See displayOrder.
    private let sortCache: TableSortCache
    private var frame = Rect.zero()

    public init(id: String, columns: Array<TableColumn>, rows: Array<Array<String>>, selected: Bindable<Int64>) {
        requireControlId(id, "Table")
        this.id = id
        this.columns = columns
        this.rows = rows
        this.selected = selected
        // Keys carry the widget-type prefix like every sibling control, so they can never
        // collide with an app's own rememberState keys (or another widget's) built from `id`.
        this.scrollOffset = localState<Float32>("Table:${id}:scroll") {0.0}
        this.sortCol = localState<Int64>("Table:${id}:sortCol") {-1}
        this.sortAsc = localState<Bool>("Table:${id}:sortAsc") {true}
        this.scrollBar = ScrollBar("Table:${id}:thumb")
        this.lastRevealed = localState<Int64>("Table:${id}:revealed") {Int64.Min}
        this.sortCache = localState<TableSortCache>("Table:${id}:sortCache") {TableSortCache()}.value
        registerFocusable(id)
        emit(this)
    }

    /**
     * The data-driven form: builds a table from an `Array<T>` and typed columns, so the source data
     * stays typed and each column's header and extraction sit together — no hand-built string matrix.
     *
     * ```
     * Table.of("fleet", servers, [
     *     DataColumn("主机", 180.0) {s => s.host},
     *     DataColumn("负载", 100.0, numeric: true) {s => "${s.load}"},
     *     DataColumn("地区", 140.0) {s => s.region}
     * ], model.selected)
     * ```
     *
     * The value extractors run per visible frame to form the cells the base table sorts and draws; for
     * a very large dataset that is redrawn continuously, prefer the raw `Array<Array<String>>` form with
     * a hoisted matrix. Selection is the original row index into `data`.
     */
    public static func of<T>(
        id: String,
        data: Array<T>,
        columns: Array<DataColumn<T>>,
        selected: Bindable<Int64>
    ): Table {
        let tableColumns = Array<TableColumn>(columns.size) {
            i => TableColumn(columns[i].title, columns[i].width, numeric: columns[i].numeric, cell: columns[i].cell)
        }
        let rows = Array<Array<String>>(data.size) {
            r => Array<String>(columns.size) {c => columns[c].value(data[r])}
        }
        Table(id, tableColumns, rows, selected)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, available.h)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func isFlexible(): Bool {
        true
    }

    public func draw(ctx: UiContext): Unit {
        let order = displayOrder()
        drawSurface(ctx, frame, ctx.theme.fieldSurface(ctx.showFocusRing(id)))
        let body = bodyRect()
        scrollOffset.value = clampScrollOffset(scrollOffset.value, contentHeight(), body.h)
        // Reveal the selection when it changed since last frame — including an app setting it
        // directly (e.g. a "find row" action) rather than through this table's own keys.
        if (selected.value != lastRevealed.value) {
            let pos = displayPositionOf(order, selected.value)
            if (pos >= 0) {
                revealPosition(pos)
            }
            lastRevealed.value = selected.value
        }
        drawBody(ctx, order, body)
        drawHeader(ctx)
        drawVerticalScrollBar(ctx, body, scrollOffset.value, contentHeight(), body.h, active: scrollBar.dragging(ctx))
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        // A data grid keeps the plain arrow cursor over its rows (like a spreadsheet), rather
        // than the pointer hand used for buttons — so it claims no hover cursor.
        let body = bodyRect()
        let contentH = contentHeight()
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                if (scrollBar.press(ctx, body, scrollOffset, contentH, body.h, x, y)) {
                    return true
                }
                if (headerRect().contains(x, y)) {
                    ctx.focus(id)
                    let col = columnAt(x)
                    if (col >= 0) {
                        toggleSort(col)
                    }
                    return true
                }
                if (frame.contains(x, y)) {
                    ctx.focus(id)
                    if (body.contains(x, y)) {
                        let order = displayOrder()
                        let d = Int64((y - body.y + scrollOffset.value) / CUI_SMALL_H)
                        if (d >= 0 && d < order.size) {
                            selected.value = order[d]
                        }
                    }
                    return true
                }
            case UiEvent.MouseMove(_, y) =>
                if (scrollBar.drag(ctx, body, scrollOffset, contentH, body.h, y)) {
                    return true
                }
            case UiEvent.MouseWheel(_, wheelY, pointerX, pointerY) =>
                if (body.contains(pointerX, pointerY)) {
                    scrollOffset.value = scrollOffsetAfterWheel(scrollOffset.value, wheelY, contentH, body.h)
                    return true
                }
            case UiEvent.KeyDown(Key.Up, _) => return moveSelection(ctx, -1)
            case UiEvent.KeyDown(Key.Down, _) => return moveSelection(ctx, 1)
            case UiEvent.KeyDown(Key.Home, _) => return setSelectionToDisplay(ctx, 0)
            case UiEvent.KeyDown(Key.End, _) => return setSelectionToDisplay(ctx, rows.size - 1)
            case _ => ()
        }
        false
    }

    public func focusableId(): ?String {
        Some(id)
    }

    // --- geometry ---

    private func headerRect(): Rect {
        Rect(frame.x, frame.y, frame.w, min(TABLE_HEADER_H, frame.h))
    }

    private func bodyRect(): Rect {
        Rect(frame.x, frame.y + TABLE_HEADER_H, frame.w, max(0.0, frame.h - TABLE_HEADER_H))
    }

    private func contentHeight(): Float32 {
        Float32(rows.size) * CUI_SMALL_H
    }

    private func columnX(index: Int64): Float32 {
        var x = frame.x
        var i = 0
        while (i < index && i < columns.size) {
            x += columns[i].width
            i += 1
        }
        x
    }

    private func columnAt(x: Float32): Int64 {
        var i = 0
        while (i < columns.size) {
            let cx = columnX(i)
            if (x >= cx && x < cx + columns[i].width) {
                return i
            }
            i += 1
        }
        -1
    }

    // --- drawing ---

    private func drawHeader(ctx: UiContext): Unit {
        let header = headerRect()
        ctx.renderer.fill(header, ctx.theme.panelEdge.withAlpha(36))
        ctx.renderer.pushClip(header)
        var i = 0
        while (i < columns.size) {
            drawHeaderCell(ctx, columns[i], i, Rect(columnX(i), header.y, columns[i].width, header.h))
            i += 1
        }
        ctx.renderer.popClip()
        ctx.renderer.fill(Rect(header.x, header.bottom() - 1.0, header.w, 1.0), ctx.theme.panelEdge)
    }

    private func drawHeaderCell(ctx: UiContext, col: TableColumn, index: Int64, cell: Rect): Unit {
        let sorted = sortCol.value == index
        let color = if (sorted) {
            ctx.theme.text
        } else {
            ctx.theme.mutedText
        }
        let ty = cell.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.CAPTION) / 2.0
        ctx.renderer.text(col.title, cell.x + TABLE_CELL_PAD, ty, color, pointSize: FontSizes.CAPTION)
        if (sorted) {
            drawSortArrow(ctx, Rect(cell.right() - 16.0, cell.y, 12.0, cell.h), sortAsc.value)
        }
    }

    // A small caret drawn with two strokes (font glyphs for arrows are unreliable): up for
    // ascending, down for descending.
    private func drawSortArrow(ctx: UiContext, area: Rect, ascending: Bool): Unit {
        let cx = area.centerX()
        let cy = area.centerY()
        let pen = Pen(width: 1.4, color: ctx.theme.text)
        if (ascending) {
            ctx.renderer.strokeLine(cx - 4.0, cy + 3.0, cx, cy - 3.0, pen)
            ctx.renderer.strokeLine(cx, cy - 3.0, cx + 4.0, cy + 3.0, pen)
        } else {
            ctx.renderer.strokeLine(cx - 4.0, cy - 3.0, cx, cy + 3.0, pen)
            ctx.renderer.strokeLine(cx, cy + 3.0, cx + 4.0, cy - 3.0, pen)
        }
    }

    private func drawBody(ctx: UiContext, order: Array<Int64>, body: Rect): Unit {
        ctx.renderer.pushClip(body)
        var d = scrollLineIndex(scrollOffset.value)
        var y = body.y - scrollLineRemainder(scrollOffset.value)
        while (d < order.size && y < body.bottom()) {
            drawRow(ctx, order[d], d, Rect(body.x, y, body.w, CUI_SMALL_H))
            y += CUI_SMALL_H
            d += 1
        }
        ctx.renderer.popClip()
    }

    private func drawRow(ctx: UiContext, rowIndex: Int64, displayPos: Int64, rowRect: Rect): Unit {
        if (rowIndex == selected.value) {
            ctx.renderer.fillRoundedRect(rowRect.inset(1.0), ctx.theme.smallRadius, ctx.theme.accentSoft)
        } else if (displayPos % 2 == 1) {
            ctx.renderer.fill(rowRect, ctx.theme.panelEdge.withAlpha(24))
        }
        var i = 0
        while (i < columns.size) {
            drawCell(ctx, rowIndex, cellAt(rowIndex, i), columns[i],
                Rect(columnX(i), rowRect.y, columns[i].width, rowRect.h))
            i += 1
        }
    }

    private func drawCell(ctx: UiContext, rowIndex: Int64, text: String, col: TableColumn, cell: Rect): Unit {
        ctx.renderer.pushClip(cell)
        match (col.cell) {
            case Some(paint) => paint(ctx, rowIndex, text, cell)
            case None =>
                let ty = cell.centerY() - ctx.renderer.textHeight(pointSize: FontSizes.BODY) / 2.0
                if (col.numeric) {
                    let tw = ctx.renderer.textWidth(text, pointSize: FontSizes.BODY)
                    ctx.renderer.text(text, cell.right() - TABLE_CELL_PAD - tw, ty, ctx.theme.text,
                        pointSize: FontSizes.BODY)
                } else {
                    ctx.renderer.text(text, cell.x + TABLE_CELL_PAD, ty, ctx.theme.text, pointSize: FontSizes.BODY)
                }
        }
        ctx.renderer.popClip()
    }

    // --- selection & sorting ---

    private func toggleSort(col: Int64): Unit {
        if (sortCol.value == col) {
            sortAsc.value = !sortAsc.value
        } else {
            sortCol.value = col
            sortAsc.value = true
        }
    }

    private func moveSelection(ctx: UiContext, delta: Int64): Bool {
        if (!ctx.hasFocus(id) || rows.isEmpty()) {
            return false
        }
        let order = displayOrder()
        selectDisplay(order, clampPosition(displayPositionOf(order, selected.value) + delta, order.size))
        true
    }

    private func setSelectionToDisplay(ctx: UiContext, pos: Int64): Bool {
        if (!ctx.hasFocus(id) || rows.isEmpty()) {
            return false
        }
        let order = displayOrder()
        selectDisplay(order, clampPosition(pos, order.size))
        true
    }

    // Selects the row at a display position and scrolls it into view.
    private func selectDisplay(order: Array<Int64>, pos: Int64): Unit {
        if (pos < 0 || pos >= order.size) {
            return
        }
        selected.value = order[pos]
        revealPosition(pos)
    }

    // Scrolls the given display position's row band minimally into view.
    private func revealPosition(pos: Int64): Unit {
        let body = bodyRect()
        let rowTop = Float32(pos) * CUI_SMALL_H
        let rowBottom = rowTop + CUI_SMALL_H
        var scroll = scrollOffset.value
        if (rowTop < scroll) {
            scroll = rowTop
        } else if (rowBottom > scroll + body.h) {
            scroll = rowBottom - body.h
        }
        scrollOffset.value = clampScrollOffset(scroll, contentHeight(), body.h)
    }

    // The display position of a selected row, or -1 when nothing valid is selected — so the next
    // Down lands on the first row (clampPosition(-1 + 1) == 0) rather than skipping it.
    private func displayPositionOf(order: Array<Int64>, rowIndex: Int64): Int64 {
        var i = 0
        while (i < order.size) {
            if (order[i] == rowIndex) {
                return i
            }
            i += 1
        }
        -1
    }

    private func cellAt(row: Int64, col: Int64): String {
        if (row < 0 || row >= rows.size) {
            return ""
        }
        let cells = rows[row]
        if (col < 0 || col >= cells.size) {
            ""
        } else {
            cells[col]
        }
    }

    // Original row indices in display order: identity when unsorted, else a stable sort by the
    // active column's cells (numeric or lexical), ascending or descending. The result is cached and
    // reused while the sort inputs are unchanged, so a stable table is not re-sorted every frame.
    private func displayOrder(): Array<Int64> {
        let n = rows.size
        let col = sortCol.value
        if (col < 0 || col >= columns.size || n <= 1) {
            return identityOrder(n)
        }
        let ascending = sortAsc.value
        // Extract the sort column's raw cells once (O(n)). These validate the cache for both column
        // kinds: unchanged cells mean unchanged keys, so the cached order is reused and neither the
        // sort nor (for numeric columns) the number parsing runs. On a miss, the parse and the
        // O(n log n) stable sort run over these cells and the result is cached.
        let cells = Array<String>(n, {i => cellAt(i, col)})
        if (sortCache.valid && sortCache.col == col && sortCache.asc == ascending &&
            stringKeysEqual(sortCache.cells, cells)) {
            return sortCache.order
        }
        let order = if (columns[col].numeric) {
            let keys = Array<Float64>(n, {i => numericKey(cells[i])})
            stableSort(identityOrder(n), {a, b => lessByOrder(compareFloat(keys[a], keys[b]), ascending)})
        } else {
            stableSort(identityOrder(n), {a, b => lessByOrder(compareBytes(cells[a], cells[b]), ascending)})
        }
        storeSort(col, ascending, cells, order)
        order
    }

    // The identity order [0, 1, ..., n-1], cached while the row count is unchanged so an unsorted
    // (or about-to-be-sorted) table does not reallocate it every frame. A row-count change also
    // invalidates any cached sorted order, since the row indices it referenced no longer hold.
    private func identityOrder(n: Int64): Array<Int64> {
        if (sortCache.rowCount == n && sortCache.identity.size == n) {
            return sortCache.identity
        }
        let identity = Array<Int64>(n, {i => i})
        sortCache.rowCount = n
        sortCache.identity = identity
        sortCache.valid = false
        identity
    }

    // Records a freshly computed sort so the next frame with the same inputs can reuse it.
    private func storeSort(col: Int64, ascending: Bool, cells: Array<String>, order: Array<Int64>): Unit {
        sortCache.valid = true
        sortCache.col = col
        sortCache.asc = ascending
        sortCache.cells = cells
        sortCache.order = order
    }

    private func lessByOrder(comparison: Int64, ascending: Bool): Bool {
        if (ascending) {
            comparison < 0
        } else {
            comparison > 0
        }
    }
}

/*
 * The Table's retained sort state, persisted across the per-frame rebuild via localState. It holds
 * the last computed display order together with the inputs it was computed from — the sort column,
 * direction, and the raw cells of that column — plus a cached identity order for the unsorted case.
 * displayOrder reuses `order` when the freshly extracted cells and the sort column/direction still
 * match, so a stable sorted table is neither re-parsed nor re-sorted every frame.
 */
private class TableSortCache {
    var rowCount: Int64 = -1
    var identity: Array<Int64> = Array<Int64>()
    var valid: Bool = false
    var col: Int64 = -1
    var asc: Bool = true
    var cells: Array<String> = Array<String>()
    var order: Array<Int64> = Array<Int64>()
}

// Element-wise value equality of two string key arrays, short-circuiting on the first difference.
private func stringKeysEqual(a: Array<String>, b: Array<String>): Bool {
    if (a.size != b.size) {
        return false
    }
    var i = 0
    while (i < a.size) {
        if (a[i] != b[i]) {
            return false
        }
        i += 1
    }
    true
}

private func clampPosition(pos: Int64, count: Int64): Int64 {
    if (count <= 0) {
        0
    } else if (pos < 0) {
        0
    } else if (pos >= count) {
        count - 1
    } else {
        pos
    }
}

// Bottom-up stable merge sort on a copy of the indices — O(n log n), keeps equal elements in
// their original order (a stable sort is what makes re-sorting a table feel predictable).
private func stableSort(input: Array<Int64>, less: (Int64, Int64) -> Bool): Array<Int64> {
    let n = input.size
    let a = Array<Int64>(n, {i => input[i]})
    if (n <= 1) {
        return a
    }
    let buffer = Array<Int64>(n, {_ => 0})
    var width = 1
    while (width < n) {
        var lo = 0
        while (lo < n) {
            mergeRuns(a, buffer, lo, min(lo + width, n), min(lo + width * 2, n), less)
            lo += width * 2
        }
        var k = 0
        while (k < n) {
            a[k] = buffer[k]
            k += 1
        }
        width *= 2
    }
    a
}

private func mergeRuns(
    a: Array<Int64>,
    buffer: Array<Int64>,
    lo: Int64,
    mid: Int64,
    hi: Int64,
    less: (Int64, Int64) -> Bool
): Unit {
    var i = lo
    var j = mid
    var k = lo
    while (i < mid && j < hi) {
        // Take the left run unless the right element is strictly smaller — this preserves the
        // relative order of equal elements (stability).
        if (less(a[j], a[i])) {
            buffer[k] = a[j]
            j += 1
        } else {
            buffer[k] = a[i]
            i += 1
        }
        k += 1
    }
    while (i < mid) {
        buffer[k] = a[i]
        i += 1
        k += 1
    }
    while (j < hi) {
        buffer[k] = a[j]
        j += 1
        k += 1
    }
}

private func compareFloat(x: Float64, y: Float64): Int64 {
    if (x < y) {
        -1
    } else if (x > y) {
        1
    } else {
        0
    }
}

// Lexical comparison over UTF-8 bytes: alphabetical for ASCII and a stable, consistent order
// for other scripts.
private func compareBytes(a: String, b: String): Int64 {
    var i = 0
    while (i < a.size && i < b.size) {
        if (a[i] < b[i]) {
            return -1
        }
        if (a[i] > b[i]) {
            return 1
        }
        i += 1
    }
    if (a.size < b.size) {
        -1
    } else if (a.size > b.size) {
        1
    } else {
        0
    }
}

// Parses a leading signed decimal from a cell for numeric sorting, tolerating surrounding text
// (leading spaces, a trailing unit like "%"): "87%" -> 87, " 3.5" -> 3.5, "-12" -> -12.
private func numericKey(text: String): Float64 {
    let n = text.size
    var i = 0
    while (i < n && text[i] == UInt8(32)) {
        i += 1
    }
    var sign = 1.0
    if (i < n && (text[i] == UInt8(45) || text[i] == UInt8(43))) {
        if (text[i] == UInt8(45)) {
            sign = -1.0
        }
        i += 1
    }
    var intPart = 0.0
    var sawDigit = false
    while (i < n && text[i] >= UInt8(48) && text[i] <= UInt8(57)) {
        intPart = intPart * 10.0 + Float64(Int64(text[i]) - 48)
        sawDigit = true
        i += 1
    }
    var fraction = 0.0
    var divisor = 1.0
    if (i < n && text[i] == UInt8(46)) {
        i += 1
        while (i < n && text[i] >= UInt8(48) && text[i] <= UInt8(57)) {
            divisor *= 10.0
            fraction += Float64(Int64(text[i]) - 48) / divisor
            sawDigit = true
            i += 1
        }
    }
    if (!sawDigit) {
        return 0.0
    }
    sign * (intPart + fraction)
}
