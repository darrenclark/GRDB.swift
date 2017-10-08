public struct BelongsToOptionalJoinedRequest<Left, Right> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let association: BelongsToOptionalAssociation<Left, Right>
}

extension BelongsToOptionalJoinedRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> BelongsToOptionalJoinedRequest {
        return BelongsToOptionalJoinedRequest(
            leftRequest: transform(leftRequest),
            association: association)
    }
}

extension BelongsToOptionalJoinedRequest : TypedRequest {
    public typealias RowDecoder = Left
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try prepareJoinRequest(
            db,
            left: leftRequest.query,
            join: .left,
            right: association.rightRequest.query,
            on: association.mapping(db))
    }
}

extension QueryInterfaceRequest where RowDecoder: TableMapping {
    public func joined<Right>(with association: BelongsToOptionalAssociation<RowDecoder, Right>)
        -> BelongsToOptionalJoinedRequest<RowDecoder, Right>
    {
        return BelongsToOptionalJoinedRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func joined<Right>(with association: BelongsToOptionalAssociation<Self, Right>)
        -> BelongsToOptionalJoinedRequest<Self, Right>
    {
        return all().joined(with: association)
    }
}
