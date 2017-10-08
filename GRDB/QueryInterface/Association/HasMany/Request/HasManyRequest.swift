public struct HasManyRequest<Left, Right> where
    Left: MutablePersistable,
    Right: TableMapping
{
    let record: Left
    let association: HasManyAssociation<Left, Right>
}

extension HasManyRequest : RequestDerivableWrapper {
    public typealias WrappedRequest = HasManyAssociation<Left, Right>.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasManyRequest {
        return HasManyRequest(
            record: record,
            association: association.mapRequest(transform))
    }
}

extension HasManyRequest : TypedRequest {
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

extension HasManyAssociation where Left: MutablePersistable {
    func all(from record: Left) -> HasManyRequest<Left, Right> {
        return HasManyRequest(record: record, association: self)
    }
}

extension MutablePersistable {
    public func all<Right>(_ association: HasManyAssociation<Self, Right>)
        -> HasManyRequest<Self, Right>
    {
        return association.all(from: self)
    }
    
    public func fetchCursor<Right>(_ db: Database, _ association: HasManyAssociation<Self, Right>) throws
        -> RecordCursor<Right>
        where Right: RowConvertible
    {
        return try association.all(from: self).fetchCursor(db)
    }
    
    public func fetchAll<Right>(_ db: Database, _ association: HasManyAssociation<Self, Right>) throws
        -> [Right]
        where Right: RowConvertible
    {
        return try association.all(from: self).fetchAll(db)
    }
    
    public func fetchOne<Right>(_ db: Database, _ association: HasManyAssociation<Self, Right>) throws
        -> Right?
        where Right: RowConvertible
    {
        return try association.all(from: self).fetchOne(db)
    }
}
