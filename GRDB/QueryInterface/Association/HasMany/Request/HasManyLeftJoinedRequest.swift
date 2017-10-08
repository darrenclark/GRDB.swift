public struct HasManyLeftJoinedRequest<Left, Right> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let association: HasManyAssociation<Left, Right>
}

extension HasManyLeftJoinedRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasManyLeftJoinedRequest {
        return HasManyLeftJoinedRequest(
            leftRequest: transform(leftRequest),
            association: association)
    }
}

extension HasManyLeftJoinedRequest : TypedRequest {
    public typealias RowDecoder = JoinedPair<Left, Right?>
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try prepareJoinedPairRequest(
            db,
            left: leftRequest.query,
            join: .left,
            right: association.rightRequest.query,
            on: association.mapping(db),
            leftScope: RowDecoder.leftScope,
            rightScope: RowDecoder.rightScope)
    }
}

extension QueryInterfaceRequest where RowDecoder: TableMapping {
    public func leftJoined<Right>(with association: HasManyAssociation<RowDecoder, Right>)
        -> HasManyLeftJoinedRequest<RowDecoder, Right>
    {
        return HasManyLeftJoinedRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func leftJoined<Right>(with association: HasManyAssociation<Self, Right>)
        -> HasManyLeftJoinedRequest<Self, Right>
    {
        return all().leftJoined(with: association)
    }
}
