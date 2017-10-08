public struct HasManyAnnotationPredicateRequest<Left, Right, Annotation> where
    Left: TableMapping,
    Right: TableMapping
{
    public typealias WrappedRequest = QueryInterfaceRequest<Left>
    
    var leftRequest: WrappedRequest
    let annotationPredicate: HasManyAnnotationPredicate<Left, Right, Annotation>
}

extension HasManyAnnotationPredicateRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasManyAnnotationPredicateRequest {
        return HasManyAnnotationPredicateRequest(
            leftRequest: transform(leftRequest),
            annotationPredicate: annotationPredicate)
    }
}

extension HasManyAnnotationPredicateRequest : TypedRequest {
    public typealias RowDecoder = Left
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        // Qualify queries
        var leftQualifier = SQLSourceQualifier()
        var rightQualifier = SQLSourceQualifier()
        let leftQuery = leftRequest.query.qualified(by: &leftQualifier)
        let rightQuery = annotationPredicate.annotation.association.rightRequest.query.qualified(by: &rightQualifier)
        try [leftQualifier, rightQualifier].resolveAmbiguities()
        
        // ... FROM left LEFT JOIN right
        let joinedSource = try leftQuery.source.join(
            .left,
            on: annotationPredicate.annotation.association.mapping(db),
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
        
        // Having: HAVING annotationExpression
        let rightHavingExpression = try annotationPredicate.predicate(annotationPredicate.annotation.expression(db)).qualified(by: rightQualifier)
        let joinedHavingExpression = (leftQuery.havingExpression.map { rightHavingExpression && $0 } ?? rightHavingExpression).qualified(by: rightQualifier)
        
        return try QueryInterfaceSelectQueryDefinition(
            select: leftQuery.selection,
            isDistinct: leftQuery.isDistinct,   // TODO: test
            from: joinedSource,
            filter: leftQuery.whereExpression,  // TODO: test
            groupBy: joinedGroupByExpressions,
            orderBy: leftQuery.orderings,       // TODO: test
            isReversed: leftQuery.isReversed,   // TODO: test
            having: joinedHavingExpression,
            limit: leftQuery.limit)             // TODO: test
            .prepare(db)
    }
}

extension QueryInterfaceRequest where RowDecoder: TableMapping {
    public func filter<Right, Annotation>(_ annotationPredicate: HasManyAnnotationPredicate<RowDecoder, Right, Annotation>)
        -> HasManyAnnotationPredicateRequest<RowDecoder, Right, Annotation>
    {
        return HasManyAnnotationPredicateRequest(leftRequest: self, annotationPredicate: annotationPredicate)
    }
}

extension TableMapping {
    public static func filter<Right, Annotation>(_ annotationPredicate: HasManyAnnotationPredicate<Self, Right, Annotation>)
        -> HasManyAnnotationPredicateRequest<Self, Right, Annotation>
    {
        return all().filter(annotationPredicate)
    }
}
