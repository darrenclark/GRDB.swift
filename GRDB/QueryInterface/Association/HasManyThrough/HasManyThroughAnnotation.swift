public struct HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation> where
    MiddleAssociation: Association,
    RightAssociation: RequestDerivableWrapper, // TODO: Remove once SE-0143 is implemented
    RightAssociation: Association,
    MiddleAssociation.RightAssociated == RightAssociation.LeftAssociated
{
    let association: HasManyThroughAssociation<MiddleAssociation, RightAssociation>
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

    public func aliased(_ alias: String) -> HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Annotation> {
        return HasManyThroughAnnotation(
            association: association,
            alias: alias,
            expression: expression)
    }
}

extension HasManyThroughAssociation {
    public var count: HasManyThroughAnnotation<MiddleAssociation, RightAssociation, Int> {
        // SELECT left.*, COUNT(right.*) FROM left LEFT JOIN middle LEFT JOIN right ...
        guard let rightTable = rightAssociation.rightRequest.query.source.tableName else {
            fatalError("Can't count tableless query")
        }
        return HasManyThroughAnnotation(
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
    
    public var isEmpty: HasManyThroughAnnotationPredicate<MiddleAssociation, RightAssociation, Int> {
        return count == 0
    }
}
