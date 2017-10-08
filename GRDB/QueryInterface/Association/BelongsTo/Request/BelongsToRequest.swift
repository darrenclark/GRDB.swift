public struct BelongsToRequest<Left, Right> where
    Left: MutablePersistable,
    Right: TableMapping
{
    let record: Left
    let association: BelongsToAssociation<Left, Right>
}

extension BelongsToRequest : RequestDerivableWrapper {
    public typealias WrappedRequest = BelongsToAssociation<Left, Right>.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> BelongsToRequest {
        return BelongsToRequest(
            record: record,
            association: association.mapRequest(transform))
    }
}

extension BelongsToRequest : TypedRequest {
    public typealias RowDecoder = Right
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let mapping = try association.mapping(db)
        let container = PersistenceContainer(record)
        let rowValue = RowValue(mapping.map { container[caseInsensitive: $0.left]?.databaseValue ?? .null })
        return try association.rightRequest
            .filter(mapping.map { Column($0.right) } == rowValue)
            .prepare(db)
    }
}

extension BelongsToAssociation where Left: MutablePersistable {
    func request(from record: Left) -> BelongsToRequest<Left, Right> {
        return BelongsToRequest(record: record, association: self)
    }
}

extension MutablePersistable {
    // TODO: Fix this weird naming: child.request(Child.parent)
    // HasMany requests looks much better: parent.all(Parent.children)
    // What should we use?
    // - child.the(Child.parent).fetchOne(db)
    // - child.one(Child.parent).fetchOne(db)
    // - Child.parent.of(child).fetchOne(db)
    public func request<Right>(_ association: BelongsToAssociation<Self, Right>)
        -> BelongsToRequest<Self, Right>
    {
        return association.request(from: self)
    }
    
    public func fetchOne<Right>(_ db: Database, _ association: BelongsToAssociation<Self, Right>) throws
        -> Right?
        where Right: RowConvertible
    {
        return try association.request(from: self).fetchOne(db)
    }
}
