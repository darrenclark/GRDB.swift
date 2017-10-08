public struct HasOneThroughIncludingRequest<MiddleAssociation, RightAssociation> where
    MiddleAssociation: AssociationToOneNonOptional,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: AssociationToOneNonOptional,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
{
    var leftRequest: QueryInterfaceRequest<MiddleAssociation.LeftAssociated>
    let association: HasOneThroughAssociation<MiddleAssociation, RightAssociation>
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasOneThroughIncludingRequest : RequestDerivableWrapper {
    public typealias WrappedRequest = QueryInterfaceRequest<MiddleAssociation.LeftAssociated>
    
    public func mapRequest(_ transform: (QueryInterfaceRequest<MiddleAssociation.LeftAssociated>) -> (QueryInterfaceRequest<MiddleAssociation.LeftAssociated>)) -> HasOneThroughIncludingRequest {
        return HasOneThroughIncludingRequest(leftRequest: transform(leftRequest), association: association)
    }
}

extension HasOneThroughIncludingRequest : TypedRequest {
    public typealias RowDecoder = JoinedPair<MiddleAssociation.LeftAssociated, RightAssociation.RightAssociated>
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        // Qualify queries
        var leftQualifier = SQLSourceQualifier()
        var middleQualifier = SQLSourceQualifier()
        var rightQualifier = SQLSourceQualifier()
        let leftQuery = leftRequest.query.qualified(by: &leftQualifier)
        let middleQuery = association.middleAssociation.rightRequest.query.qualified(by: &middleQualifier)
        let rightQuery = association.rightAssociation.rightRequest.query.qualified(by: &rightQualifier)
        try [leftQualifier, middleQualifier, rightQualifier].resolveAmbiguities()
        
        // SELECT left.*, right.*
        let joinedSelection = leftQuery.selection + rightQuery.selection
        
        // ... FROM left JOIN middle JOIN right
        let joinedSource = try leftQuery.source.join(
            .inner,
            on: association.middleAssociation.mapping(db),
            and: middleQuery.whereExpression,
            to: middleQuery.source.join(
                .inner,
                on: association.rightAssociation.mapping(db),
                and: rightQuery.whereExpression,
                to: rightQuery.source))
        
        // ORDER BY left.***, right.***
        let joinedOrderings = leftQuery.queryOrderings + rightQuery.queryOrderings
        
        // Define row scopes
        let leftCount = try leftQuery.numberOfColumns(db)
        let rightCount = try rightQuery.numberOfColumns(db)
        let joinedAdapter = ScopeAdapter([
            // Left columns start at index 0
            RowDecoder.leftScope: RangeRowAdapter(0..<leftCount),
            // Right columns start after left columns
            RowDecoder.rightScope: RangeRowAdapter(leftCount..<(leftCount + rightCount))])
        
        return try QueryInterfaceSelectQueryDefinition(
            select: joinedSelection,
            isDistinct: leftQuery.isDistinct,
            from: joinedSource,
            filter: leftQuery.whereExpression,
            groupBy: leftQuery.groupByExpressions,
            orderBy: joinedOrderings,
            isReversed: false,
            having: leftQuery.havingExpression,
            limit: leftQuery.limit)
            .adapted(joinedAdapter)
            .prepare(db)
    }
}

extension QueryInterfaceRequest where RowDecoder: TableMapping {
    public func including<MiddleAssociation, RightAssociation>(_ association: HasOneThroughAssociation<MiddleAssociation, RightAssociation>)
        -> HasOneThroughIncludingRequest<MiddleAssociation, RightAssociation>
        where MiddleAssociation.LeftAssociated == RowDecoder
    {
        return HasOneThroughIncludingRequest(leftRequest: self, association: association)
    }
}

extension TableMapping {
    public static func including<MiddleAssociation, RightAssociation>(_ association: HasOneThroughAssociation<MiddleAssociation, RightAssociation>)
        -> HasOneThroughIncludingRequest<MiddleAssociation, RightAssociation>
        where MiddleAssociation.LeftAssociated == Self
    {
        return all().including(association)
    }
}
