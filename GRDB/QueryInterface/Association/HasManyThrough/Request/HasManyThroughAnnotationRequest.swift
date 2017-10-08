public struct HasManyThroughAnnotationRequest<MiddleAssociation, RightAssociation, Annotation> where
    MiddleAssociation: Association,
    RightAssociation: Association,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation.LeftAssociated == MiddleAssociation.RightAssociated
{
    public typealias WrappedRequest = QueryInterfaceRequest<MiddleAssociation.LeftAssociated>
    
    var leftRequest: WrappedRequest
    let annotation: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasManyThroughAnnotationRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasManyThroughAnnotationRequest {
        return HasManyThroughAnnotationRequest(
            leftRequest: transform(leftRequest),
            annotation: annotation)
    }
}

extension HasManyThroughAnnotationRequest : TypedRequest {
    public typealias RowDecoder = JoinedPair<MiddleAssociation.LeftAssociated, Annotation>
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        // Qualify queries
        var leftQualifier = SQLSourceQualifier()
        var middleQualifier = SQLSourceQualifier()
        var rightQualifier = SQLSourceQualifier()
        let leftQuery = leftRequest.query.qualified(by: &leftQualifier)
        let middleQuery = annotation.association.middleAssociation.rightRequest.query.qualified(by: &middleQualifier)
        let rightQuery = annotation.association.rightAssociation.rightRequest.query.qualified(by: &rightQualifier)
        try [leftQualifier, middleQualifier, rightQualifier].resolveAmbiguities()
        
        // SELECT left.*, right.annotation
        let joinedSelection = try leftQuery.selection + [annotation.expression(db).qualified(by: rightQualifier)]
        
        // ... FROM left LEFT JOIN middle LEFT JOIN right
        let joinedSource = try leftQuery.source.join(
            .left,
            on: annotation.association.middleAssociation.mapping(db),
            and: middleQuery.whereExpression,
            to: middleQuery.source.join(
                .left,
                on: annotation.association.rightAssociation.mapping(db),
                and: rightQuery.whereExpression,
                to: rightQuery.source))
        
        // ... GROUP BY left.id
        guard let leftTableName = leftQuery.source.tableName else {
            fatalError("Can't annotate tableless query")
        }
        let pkColumns = try db.primaryKey(leftTableName)
            .columns
            .map { Column($0).qualified(by: leftQualifier) as SQLExpression }
        guard !pkColumns.isEmpty else {
            fatalError("Can't annotate table without primary key")
        }
        let joinedGroupByExpressions = pkColumns + leftQuery.groupByExpressions
        
        // Define row scopes
        let leftCount = try leftQuery.numberOfColumns(db)
        let rightCount = 1
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
            groupBy: joinedGroupByExpressions,
            orderBy: leftQuery.orderings,
            isReversed: leftQuery.isReversed,
            having: leftQuery.havingExpression,
            limit: leftQuery.limit)
            .adapted(joinedAdapter)
            .prepare(db)
    }
}

extension QueryInterfaceRequest where RowDecoder: TableMapping {
    public func annotated<MiddleAssociation, RightAssociation, Annotation>(with annotation: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>)
        -> HasManyThroughAnnotationRequest<MiddleAssociation, RightAssociation, Annotation>
        where MiddleAssociation.LeftAssociated == RowDecoder
    {
        return HasManyThroughAnnotationRequest(leftRequest: self, annotation: annotation)
    }
}

extension TableMapping {
    public static func annotated<MiddleAssociation, RightAssociation, Annotation>(with annotation: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation>)
        -> HasManyThroughAnnotationRequest<MiddleAssociation, RightAssociation, Annotation>
        where MiddleAssociation.LeftAssociated == Self
    {
        return all().annotated(with: annotation)
    }
}
