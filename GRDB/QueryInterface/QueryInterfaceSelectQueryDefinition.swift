// MARK: - QueryInterfaceSelectQueryDefinition

struct QueryInterfaceSelectQueryDefinition {
    var selection: [SQLSelectable]
    var isDistinct: Bool
    var source: SQLSource
    var whereExpression: SQLExpression?
    var groupByExpressions: [SQLExpression]
    var orderings: [SQLOrderingTerm]
    var isReversed: Bool
    var havingExpression: SQLExpression?
    var limit: SQLLimit?
    
    init(
        select selection: [SQLSelectable],
        isDistinct: Bool = false,
        from source: SQLSource,
        filter whereExpression: SQLExpression? = nil,
        groupBy groupByExpressions: [SQLExpression] = [],
        orderBy orderings: [SQLOrderingTerm] = [],
        isReversed: Bool = false,
        having havingExpression: SQLExpression? = nil,
        limit: SQLLimit? = nil)
    {
        self.selection = selection
        self.isDistinct = isDistinct
        self.source = source
        self.whereExpression = whereExpression
        self.groupByExpressions = groupByExpressions
        self.orderings = orderings
        self.isReversed = isReversed
        self.havingExpression = havingExpression
        self.limit = limit
    }
    
    func sql(_ arguments: inout StatementArguments?) -> String {
        var sql = "SELECT"
        
        if isDistinct {
            sql += " DISTINCT"
        }
        
        assert(!selection.isEmpty)
        sql += " " + selection.map { $0.resultColumnSQL(&arguments) }.joined(separator: ", ")
        
        sql += " FROM " + source.sourceSQL(&arguments)
        
        if let whereExpression = whereExpression {
            sql += " WHERE " + whereExpression.expressionSQL(&arguments)
        }
        
        if !groupByExpressions.isEmpty {
            sql += " GROUP BY " + groupByExpressions.map { $0.expressionSQL(&arguments) }.joined(separator: ", ")
        }
        
        if let havingExpression = havingExpression {
            sql += " HAVING " + havingExpression.expressionSQL(&arguments)
        }
        
        let orderings = self.queryOrderings
        if !orderings.isEmpty {
            sql += " ORDER BY " + orderings.map { $0.orderingTermSQL(&arguments) }.joined(separator: ", ")
        }
        
        if let limit = limit {
            sql += " LIMIT " + limit.sql
        }
        
        return sql
    }
    
    func makeDeleteStatement(_ db: Database) throws -> UpdateStatement {
        guard groupByExpressions.isEmpty else {
            // Programmer error
            fatalError("Can't delete query with GROUP BY expression")
        }
        
        guard havingExpression == nil else {
            // Programmer error
            fatalError("Can't delete query with GROUP BY expression")
        }
        
        var sql = "DELETE"
        var arguments: StatementArguments? = StatementArguments()
        
        sql += " FROM " + source.sourceSQL(&arguments)
        
        if let whereExpression = whereExpression {
            sql += " WHERE " + whereExpression.expressionSQL(&arguments)
        }
        
        if let limit = limit {
            let orderings = self.queryOrderings
            if !orderings.isEmpty {
                sql += " ORDER BY " + orderings.map { $0.orderingTermSQL(&arguments) }.joined(separator: ", ")
            }
            
            if Database.sqliteCompileOptions.contains("ENABLE_UPDATE_DELETE_LIMIT") {
                sql += " LIMIT " + limit.sql
            } else {
                fatalError("Can't delete query with limit")
            }
        }
        
        let statement = try db.makeUpdateStatement(sql)
        statement.arguments = arguments!
        return statement
    }
    
    func numberOfColumns(_ db: Database) throws -> Int {
        return try selection.reduce(0) { try $0 + $1.numberOfColumns(db) }
    }
    
