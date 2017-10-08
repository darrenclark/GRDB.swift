// TODO: consider only using left joins for this kind of query
public struct HasOneOptionalThroughJoinedRequest<MiddleAssociation, RightAssociation> where
    MiddleAssociation: AssociationToOne,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: AssociationToOne,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
{
    public typealias WrappedRequest = QueryInterfaceRequest<MiddleAssociation.LeftAssociated>
    
    var leftRequest: WrappedRequest
    let association: HasOneOptionalThroughAssociation<MiddleAssociation, RightAssociation>
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasOneOptionalThroughJoinedRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasOneOptionalThroughJoinedRequest {
        return HasOneOptionalThroughJoinedRequest(leftRequest: transform(leftRequest), association: association)
    }
}

extension HasOneOptionalThroughJoinedRequest : TypedRequest {
    public typealias RowDecoder = MiddleAssociation.LeftAssociated
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
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
    public func joined<MiddleAssociation, RightAssociation>(with association: HasOneOptionalThroughAssociation<MiddleAssociation, RightAssociation>)
        -> HasOneOptionalThroughJoinedRequest<MiddleAssociation, RightAssociation>
        where MiddleAssociation.LeftAssociated == RowDecoder
    {
        return HasOneOptionalThroughJoinedRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func joined<MiddleAssociation, RightAssociation>(with association: HasOneOptionalThroughAssociation<MiddleAssociation, RightAssociation>)
        -> HasOneOptionalThroughJoinedRequest<MiddleAssociation, RightAssociation>
        where MiddleAssociation.LeftAssociated == Self
    {
        return all().joined(with: association)
    }
}
