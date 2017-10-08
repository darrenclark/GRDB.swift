// TODO: consider only using left joins for this kind of query
public struct HasOneThroughJoinedRequest<MiddleAssociation, RightAssociation> where
    MiddleAssociation: AssociationToOneNonOptional,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: AssociationToOneNonOptional,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
{
    var leftRequest: QueryInterfaceRequest<MiddleAssociation.LeftAssociated>
    let association: HasOneThroughAssociation<MiddleAssociation, RightAssociation>
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasOneThroughJoinedRequest : RequestDerivableWrapper {
    public typealias WrappedRequest = QueryInterfaceRequest<MiddleAssociation.LeftAssociated>
    
    public func mapRequest(_ transform: (QueryInterfaceRequest<MiddleAssociation.LeftAssociated>) -> (QueryInterfaceRequest<MiddleAssociation.LeftAssociated>)) -> HasOneThroughJoinedRequest {
        return HasOneThroughJoinedRequest(leftRequest: transform(leftRequest), association: association)
    }
}

extension HasOneThroughJoinedRequest : TypedRequest {
    public typealias RowDecoder = MiddleAssociation.LeftAssociated
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        // Generates SELECT left.* FROM left LEFT JOIN middle LEFT JOIN right
        //
        // We use LEFT JOIN because:
        //
        // 1. HasOneThroughAssociation assumes the database has a right item for
        //    every left item.
        // 2. Hence JOIN and LEFT JOIN are assumed to produce the same results.
        // 3. If the database happens not to always have a right item for every
        //    left item, using JOIN would miss some left items.
        // 4. Hence we prefer using LEFT JOIN because it does less harm to the
        ///   users who should have used HasOneOptionalThroughAssociation.
        
        // Qualify queries
        var leftQualifier = SQLSourceQualifier()
        var middleQualifier = SQLSourceQualifier()
        var rightQualifier = SQLSourceQualifier()
        let leftQuery = leftRequest.query.qualified(by: &leftQualifier)
        let middleQuery = association.middleAssociation.rightRequest.query.qualified(by: &middleQualifier)
        let rightQuery = association.rightAssociation.rightRequest.query.qualified(by: &rightQualifier)
        try [leftQualifier, middleQualifier, rightQualifier].resolveAmbiguities()
        
        // ... FROM left LEFT JOIN middle LEFT JOIN right
        let joinedSource = try leftQuery.source.join(
            .left,
            on: association.middleAssociation.mapping(db),
            and: middleQuery.whereExpression,
            to: middleQuery.source.join(
                .left,
                on: association.rightAssociation.mapping(db),
                and: rightQuery.whereExpression,
                to: rightQuery.source))
        
        return try QueryInterfaceSelectQueryDefinition(
            select: leftQuery.selection,
            isDistinct: leftQuery.isDistinct,
            from: joinedSource,
            filter: leftQuery.whereExpression,
            groupBy: leftQuery.groupByExpressions,
            orderBy: leftQuery.orderings,
            isReversed: leftQuery.isReversed,
            having: leftQuery.havingExpression,
            limit: leftQuery.limit)
            .prepare(db)
    }
}

extension QueryInterfaceRequest where RowDecoder: TableMapping {
    public func joined<MiddleAssociation, RightAssociation>(with association: HasOneThroughAssociation<MiddleAssociation, RightAssociation>)
        -> HasOneThroughJoinedRequest<MiddleAssociation, RightAssociation>
        where MiddleAssociation.LeftAssociated == RowDecoder
    {
        return HasOneThroughJoinedRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func joined<MiddleAssociation, RightAssociation>(with association: HasOneThroughAssociation<MiddleAssociation, RightAssociation>)
        -> HasOneThroughJoinedRequest<MiddleAssociation, RightAssociation>
        where MiddleAssociation.LeftAssociated == Self
    {
        return all().joined(with: association)
    }
}
