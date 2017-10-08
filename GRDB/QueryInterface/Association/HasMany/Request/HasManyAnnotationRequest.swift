public struct HasManyAnnotationRequest<Left, Right, Annotation> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let annotation: HasManyAnnotation<Left, Right, Annotation>
}

extension HasManyAnnotationRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasManyAnnotationRequest {
        return HasManyAnnotationRequest(
            leftRequest: transform(leftRequest),
            annotation: annotation)
    }
}

extension HasManyAnnotationRequest : TypedRequest {
    public typealias RowDecoder = JoinedPair<Left, Annotation>
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        // Qualify queries
        var leftQualifier = SQLSourceQualifier()
        var rightQualifier = SQLSourceQualifier()
        let leftQuery = leftRequest.query.qualified(by: &leftQualifier)
        let rightQuery = annotation.association.rightRequest.query.qualified(by: &rightQualifier)
        try [leftQualifier, rightQualifier].resolveAmbiguities()

        // SELECT left.*, right.annotation
        let joinedSelection = try leftQuery.selection + [annotation.selection(db).qualified(by: rightQualifier)]
        
        // ... FROM left LEFT JOIN right
        let joinedSource = try leftQuery.source.join(
            .left,
            on: annotation.association.mapping(db),
            and: rightQuery.whereExpression,
            to: rightQuery.source)
        
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
    public func annotated<Right, Annotation>(with annotation: HasManyAnnotation<RowDecoder, Right, Annotation>)
        -> HasManyAnnotationRequest<RowDecoder, Right, Annotation>
    {
        return HasManyAnnotationRequest(leftRequest: self, annotation: annotation)
    }
}

extension TableMapping {
    public static func annotated<Right, Annotation>(with annotation: HasManyAnnotation<Self, Right, Annotation>)
        -> HasManyAnnotationRequest<Self, Right, Annotation>
    {
        return all().annotated(with: annotation)
    }
}