    var queryOrderings: [SQLOrderingTerm] {
        if isReversed {
            if orderings.isEmpty {
                // https://www.sqlite.org/lang_createtable.html#rowid
                //
                // > The rowid value can be accessed using one of the special
                // > case-independent names "rowid", "oid", or "_rowid_" in
                // > place of a column name. If a table contains a user defined
                // > column named "rowid", "oid" or "_rowid_", then that name
                // > always refers the explicitly declared column and cannot be
                // > used to retrieve the integer rowid value.
                //
                // Here we assume that rowid is not a custom column.
                // TODO: support for user-defined rowid column.
                // TODO: support for WITHOUT ROWID tables.
                return [Column.rowID.desc]
            } else {
                return orderings.map { $0.reversed }
            }
        } else {
            return orderings
        }
    }
    
    /// Remove ordering
    var unordered: QueryInterfaceSelectQueryDefinition {
        var query = self
        query.isReversed = false
        query.orderings = []
        return query
    }
    
    var qualifier: SQLSourceQualifier? {
        return source.qualifier
    }
    
    // Apply eventual source qualifier to all unqualified query components
    var eventuallyQualifiedQuery: QueryInterfaceSelectQueryDefinition {
        if qualifier != nil {
            var qualifier = SQLSourceQualifier()
            return qualified(by: &qualifier)
        } else {
            return self
        }
    }
    
    // Input: SELECT * FROM foo ORDER BY bar
    // Output: SELECT foo.* FROM foo ORDER BY foo.bar
    func qualified(by qualifier: inout SQLSourceQualifier) -> QueryInterfaceSelectQueryDefinition {
        let qualifiedSource = source.qualified(by: &qualifier)
        let qualifiedSelection = selection.map { $0.qualified(by: qualifier) }
        let qualifiedFilter = whereExpression.map { $0.qualified(by: qualifier) }
        let qualifiedGroupByExpressions = groupByExpressions.map { $0.qualified(by: qualifier) }
        let qualifiedOrderings = orderings.map { $0.qualified(by: qualifier) }
        let qualifiedHavingExpression = havingExpression?.qualified(by: qualifier)
        
        return QueryInterfaceSelectQueryDefinition(
            select: qualifiedSelection,
            isDistinct: isDistinct,
            from: qualifiedSource,
            filter: qualifiedFilter,
            groupBy: qualifiedGroupByExpressions,
            orderBy: qualifiedOrderings,
            isReversed: isReversed,
            having: qualifiedHavingExpression,
            limit: limit)
    }
}

extension QueryInterfaceSelectQueryDefinition : Request {
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        var arguments: StatementArguments? = StatementArguments()
        let sql = eventuallyQualifiedQuery.sql(&arguments)
        let statement = try db.makeSelectStatement(sql)
        try statement.setArgumentsWithValidation(arguments!)
        return (statement, nil)
    }
    
    func fetchCount(_ db: Database) throws -> Int {
        return try Int.fetchOne(db, countQuery)!
    }
    
    private var countQuery: QueryInterfaceSelectQueryDefinition {
        guard groupByExpressions.isEmpty && limit == nil else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            return trivialCountQuery
        }
        
        guard source.isTable else {
            // SELECT ... FROM (something which is not a table)
            return trivialCountQuery
        }
        
        assert(!selection.isEmpty)
        if selection.count == 1 {
            guard let count = selection[0].count(distinct: isDistinct) else {
                return trivialCountQuery
            }
            var countQuery = unordered
            countQuery.isDistinct = false
            countQuery.selection = [count.sqlSelectable]
            return countQuery
        } else {
            // SELECT [DISTINCT] expr1, expr2, ... FROM tableName ...
            
            guard !isDistinct else {
                return trivialCountQuery
            }
            
            // SELECT expr1, expr2, ... FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            var countQuery = unordered
            countQuery.selection = [SQLExpressionCount(AllColumns())]
            return countQuery
        }
    }
    
    // SELECT COUNT(*) FROM (self)
    private var trivialCountQuery: QueryInterfaceSelectQueryDefinition {
        return QueryInterfaceSelectQueryDefinition(
            select: [SQLExpressionCount(AllColumns())],
            from: .query(unordered))
    }
}

