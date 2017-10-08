public struct HasManyThroughRequest<MiddleAssociation, RightAssociation> where
    MiddleAssociation: Association,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: Association,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated,
    MiddleAssociation.LeftAssociated: MutablePersistable
{
    let record: MiddleAssociation.LeftAssociated
    let association: HasManyThroughAssociation<MiddleAssociation, RightAssociation>
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasManyThroughRequest : RequestDerivableWrapper {
    public typealias WrappedRequest = RightAssociation.WrappedRequest
    
    public func mapRequest(_ transform: (WrappedRequest) -> WrappedRequest) -> HasManyThroughRequest {
        return HasManyThroughRequest(
            record: record,
            association: association.mapRequest(transform))
    }
}

extension HasManyThroughRequest : TypedRequest {
    public typealias RowDecoder = RightAssociation.RightAssociated
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        var middleQualifier = SQLSourceQualifier()
        var rightQualifier = SQLSourceQualifier()
        
        // SELECT * FROM middle ... -> SELECT middle.* FROM middle WHERE middle.leftId = left.id ...
        let middleMapping = try association.middleAssociation.mapping(db)
        let container = PersistenceContainer(record)
        let rowValue = RowValue(middleMapping.map { container[caseInsensitive: $0.left]?.databaseValue ?? .null })
        // TODO: when rowValue contains NULL, there is no point building any statement 
        let middleQuery = association.middleAssociation.rightRequest
            .filter(middleMapping.map { Column($0.right) } == rowValue)
            .query.qualified(by: &middleQualifier)
        
        // SELECT * FROM right ... -> SELECT right.* FROM right ...
        let rightQuery = association.rightAssociation.rightRequest.query.qualified(by: &rightQualifier)
        
        // ... FROM right JOIN middle
        let joinedSource = try rightQuery.source.join(
            .inner,
            on: association.rightAssociation.reversedMapping(db),
            and: middleQuery.whereExpression,
            to: middleQuery.source)
        
        // ORDER BY right.***, middle.***
        let joinedOrderings = rightQuery.queryOrderings + middleQuery.queryOrderings
        
        return try QueryInterfaceSelectQueryDefinition(
            select: rightQuery.selection,
            isDistinct: rightQuery.isDistinct,
            from: joinedSource,
            filter: rightQuery.whereExpression,
            groupBy: rightQuery.groupByExpressions,
            orderBy: joinedOrderings,
            isReversed: false,
            having: rightQuery.havingExpression,
            limit: rightQuery.limit)
            .prepare(db)
    }
}

extension HasManyThroughAssociation where MiddleAssociation.LeftAssociated: MutablePersistable {
    func request(from record: MiddleAssociation.LeftAssociated) -> HasManyThroughRequest<MiddleAssociation, RightAssociation> {
        return HasManyThroughRequest(record: record, association: self)
    }
}

extension MutablePersistable {
    public func request<MiddleAssociation, RightAssociation>(_ association: HasManyThroughAssociation<MiddleAssociation, RightAssociation>)
        -> HasManyThroughRequest<MiddleAssociation, RightAssociation>
        where MiddleAssociation.LeftAssociated == Self
    {
        return association.request(from: self)
    }
    
    public func fetchCursor<MiddleAssociation, RightAssociation>(_ db: Database, _ association: HasManyThroughAssociation<MiddleAssociation, RightAssociation>) throws
        -> RecordCursor<RightAssociation.RightAssociated>
        where
        MiddleAssociation.LeftAssociated == Self
    {
        return try association.request(from: self).fetchCursor(db)
    }
    
    public func fetchAll<MiddleAssociation, RightAssociation>(_ db: Database, _ association: HasManyThroughAssociation<MiddleAssociation, RightAssociation>) throws
        -> [RightAssociation.RightAssociated]
        where
        MiddleAssociation.LeftAssociated == Self,
        RightAssociation.RightAssociated: RowConvertible
    {
        return try association.request(from: self).fetchAll(db)
    }
    
    public func fetchOne<MiddleAssociation, RightAssociation>(_ db: Database, _ association: HasManyThroughAssociation<MiddleAssociation, RightAssociation>) throws
        -> RightAssociation.RightAssociated?
        where
        MiddleAssociation.LeftAssociated == Self,
        RightAssociation.RightAssociated: RowConvertible
    {
        return try association.request(from: self).fetchOne(db)
    }
}
