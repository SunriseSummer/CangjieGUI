package cui.desktop

/** Identifies the independently quarantined branch that rejected an accessibility operation. */
public enum AccessibilityFailureSource {
    | NativeBridge
    | ExternalAdapter
    | FailureHandler
}

/** Identifies which accessibility boundary operation failed. */
public enum AccessibilityFailureOperation {
    | Update
    | DrainActions
    | ReportFailure
}

/** One observable failure from an isolated desktop accessibility branch. */
public class AccessibilityFailure {
    public let source: AccessibilityFailureSource
    public let operation: AccessibilityFailureOperation
    public let revision: UInt64
    public let cause: Exception

    init(
        source: AccessibilityFailureSource,
        operation: AccessibilityFailureOperation,
        revision: UInt64,
        cause: Exception
    ) {
        this.source = source
        this.operation = operation
        this.revision = revision
        this.cause = cause
    }
}
