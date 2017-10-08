public struct HasManyJoinedRequest<Left, Right> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let association: HasManyAssociation<Left, Right>
}

extension HasManyJoinedRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasManyJoinedRequest {
        return HasManyJoinedRequest(
            leftRequest: transform(leftRequest),
            association: association)
    }
}

extension HasManyJoinedRequest : TypedRequest {
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
    public func joined<Right>(with association: HasManyAssociation<RowDecoder, Right>)
        -> HasManyJoinedRequest<RowDecoder, Right>
    {
        return HasManyJoinedRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func joined<Right>(with association: HasManyAssociation<Self, Right>)
        -> HasManyJoinedRequest<Self, Right>
    {
        return all().joined(with: association)
    }
}
