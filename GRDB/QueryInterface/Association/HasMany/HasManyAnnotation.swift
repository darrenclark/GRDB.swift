public struct HasManyAnnotation<Left, Right, Annotation> where
    Left: TableMapping,
    Right: TableMapping
{
    let association: HasManyAssociation<Left, Right>
    let expression: (Database) throws -> SQLExpression
}

extension HasManyAssociation {
    public var count: HasManyAnnotation<Left, Right, Int> {
        // SELECT left.*, COUNT(right.*) FROM left LEFT JOIN right ...
        guard let rightTable = rightRequest.query.source.tableName else {
            fatalError("Can't count tableless query")
        }
        return HasManyAnnotation(
            association: self,
            expression: { db in
                let primaryKey = try db.primaryKey(rightTable)
                guard primaryKey.columns.count == 1 else {
                    fatalError("Not implemented: count table with compound primary key")
                }
                return SQLExpressionCount(Column(primaryKey.columns[0]))
        })
    }
    
    public var isEmpty: HasManyAnnotationPredicate<Left, Right, Int> {
        return count == 0
    }
}
