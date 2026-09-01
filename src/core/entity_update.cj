package cui.core

/** One ordered endomorphism targeting an entity ID in an EntityTable batch. */
public struct EntityUpdate<ID, Entity> {
    /** Target entity ID. */
    public let id: ID
    private let updateEntity: (Entity) -> Entity

    public init(id: ID, transform!: (Entity) -> Entity) {
        this.id = id
        updateEntity = transform
    }

    /** Applies this update to one already-resolved entity. */
    public func apply(entity: Entity): Entity {
        updateEntity(entity)
    }
}
