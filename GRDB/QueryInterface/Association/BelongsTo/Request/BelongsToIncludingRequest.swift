public struct BelongsToIncludingRequest<Left, Right> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let association: BelongsToAssociation<Left, Right>
}

extension BelongsToIncludingRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> BelongsToIncludingRequest {
        return BelongsToIncludingRequest(
            leftRequest: transform(leftRequest),
            association: association)
    }
}

extension BelongsToIncludingRequest : TypedRequest {
    public typealias RowDecoder = JoinedPair<Left, Right>
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try prepareJoinedPairRequest(
            db,
            left: leftRequest.query,
            join: .inner,
            right: association.rightRequest.query,
            on: association.mapping(db),
            leftScope: RowDecoder.leftScope,
            rightScope: RowDecoder.rightScope)
    }
}

extension QueryInterfaceRequest where RowDecoder: TableMapping {
    public func including<Right>(_ association: BelongsToAssociation<RowDecoder, Right>)
        -> BelongsToIncludingRequest<RowDecoder, Right>
    {
        return BelongsToIncludingRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func including<Right>(_ association: BelongsToAssociation<Self, Right>)
        -> BelongsToIncludingRequest<Self, Right>
    {
        return all().including(association)
    }
}
