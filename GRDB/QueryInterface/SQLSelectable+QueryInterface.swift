// MARK: - AllColumns

/// AllColumns is the `*` in `SELECT *`.
///
/// You use AllColumns in your custom implementation of
/// TableMapping.databaseSelection.
///
/// For example:
///
///     struct Player : TableMapping {
///         static var databaseTableName = "players"
///         static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
///     }
///
///     // SELECT *, rowid FROM players
///     let request = Player.all()
public struct AllColumns {
    let qualifier: SQLSourceQualifier?
    
    init(qualifier: SQLSourceQualifier) {
        self.qualifier = qualifier
    }
    
    /// TODO
    public init() {
        self.qualifier = nil
    }
}

extension AllColumns : SQLSelectable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        if let qualifiedName = qualifier?.qualifiedName {
            return "\(qualifiedName.quotedDatabaseIdentifier).*"
        } else {
            return "*"
        }
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func countedSQL(_ arguments: inout StatementArguments?) -> String {
        GRDBPrecondition(qualifier == nil, "Not implemented")
        return "*"
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func count(distinct: Bool) -> SQLCount? {
        GRDBPrecondition(qualifier == nil, "Not implemented")
        
        // SELECT DISTINCT * FROM tableName ...
        guard !distinct else {
            return nil
        }
        
        // SELECT * FROM tableName ...
        // ->
        // SELECT COUNT(*) FROM tableName ...
        return .all
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func numberOfColumns(_ db: Database) throws -> Int {
        guard let tableName = qualifier?.tableName else {
            fatalError("GRDB bug: can't count number of columns in unknown table")
        }
        return try db.columnCount(in: tableName)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func qualified(by qualifier: SQLSourceQualifier) -> AllColumns {
        if self.qualifier == nil {
            return AllColumns(qualifier: qualifier)
        } else {
            return self
        }
    }
}


// MARK: - SQLAliasedExpression

struct SQLAliasedExpression : SQLSelectable {
    let expression: SQLExpression
    let alias: String
    
    init(_ expression: SQLExpression, alias: String) {
        self.expression = expression
        self.alias = alias
    }
    
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return expression.resultColumnSQL(&arguments) + " AS " + alias.quotedDatabaseIdentifier
    }
    
    func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return expression.countedSQL(&arguments)
    }
    
    func count(distinct: Bool) -> SQLCount? {
        return expression.count(distinct: distinct)
    }
    
    func qualified(by qualifier: SQLSourceQualifier) -> SQLAliasedExpression {
        return SQLAliasedExpression(expression.qualified(by: qualifier), alias: alias)
    }
    
    func numberOfColumns(_ db: Database) throws -> Int {
        return 1
    }
}
