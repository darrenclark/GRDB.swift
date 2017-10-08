public struct BelongsToOptionalRequest<Left, Right> where
    Left: MutablePersistable,
    Right: TableMapping
{
    let record: Left
    let association: BelongsToOptionalAssociation<Left, Right>
}

extension BelongsToOptionalRequest : RequestDerivableWrapper {
    public typealias WrappedRequest = BelongsToOptionalAssociation<Left, Right>.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> BelongsToOptionalRequest {
        return BelongsToOptionalRequest(
            record: record,
            association: association.mapRequest(transform))
    }
}

extension BelongsToOptionalRequest : TypedRequest {
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

extension BelongsToOptionalAssociation where Left: MutablePersistable {
    func request(from record: Left) -> BelongsToOptionalRequest<Left, Right> {
        return BelongsToOptionalRequest(record: record, association: self)
    }
}

extension MutablePersistable {
    public func request<Right>(_ association: BelongsToOptionalAssociation<Self, Right>)
        -> BelongsToOptionalRequest<Self, Right>
    {
        return association.request(from: self)
    }
    
    public func fetchOne<Right>(_ db: Database, _ association: BelongsToOptionalAssociation<Self, Right>) throws
        -> Right?
        where Right: RowConvertible
    {
        return try association.request(from: self).fetchOne(db)
    }
}