enum SQLJoinOperator : String {
    case inner = "JOIN"
    case left = "LEFT JOIN"
}

struct SQLSource {
    private enum Origin {
        case table(tableName: String, qualifier: SQLSourceQualifier?)
        indirect case query(QueryInterfaceSelectQueryDefinition)
        
        var qualifier: SQLSourceQualifier? {
            switch self {
            case .table(_, let qualifier):
                return qualifier
            case .query(let query):
                return query.qualifier
            }
        }
        
        func sql(_ arguments: inout StatementArguments?) -> String {
            switch self {
            case .table(let tableName, let qualifier):
                if let alias = qualifier?.alias, alias != tableName {
                    return "\(tableName.quotedDatabaseIdentifier) \(alias.quotedDatabaseIdentifier)"
                } else {
                    return "\(tableName.quotedDatabaseIdentifier)"
                }
            case .query(let query):
                return "(\(query.sql(&arguments)))"
            }
        }
        
        func qualified(by qualifier: inout SQLSourceQualifier) -> Origin {
            switch self {
            case .table(let tableName, let oldQualifier):
                if let oldQualifier = oldQualifier {
                    qualifier = oldQualifier
                    return self
                } else {
                    qualifier.tableName = tableName
                    return .table(
                        tableName: tableName,
                        qualifier: qualifier)
                }
            case .query(let query):
                return .query(query.qualified(by: &qualifier))
            }
        }
    }
    
    private struct Join {
        let joinOp: SQLJoinOperator
        let tableName: String
        let qualifier: SQLSourceQualifier?
        let mapping: [(left: Column, right: String)]
        let onExpression: SQLExpression?
        let joins: [Join]
        
        func sql(_ arguments: inout StatementArguments?) -> String {
            var sql = joinOp.rawValue
            
            if let alias = qualifier?.alias, alias != tableName {
                sql += " \(tableName.quotedDatabaseIdentifier) \(alias.quotedDatabaseIdentifier)"
            } else {
                sql += " \(tableName.quotedDatabaseIdentifier)"
            }
            
            var onClauses: [SQLExpression]
            if let qualifier = qualifier {
                // right.leftId == left.id
                onClauses = mapping.map { arrow in
                    Column(arrow.right).qualified(by: qualifier) == arrow.left
                }
            } else {
                // leftId == left.id
                onClauses = mapping.map { arrow in
                    Column(arrow.right) == arrow.left
                }
            }
            
            if let onExpression = onExpression {
                // right.name = 'foo'
                onClauses.append(onExpression)
            }
            
            if let first = onClauses.first {
                let onClause = onClauses.suffix(from: 1).reduce(first, &&)
                sql += " ON " + onClause.expressionSQL(&arguments)
            }
            
            return ([sql] + joins.map { $0.sql(&arguments) }).joined(separator: " ")
        }
    }
    
    private let origin: Origin
    private let joins: [Join]
    
    /// True if source is a simple table
    var isTable: Bool {
        switch origin {
        case .table:
            return joins.isEmpty
        default:
            return false
        }
    }
    
    /// An alias or an actual table name
    var qualifiedName: String? {
        switch origin {
        case .table(let tableName, let qualifier):
            return qualifier?.qualifiedName ?? tableName
        case .query(let query):
            return query.source.qualifiedName
        }
    }
    
    /// An actual table name, not an alias
    var tableName: String? {
        switch origin {
        case .table(let tableName, _):
            return tableName
        case .query(let query):
            return query.source.tableName
        }
    }
    
    var qualifier: SQLSourceQualifier? {
        return origin.qualifier
    }
    
    static func table(_ tableName: String) -> SQLSource {
        return SQLSource(
            origin: .table(tableName: tableName, qualifier: nil),
            joins: [])
    }
    
    static func query(_ query: QueryInterfaceSelectQueryDefinition) -> SQLSource {
        return SQLSource(
            origin: .query(query),
            joins: [])
    }
    
