// TODO: consider only using the same request class for optional and mandatory associations
public struct HasOneOptionalThroughRequest<MiddleAssociation, RightAssociation> where
    MiddleAssociation: AssociationToOne,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: AssociationToOne,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated,
    MiddleAssociation.LeftAssociated: MutablePersistable
{
    let record: MiddleAssociation.LeftAssociated
    let association: HasOneOptionalThroughAssociation<MiddleAssociation, RightAssociation>
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasOneOptionalThroughRequest : RequestDerivableWrapper {
    public typealias WrappedRequest = RightAssociation.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasOneOptionalThroughRequest {
        return HasOneOptionalThroughRequest(record: record, association: association.mapRequest(transform))
    }
}

extension HasOneOptionalThroughRequest : TypedRequest {
    public typealias RowDecoder = RightAssociation.RightAssociated
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        let middleMapping = try association.middleAssociation.mapping(db)
        let container = PersistenceContainer(record)
        let rowValue = RowValue(middleMapping.map { container[caseInsensitive: $0.left]?.databaseValue ?? .null })
        let rightRequest = association.middleAssociation.rightRequest
            .filter(middleMapping.map { Column($0.right) } == rowValue)
        
        // Qualify queries
        var middleQualifier = SQLSourceQualifier()
        var rightQualifier = SQLSourceQualifier()
        let middleQuery = rightRequest.query.qualified(by: &middleQualifier)
        let rightQuery = association.rightAssociation.rightRequest.query.qualified(by: &rightQualifier)
        try [middleQualifier, rightQualifier].resolveAmbiguities()
        
        // ... FROM right JOIN middle
        let joinedSource = try rightQuery.source.join(
            .inner,
            on: association.rightAssociation.reversedMapping(db),
            and: middleQuery.whereExpression,
            to: middleQuery.source)
        
        return try QueryInterfaceSelectQueryDefinition(
            select: rightQuery.selection,
            isDistinct: rightQuery.isDistinct,
            from: joinedSource,
            filter: rightQuery.whereExpression,
            groupBy: rightQuery.groupByExpressions,
            orderBy: rightQuery.orderings,
            isReversed: rightQuery.isReversed,
            having: rightQuery.havingExpression,
            limit: rightQuery.limit)
            .prepare(db)
    }
}

extension HasOneOptionalThroughAssociation where MiddleAssociation.LeftAssociated: MutablePersistable {
    func request(from record: MiddleAssociation.LeftAssociated)
        -> HasOneOptionalThroughRequest<MiddleAssociation, RightAssociation>
    {
        return HasOneOptionalThroughRequest(record: record, association: self)
    }
}

extension MutablePersistable {
    public func request<MiddleAssociation, RightAssociation>(_ association: HasOneOptionalThroughAssociation<MiddleAssociation, RightAssociation>)
        -> HasOneOptionalThroughRequest<MiddleAssociation, RightAssociation>
        where MiddleAssociation.LeftAssociated == Self
    {
        return association.request(from: self)
    }
    
    public func fetchOne<MiddleAssociation, RightAssociation>(_ db: Database, _ association: HasOneOptionalThroughAssociation<MiddleAssociation, RightAssociation>) throws
        -> RightAssociation.RightAssociated?
        where
        MiddleAssociation.LeftAssociated == Self,
        RightAssociation.RightAssociated: RowConvertible
    {
        return try association.request(from: self).fetchOne(db)
    }
}
