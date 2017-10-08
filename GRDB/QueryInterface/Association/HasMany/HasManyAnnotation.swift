public struct HasManyAnnotation<Left, Right, Annotation> where
    Left: TableMapping,
    Right: TableMapping
{
    let association: HasManyAssociation<Left, Right>
    let alias: String?
    let expression: (Database) throws -> SQLExpression
    
    func selection(_ db: Database) throws -> SQLSelectable {
        let expression = try self.expression(db)
        if let alias = alias {
            return expression.aliased(alias)
        } else {
            return expression
        }
    }
    
    public func aliased(_ alias: String) -> HasManyAnnotation<Left, Right, Annotation> {
        return HasManyAnnotation(
            association: association,
            alias: alias,
            expression: expression)
    }
}

extension HasManyAssociation {
    public var count: HasManyAnnotation<Left, Right, Int> {
        // SELECT left.*, COUNT(right.*) FROM left LEFT JOIN right ...
        guard let rightTable = rightRequest.query.source.tableName else {
            fatalError("Can't count tableless query")
        }
        return HasManyAnnotation(
            association: self,
            alias: nil,
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
