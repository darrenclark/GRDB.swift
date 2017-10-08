public struct HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation> where
    MiddleAssociation: Association,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: Association,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
{
    let association: HasManyThroughAssociation<MiddleAssociation, RightAssociation>
    let expression: (Database) throws -> SQLExpression
}

extension HasManyThroughAssociation {
    public var count: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Int> {
        // SELECT left.*, COUNT(right.*) FROM left LEFT JOIN middle LEFT JOIN right ...
        guard let rightTable = rightAssociation.rightRequest.query.source.tableName else {
            fatalError("Can't count tableless query")
        }
        return HasManyThroughAnnotation(
            association: self,
            expression: { db in
                let primaryKey = try db.primaryKey(rightTable)
                guard primaryKey.columns.count == 1 else {
                    fatalError("Not implemented: count table with compound primary key")
                }
                return SQLExpressionCount(Column(primaryKey.columns[0]))
        })
    }
    
    public var isEmpty: HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Int> {
        return count == 0
    }
}