    func join(
        _ joinOp: SQLJoinOperator,
        on mapping: [(left: String, right: String)],
        and onExpression: SQLExpression?,
        to right: SQLSource) -> SQLSource
    {
        guard case .table(_, let leftQualifier) = origin else { fatalError() }
        guard case .table(let rightTableName, let rightQualifier) = right.origin else { fatalError() }
        
        var joinMapping: [(left: Column, right: String)]
        if let leftQualifier = leftQualifier {
            joinMapping = mapping.map { arrow in
                (left: Column(arrow.left).qualified(by: leftQualifier), right: arrow.right)
            }
        } else {
            joinMapping = mapping.map { arrow in
                (left: Column(arrow.left), right: arrow.right)
            }
        }
        
        let newJoin = Join(
            joinOp: joinOp,
            tableName: rightTableName,
            qualifier: rightQualifier,
            mapping: joinMapping,
            onExpression: onExpression,
            joins: right.joins)
        
        return SQLSource(
            origin: origin,
            joins: joins + [newJoin])
    }
    
    func sourceSQL(_ arguments: inout StatementArguments?) -> String {
        return ([origin.sql(&arguments)] + joins.map { $0.sql(&arguments) }).joined(separator: " ")
    }
    
    func qualified(by qualifier: inout SQLSourceQualifier) -> SQLSource {
        return SQLSource(origin: origin.qualified(by: &qualifier), joins: joins)
    }
}

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
public class SQLSourceQualifier {
    var tableName: String?
    var alias: String?
    var userProvided = false
    
    init() {
        self.tableName = nil
        self.alias = nil
    }
    
    var qualifiedName: String? {
        return alias ?? tableName
    }
}

extension Array where Iterator.Element == SQLSourceQualifier {
    func resolveAmbiguities() throws {
        var groups: [String: [SQLSourceQualifier]] = [:]
        for qualifier in self {
            let qualifiedName = qualifier.qualifiedName! // qualifier must have been given a table name by now
            let lowercaseName = qualifiedName.lowercased()
            // TODO: enhance once SE-0165 has shipped
            if groups[lowercaseName] != nil {
                groups[lowercaseName]!.append(qualifier)
            } else {
                groups[lowercaseName] = [qualifier]
            }
        }
        
        var uniqueNames: Set<String> = []
        var ambiguousGroups: [[SQLSourceQualifier]] = []
        
        for (lowercaseName, group) in groups {
            if group.count > 1 {
                if group.filter({ $0.userProvided }).count >= 2 {
                    throw DatabaseError(message: "ambiguous alias: \(group[0].qualifiedName!)")
                }
                ambiguousGroups.append(group)
            } else {
                uniqueNames.insert(lowercaseName)
            }
        }
        
        for group in ambiguousGroups {
            var index = 1
            for qualifier in group {
                if qualifier.userProvided { continue }
                let radical = qualifier.qualifiedName!.databaseQualifierRadical
                var alias: String
                repeat {
                    alias = "\(radical)\(index)"
                    index += 1
                } while uniqueNames.contains(alias.lowercased())
                uniqueNames.insert(alias.lowercased())
                qualifier.alias = alias
            }
        }
    }
}

extension String {
    /// "foo12" => "foo"
    var databaseQualifierRadical: String {
        let digits: ClosedRange<Character> = "0"..."9"
        let radicalEndIndex = characters            // "foo12"
            .reversed()                             // "21oof"
            .prefix(while: { digits.contains($0) }) // "21"
            .endIndex                               // reversed(3)
            .base                                   // 3
        return String(characters.prefix(upTo: radicalEndIndex))
    }
}

struct SQLLimit {
    let limit: Int
    let offset: Int?
    
    var sql: String {
        if let offset = offset {
            return "\(limit) OFFSET \(offset)"
        } else {
            return "\(limit)"
        }
    }
}

extension SQLCount {
    var sqlSelectable: SQLSelectable {
        switch self {
        case .all:
            return SQLExpressionCount(AllColumns())
        case .distinct(let expression):
            return SQLExpressionCountDistinct(expression)
        }
    }
}
