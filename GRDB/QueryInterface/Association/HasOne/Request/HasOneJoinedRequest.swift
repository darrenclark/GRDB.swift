// TODO: consider only using left joins for this kind of query
public struct HasOneJoinedRequest<Left, Right> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let association: HasOneAssociation<Left, Right>
}

extension HasOneJoinedRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasOneJoinedRequest {
        return HasOneJoinedRequest(
            leftRequest: transform(leftRequest),
            association: association)
    }
}

extension HasOneJoinedRequest : TypedRequest {
    public typealias RowDecoder = Left
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        // Generates SELECT left.* FROM left LEFT JOIN right
        //
        // We use LEFT JOIN because:
        //
        // 1. HasOneAssociation assumes the database has a right item for
        //    every left item.
        // 2. Hence JOIN and LEFT JOIN are assumed to produce the same results.
        // 3. If the database happens not to always have a right item for every
        //    left item, using JOIN would miss some left items.
        // 4. Hence we prefer using LEFT JOIN because it does less harm to the
        ///   users who should have used HasOneOptionalAssociation.
        return try prepareJoinRequest(
            db,
            left: leftRequest.query,
            join: .left,
            right: association.rightRequest.query,
            on: association.mapping(db))
    }
}

extension QueryInterfaceRequest where RowDecoder: TableMapping {
    public func joined<Right>(with association: HasOneAssociation<RowDecoder, Right>)
        -> HasOneJoinedRequest<RowDecoder, Right>
    {
        return HasOneJoinedRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func joined<Right>(with association: HasOneAssociation<Self, Right>)
        -> HasOneJoinedRequest<Self, Right>
    {
        return all().joined(with: association)
    }
}
