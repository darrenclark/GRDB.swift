public struct HasManyThroughAnnotationPredicateRequest<MiddleAssociation, RightAssociation, Annotation> where
    MiddleAssociation: Association,
    RightAssociation: Association,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation.LeftAssociated == MiddleAssociation.RightAssociated
{
    public typealias WrappedRequest = QueryInterfaceRequest<MiddleAssociation.LeftAssociated>
    
    var leftRequest: WrappedRequest
    let annotationPredicate: HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation>
}

// TODO: Derive conditional conformance to RequestDerivableWrapper once once SE-0143 is implemented
extension HasManyThroughAnnotationPredicateRequest : RequestDerivableWrapper {
    public func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> HasManyThroughAnnotationPredicateRequest {
        return HasManyThroughAnnotationPredicateRequest(
            leftRequest: transform(leftRequest),
            annotationPredicate: annotationPredicate)
    }
}

extension HasManyThroughAnnotationPredicateRequest : TypedRequest {
    public typealias RowDecoder = MiddleAssociation.LeftAssociated
    
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        // Qualify queries
        var leftQualifier = SQLSourceQualifier()
        var middleQualifier = SQLSourceQualifier()
        var rightQualifier = SQLSourceQualifier()
        let leftQuery = leftRequest.query.qualified(by: &leftQualifier)
        let middleQuery = annotationPredicate.annotation.association.middleAssociation.rightRequest.query.qualified(by: &middleQualifier)
        let rightQuery = annotationPredicate.annotation.association.rightAssociation.rightRequest.query.qualified(by: &rightQualifier)
        try [leftQualifier, middleQualifier, rightQualifier].resolveAmbiguities()
        
        // ... FROM left LEFT JOIN middle LEFT JOIN right
        let joinedSource = try leftQuery.source.join(
            .left,
            on: annotationPredicate.annotation.association.middleAssociation.mapping(db),
            and: middleQuery.whereExpression,
            to: middleQuery.source.join(
                .left,
                on: annotationPredicate.annotation.association.rightAssociation.mapping(db),
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
    public func filter<MiddleAssociation, RightAssociation, Annotation>(_ annotationPredicate: HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation>)
        -> HasManyThroughAnnotationPredicateRequest<MiddleAssociation, RightAssociation, Annotation>
        where MiddleAssociation.LeftAssociated == RowDecoder
    {
        return HasManyThroughAnnotationPredicateRequest(leftRequest: self, annotationPredicate: annotationPredicate)
    }
}

extension TableMapping {
    public static func filter<MiddleAssociation, RightAssociation, Annotation>(_ annotationPredicate: HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Annotation>)
        -> HasManyThroughAnnotationPredicateRequest<MiddleAssociation, RightAssociation, Annotation>
        where MiddleAssociation.LeftAssociated == Self
    {
        return all().filter(annotationPredicate)
    }
}
