package cui.controls

import sdl.Rect
import cui.core.UiContext

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
