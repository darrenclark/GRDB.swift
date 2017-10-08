public struct HasOneIncludingRequest<Left, Right> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let association: HasOneAssociation<Left, Right>
}

extension HasOneIncludingRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasOneIncludingRequest {
        return HasOneIncludingRequest(
            leftRequest: transform(leftRequest),
            association: association)
    }
}

extension HasOneIncludingRequest : TypedRequest {
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
    public func including<Right>(_ association: HasOneAssociation<RowDecoder, Right>)
        -> HasOneIncludingRequest<RowDecoder, Right>
    {
        return HasOneIncludingRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func including<Right>(_ association: HasOneAssociation<Self, Right>)
        -> HasOneIncludingRequest<Self, Right>
    {
        return all().including(association)
    }
}
