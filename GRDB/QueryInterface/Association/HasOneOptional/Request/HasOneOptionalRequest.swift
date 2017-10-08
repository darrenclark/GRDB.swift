public struct HasOneOptionalRequest<Left, Right> where
    Left: MutablePersistable,
    Right: TableMapping
{
    let record: Left
    let association: HasOneOptionalAssociation<Left, Right>
}

extension HasOneOptionalRequest : RequestDerivableWrapper {
    public typealias WrappedRequest = HasOneOptionalAssociation<Left, Right>.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasOneOptionalRequest {
        return HasOneOptionalRequest(record: record, association: association.mapRequest(transform))
    }
}

extension HasOneOptionalRequest : TypedRequest {
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

extension HasOneOptionalAssociation where Left: MutablePersistable {
    func request(from record: Left) -> HasOneOptionalRequest<Left, Right> {
        return HasOneOptionalRequest(record: record, association: self)
    }
}

extension MutablePersistable {
    public func request<Right>(_ association: HasOneOptionalAssociation<Self, Right>)
        -> HasOneOptionalRequest<Self, Right>
    {
        return association.request(from: self)
    }
    
    public func fetchOne<Right>(_ db: Database, _ association: HasOneOptionalAssociation<Self, Right>) throws
        -> Right?
        where Right: RowConvertible
    {
        return try association.request(from: self).fetchOne(db)
    }
}
