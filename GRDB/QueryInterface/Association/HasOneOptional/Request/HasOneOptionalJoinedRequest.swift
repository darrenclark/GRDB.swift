// TODO: consider only using left joins for this kind of query
public struct HasOneOptionalJoinedRequest<Left, Right> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let association: HasOneOptionalAssociation<Left, Right>
}

extension HasOneOptionalJoinedRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasOneOptionalJoinedRequest {
        return HasOneOptionalJoinedRequest(leftRequest: transform(leftRequest), association: association)
    }
}

extension HasOneOptionalJoinedRequest : TypedRequest {
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
    public func joined<Right>(with association: HasOneOptionalAssociation<RowDecoder, Right>)
        -> HasOneOptionalJoinedRequest<RowDecoder, Right>
    {
        return HasOneOptionalJoinedRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func joined<Right>(with association: HasOneOptionalAssociation<Self, Right>)
        -> HasOneOptionalJoinedRequest<Self, Right>
    {
        return all().joined(with: association)
    }
}
