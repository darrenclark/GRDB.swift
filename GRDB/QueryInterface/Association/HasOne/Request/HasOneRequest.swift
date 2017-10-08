public struct HasOneRequest<Left, Right> where
    Left: MutablePersistable,
    Right: TableMapping
{
    let record: Left
    let association: HasOneAssociation<Left, Right>
}

extension HasOneRequest : RequestDerivableWrapper {
    public typealias WrappedRequest = HasOneAssociation<Left, Right>.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasOneRequest {
        return HasOneRequest(record: record, association: association.mapRequest(transform))
    }
}

extension HasOneRequest : TypedRequest {
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

extension HasOneAssociation where Left: MutablePersistable {
    func request(from record: Left) -> HasOneRequest<Left, Right> {
        return HasOneRequest(record: record, association: self)
    }
}

extension MutablePersistable {
    public func request<Right>(_ association: HasOneAssociation<Self, Right>)
        -> HasOneRequest<Self, Right>
    {
        return association.request(from: self)
    }
    
    public func fetchOne<Right>(_ db: Database, _ association: HasOneAssociation<Self, Right>) throws
        -> Right?
        where Right: RowConvertible
    {
        return try association.request(from: self).fetchOne(db)
    }
}
