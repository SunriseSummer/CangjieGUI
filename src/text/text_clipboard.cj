package cui.text

import sdl.SdlException
import sdl.input.Clipboard

/** Plain-text clipboard access; callbacks support custom hosts and deterministic tests. */
public class TextClipboard {
    /** Shared stateless adapter for the system clipboard on the UI thread. */
    public static let system = TextClipboard()
    private let read: () -> String
    private let write: (String) -> Unit

    public init(read!: () -> String = {=> Clipboard.getText()},
        write!: (String) -> Unit = {value => Clipboard.setText(value)}) {
        this.read = read
        this.write = write
    }

    /** None means platform access failed; Some("") means no text is available. */
    public func readText(): ?String {
        try {
            let value = read()
            if (value.contains("\u{0000}")) {
                None
            } else {
                Some(value)
            }
        } catch (_: SdlException | IllegalArgumentException) {
            None
        }
    }

    /** Reports success; embedded NUL is rejected before invoking the writer. */
    public func writeText(value: String): Bool {
        if (value.contains("\u{0000}")) {
            return false
        }
        try {
            write(value)
            true
        } catch (_: SdlException | IllegalArgumentException) {
            false
        }
    }
}

internal func normalizedEditorInput(value: String, multiline!: Bool): String {
    let normalized = value.replace("\r\n", "\n").replace("\r", "\n")
    if (multiline) {
        normalized
    } else {
        normalized.replace("\n", " ")
    }
}
