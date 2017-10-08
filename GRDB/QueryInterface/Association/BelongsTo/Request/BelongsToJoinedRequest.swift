public struct BelongsToJoinedRequest<Left, Right> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let association: BelongsToAssociation<Left, Right>
}

extension BelongsToJoinedRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> BelongsToJoinedRequest {
        return BelongsToJoinedRequest(
            leftRequest: transform(leftRequest),
            association: association)
    }
}

extension BelongsToJoinedRequest : TypedRequest {
    public typealias RowDecoder = Left
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        // Generates SELECT left.* FROM left LEFT JOIN right
        //
        // We use LEFT JOIN because:
        //
        // 1. BelongsToAssociation assumes the database has a right item for
        //    every left item.
        // 2. Hence JOIN and LEFT JOIN are assumed to produce the same results.
        // 3. If the database happens not to always have a right item for every
        //    left item, using JOIN would miss some left items.
        // 4. Hence we prefer using LEFT JOIN because it does less harm to the
        ///   users who should have used BelongsToOptionalAssociation.
        return try prepareJoinRequest(
            db,
            left: leftRequest.query,
            join: .left,
            right: association.rightRequest.query,
            on: association.mapping(db))
    }
}

extension QueryInterfaceRequest where RowDecoder: TableMapping {
    public func joined<Right>(with association: BelongsToAssociation<RowDecoder, Right>)
        -> BelongsToJoinedRequest<RowDecoder, Right>
    {
        return BelongsToJoinedRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func joined<Right>(with association: BelongsToAssociation<Self, Right>)
        -> BelongsToJoinedRequest<Self, Right>
    {
        return all().joined(with: association)
    }
}
