package cui.core

/**
 * A composable, bidirectional projection from a source value `S` to one focus `A`.
 * Well-behaved lenses satisfy Get-Put, Put-Get, and Put-Put; generated field lenses
 * can enforce these laws by construction, while custom lenses should be property-tested.
 * Composition also preserves a fused endomorphism path so writes traverse each lens once.
 */
public class Lens<S, A> {
    private let read: (S) -> A
    private let write: (S, A) -> S
    private let modify: (S, (A) -> A) -> S

    public init(get!: (S) -> A, set!: (S, A) -> S) {
        this.read = get
        this.write = set
        this.modify = {source, transform => set(source, transform(get(source)))}
    }

    private init(
        get!: (S) -> A,
        set!: (S, A) -> S,
        modify!: (S, (A) -> A) -> S
    ) {
        this.read = get
        this.write = set
        this.modify = modify
    }

    /** Reads the focused value. */
    public func get(source: S): A {
        read(source)
    }

    /** Rebuilds `source` with a replacement focused value. */
    public func set(source: S, value: A): S {
        write(source, value)
    }

    /** Applies one endomorphism to the focus while traversing every composed Lens exactly once. */
    public func update(source: S, transform: (A) -> A): S {
        modify(source, transform)
    }

    /** Composes this projection with a projection from `A` to `B`. */
    public func then<B>(next: Lens<A, B>): Lens<S, B> {
        let nextRead = next.read
        let nextWrite = next.write
        let nextModify = next.modify
        Lens<S, B>(
            get: {source => nextRead(read(source))},
            set: {
                source, value => modify(source, {focused => nextWrite(focused, value)})
            },
            modify: {
                source, transform => modify(source, {focused => nextModify(focused, transform)})
            }
        )
    }
}
