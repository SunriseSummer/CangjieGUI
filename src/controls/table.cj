package cui.controls

import sdl.{Color, FontSizes, Key, MouseButton, Pen, Rect, Size, UiEvent}
import cui.core.{clampItemIndex, Bindable, CUI_SMALL_H, ScrollBar, State, UiContext, Widget, resolveControlKey,
    clampScrollOffset, maxScrollOffset, drawSurface, drawVerticalScrollBar, emit, localState, registerFocusable,
    scrollLineIndex, scrollLineRemainder, scrollByWheel}

private let TABLE_HEADER_H: Float32 = 32.0
private let TABLE_CELL_PAD: Float32 = 10.0

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
    private var rowHeight: Float32 = CUI_SMALL_H
    private var headerHeight: Float32 = TABLE_HEADER_H

    public init(columns: Array<TableColumn>, rows: Array<Array<String>>, selected: Bindable<Int64>, key!: ?String = None) {
        let ident = resolveControlKey(key, "Table")
        this.id = ident
        this.columns = columns
        this.rows = rows
        this.selected = selected
        // Keys carry the widget-type prefix like every sibling control, so they can never
        // collide with an app's own rememberState keys (or another widget's) built from `id`.
        this.scrollOffset = localState<Float32>("Table:${ident}:scroll") {0.0}
        this.sortCol = localState<Int64>("Table:${ident}:sortCol") {-1}
        this.sortAsc = localState<Bool>("Table:${ident}:sortAsc") {true}
        this.scrollBar = ScrollBar("Table:${ident}:thumb")
        this.lastRevealed = localState<Int64>("Table:${ident}:revealed") {Int64.Min}
        this.sortCache = localState<TableSortCache>("Table:${ident}:sortCache") {TableSortCache()}.value
        registerFocusable(ident)
        emit(this)
    }

    /**
     * The data-driven form: builds a table from an `Array<T>` and typed columns, so the source data
     * stays typed and each column's header and extraction sit together — no hand-built string matrix.
     *
     * ```
     * Table.of(servers, [
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
        data: Array<T>,
        columns: Array<DataColumn<T>>,
        selected: Bindable<Int64>,
        key!: ?String = None
    ): Table {
        let tableColumns = Array<TableColumn>(columns.size) {
            i => TableColumn(columns[i].title, columns[i].width, numeric: columns[i].numeric, cell: columns[i].cell)
        }
        let rows = Array<Array<String>>(data.size) {
            r => Array<String>(columns.size) {c => columns[c].value(data[r])}
        }
        Table(tableColumns, rows, selected, key: key)
    }

    public func measure(ctx: UiContext, available: Size): Size {
        rowHeight = ctx.textRowHeight()
        headerHeight = ctx.textRowHeight(minHeight: TABLE_HEADER_H)
        Size(available.w, available.h)
    }

    public func layout(ctx: UiContext, rect: Rect): Unit {
        rowHeight = ctx.textRowHeight()
        headerHeight = ctx.textRowHeight(minHeight: TABLE_HEADER_H)
        frame = rect
        let body = bodyRect()
        let clamped = clampScrollOffset(scrollOffset.value, contentHeight(), body.h)
        if (clamped != scrollOffset.value) {
            scrollOffset.value = clamped
        }
        // Resolve viewport state during layout, before the frame is committed for painting.
        if (selected.value != lastRevealed.value) {
            let pos = displayPositionOf(displayOrder(), selected.value)
            if (pos >= 0) {
                revealPosition(pos)
            }
            lastRevealed.value = selected.value
        }
    }

    public func isFlexible(): Bool {
        true
    }

    public func draw(ctx: UiContext): Unit {
        let order = displayOrder()
        drawSurface(ctx, frame, ctx.theme.fieldSurface(active: ctx.showFocusRing(id)))
        let body = bodyRect()
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
                        let d = Int64((y - body.y + scrollOffset.value) / rowHeight)
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
                // Content that fits leaves the wheel to an enclosing scroller (no dead zone).
                if (body.contains(pointerX, pointerY) && maxScrollOffset(contentH, body.h) > 0.0) {
                    return scrollByWheel(scrollOffset, wheelY, contentH, body.h)
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
        Rect(frame.x, frame.y, frame.w, min(headerHeight, frame.h))
    }

    private func bodyRect(): Rect {
        Rect(frame.x, frame.y + headerHeight, frame.w, max(0.0, frame.h - headerHeight))
    }

    private func contentHeight(): Float32 {
        Float32(rows.size) * rowHeight
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
        try {
            var i = 0
            while (i < columns.size) {
                drawHeaderCell(ctx, columns[i], i, Rect(columnX(i), header.y, columns[i].width, header.h))
                i += 1
            }
        } finally {
            ctx.renderer.popClip()
        }
        ctx.renderer.fill(Rect(header.x, header.bottom() - 1.0, header.w, 1.0), ctx.theme.panelEdge)
    }

    private func drawHeaderCell(ctx: UiContext, col: TableColumn, index: Int64, cell: Rect): Unit {
        let sorted = sortCol.value == index
        let color = if (sorted) {
            ctx.theme.text
        } else {
            ctx.theme.mutedText
        }
        let ty = cell.centerY() - ctx.textHeight(pointSize: ctx.textSize(fallback: FontSizes.CAPTION)) / 2.0
        ctx.text(col.title, cell.x + TABLE_CELL_PAD, ty, color, pointSize: ctx.textSize(fallback: FontSizes.CAPTION))
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
        try {
            var d = scrollLineIndex(scrollOffset.value, rowHeight: rowHeight)
            var y = body.y - scrollLineRemainder(scrollOffset.value, rowHeight: rowHeight)
            while (d < order.size && y < body.bottom()) {
                drawRow(ctx, order[d], d, Rect(body.x, y, body.w, rowHeight))
                y += rowHeight
                d += 1
            }
        } finally {
            ctx.renderer.popClip()
        }
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
        try {
            match (col.cell) {
                case Some(paint) => paint(ctx, rowIndex, text, cell)
                case None =>
                    let ty = cell.centerY() - ctx.textHeight(pointSize: ctx.textSize(fallback: FontSizes.BODY)) / 2.0
                    if (col.numeric) {
                        let tw = ctx.textWidth(text, pointSize: ctx.textSize(fallback: FontSizes.BODY))
                        ctx.text(text, cell.right() - TABLE_CELL_PAD - tw, ty, ctx.theme.text,
                            pointSize: ctx.textSize(fallback: FontSizes.BODY))
                    } else {
                        ctx.text(text, cell.x + TABLE_CELL_PAD, ty, ctx.theme.text,
                            pointSize: ctx.textSize(fallback: FontSizes.BODY))
                    }
            }
        } finally {
            ctx.renderer.popClip()
        }
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
        selectDisplay(order, clampItemIndex(displayPositionOf(order, selected.value) + delta, order.size))
        true
    }

    private func setSelectionToDisplay(ctx: UiContext, pos: Int64): Bool {
        if (!ctx.hasFocus(id) || rows.isEmpty()) {
            return false
        }
        let order = displayOrder()
        selectDisplay(order, clampItemIndex(pos, order.size))
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
        let rowTop = Float32(pos) * rowHeight
        let rowBottom = rowTop + rowHeight
        var scroll = scrollOffset.value
        if (rowTop < scroll) {
            scroll = rowTop
        } else if (rowBottom > scroll + body.h) {
            scroll = rowBottom - body.h
        }
        let clamped = clampScrollOffset(scroll, contentHeight(), body.h)
        if (clamped != scrollOffset.value) {
            scrollOffset.value = clamped
        }
    }

    // The display position of a selected row, or -1 when nothing valid is selected — so the next
    // Down lands on the first row (clampItemIndex(-1 + 1) == 0) rather than skipping it.
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
        if (sortCache.valid && sortCache.col == col && sortCache.asc == ascending && stringKeysEqual(sortCache.cells,
            cells)) {
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
