/// The protocol for joined pairs
public protocol JoinedPairDecoder {
    /// The type that can convert the left part of a database row to a
    /// fetched value
    associatedtype LeftDecoder
    
    /// The type that can convert the right part of a database row to a
    /// fetched value
    associatedtype RightDecoder
}

extension JoinedPairDecoder {
    /// The scope used to consume left part of a database row
    public static var leftScope: String { return "left" }
    
    /// The scope used to consume right part of a database row
    public static var rightScope: String { return "right" }
    
    static func leftRow(_ row: Row) -> Row {
        guard let leftRow = row.scoped(on: leftScope) else {
            fatalError("missing required scope: \(String(reflecting: leftScope))")
        }
        return leftRow
    }
    
    static func rightRow(_ row: Row) -> Row {
        guard let rightRow = row.scoped(on: rightScope) else {
            fatalError("missing required scope: \(String(reflecting: rightScope))")
        }
        return rightRow
    }
}

/// A concrete JoinedPairDecoder
public struct JoinedPair<Left, Right> : JoinedPairDecoder {
    public typealias LeftDecoder = Left
    public typealias RightDecoder = Right
}

extension RowConvertible {
    /// Initializes a record from `row`.
    ///
    /// Returns nil unless the row contains a non-null value.
    init?(leftJoinedRow row: Row) {
        guard row.containsNonNullValue else { return nil }
        self.init(row: row)
    }
}

func prepareJoinedPairRequest(
    _ db: Database,
    left leftQuery: QueryInterfaceSelectQueryDefinition,
    join joinOp: SQLJoinOperator,
    right rightQuery: QueryInterfaceSelectQueryDefinition,
    on mapping: [(left: String, right: String)],
    leftScope: String,
    rightScope: String) throws
    -> (SelectStatement, RowAdapter?)
{
    // Qualify queries
    var leftQualifier = SQLSourceQualifier()
    var rightQualifier = SQLSourceQualifier()
    let leftQuery = leftQuery.qualified(by: &leftQualifier)
    let rightQuery = rightQuery.qualified(by: &rightQualifier)
    try [leftQualifier, rightQualifier].resolveAmbiguities()
    
    // SELECT left.*, right.*
    let joinedSelection = leftQuery.selection + rightQuery.selection
    
    // ... FROM left JOIN right
    let joinedSource = leftQuery.source.join(
        joinOp,
        on: mapping,
        and: rightQuery.whereExpression,
        to: rightQuery.source)
    
    // ORDER BY left.***, right.***
    let joinedOrderings = leftQuery.queryOrderings + rightQuery.queryOrderings
    
    // Define row scopes
    let leftCount = try leftQuery.numberOfColumns(db)
    let rightCount = try rightQuery.numberOfColumns(db)
    let joinedAdapter = ScopeAdapter([
        // Left columns start at index 0
        leftScope: RangeRowAdapter(0..<leftCount),
        // Right columns start after left columns
        rightScope: RangeRowAdapter(leftCount..<(leftCount + rightCount))])
    
    return try QueryInterfaceSelectQueryDefinition(
        select: joinedSelection,
        isDistinct: leftQuery.isDistinct,
        from: joinedSource,
        filter: leftQuery.whereExpression,
        groupBy: leftQuery.groupByExpressions,
        orderBy: joinedOrderings,
        isReversed: false,
        having: leftQuery.havingExpression,
        limit: leftQuery.limit)
        .adapted(joinedAdapter)
        .prepare(db)
}

func prepareJoinRequest(
    _ db: Database,
    left leftQuery: QueryInterfaceSelectQueryDefinition,
    join joinOp: SQLJoinOperator,
    right rightQuery: QueryInterfaceSelectQueryDefinition,
    on mapping: [(left: String, right: String)]) throws
    -> (SelectStatement, RowAdapter?)
{
    // Qualify queries
    var leftQualifier = SQLSourceQualifier()
    var rightQualifier = SQLSourceQualifier()
    let leftQuery = leftQuery.qualified(by: &leftQualifier)
    let rightQuery = rightQuery.qualified(by: &rightQualifier)
    try [leftQualifier, rightQualifier].resolveAmbiguities()
    
    // ... FROM left JOIN right
    let joinedSource = leftQuery.source.join(
        joinOp,
        on: mapping,
        and: rightQuery.whereExpression,
        to: rightQuery.source)
    
    return try QueryInterfaceSelectQueryDefinition(
        select: leftQuery.selection,
        isDistinct: leftQuery.isDistinct,
        from: joinedSource,
        filter: leftQuery.whereExpression,
        groupBy: leftQuery.groupByExpressions,
        orderBy: leftQuery.orderings,
        isReversed: leftQuery.isReversed,
        having: leftQuery.havingExpression,
        limit: leftQuery.limit)
        .prepare(db)
}

// MARK: - Inner Join (RowConvertible, RowConvertible)

extension JoinedPairDecoder where LeftDecoder: RowConvertible, RightDecoder: RowConvertible {
    
    // MARK: Fetching From SelectStatement
    
    static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> MapCursor<RowCursor, (left: LeftDecoder, right: RightDecoder)> {
        return try Row.fetchCursor(statement, arguments: arguments, adapter: adapter).map { row in
            (left: LeftDecoder(row: leftRow(row)), right: RightDecoder(row: rightRow(row)))
        }
    }
    
    static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [(left: LeftDecoder, right: RightDecoder)] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> (left: LeftDecoder, right: RightDecoder)? {
        return try fetchCursor(statement, arguments: arguments, adapter: adapter).next()
    }
}

extension JoinedPairDecoder where LeftDecoder: RowConvertible, RightDecoder: RowConvertible {
    
    // MARK: Fetching From Request
    
    static func fetchCursor(_ db: Database, _ request: Request) throws -> MapCursor<RowCursor, (left: LeftDecoder, right: RightDecoder)> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    static func fetchAll(_ db: Database, _ request: Request) throws -> [(left: LeftDecoder, right: RightDecoder)] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    static func fetchOne(_ db: Database, _ request: Request) throws -> (left: LeftDecoder, right: RightDecoder)? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension TypedRequest where RowDecoder: JoinedPairDecoder, RowDecoder.LeftDecoder: RowConvertible, RowDecoder.RightDecoder: RowConvertible {
    public func fetchCursor(_ db: Database) throws -> MapCursor<RowCursor, (left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder)> {
        return try RowDecoder.fetchCursor(db, self)
    }
    
    public func fetchAll(_ db: Database) throws -> [(left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder)] {
        return try RowDecoder.fetchAll(db, self)
    }
    
    public func fetchOne(_ db: Database) throws -> (left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder)? {
        return try RowDecoder.fetchOne(db, self)
    }
}

// MARK: - Inner Join (RowConvertible, DatabaseValueConvertible)

extension JoinedPairDecoder where LeftDecoder: RowConvertible, RightDecoder: DatabaseValueConvertible {
    
    // MARK: Fetching From SelectStatement
    
    static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> MapCursor<RowCursor, (left: LeftDecoder, right: RightDecoder)> {
        return try Row.fetchCursor(statement, arguments: arguments, adapter: adapter).map { row in
            (left: LeftDecoder(row: leftRow(row)), right: rightRow(row)[0])
        }
    }
    
    static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [(left: LeftDecoder, right: RightDecoder)] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> (left: LeftDecoder, right: RightDecoder)? {
        return try fetchCursor(statement, arguments: arguments, adapter: adapter).next()
    }
}

extension JoinedPairDecoder where LeftDecoder: RowConvertible, RightDecoder: DatabaseValueConvertible {
    
    // MARK: Fetching From Request
    
    static func fetchCursor(_ db: Database, _ request: Request) throws -> MapCursor<RowCursor, (left: LeftDecoder, right: RightDecoder)> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    static func fetchAll(_ db: Database, _ request: Request) throws -> [(left: LeftDecoder, right: RightDecoder)] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    static func fetchOne(_ db: Database, _ request: Request) throws -> (left: LeftDecoder, right: RightDecoder)? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension TypedRequest where RowDecoder: JoinedPairDecoder, RowDecoder.LeftDecoder: RowConvertible, RowDecoder.RightDecoder: DatabaseValueConvertible {
    public func fetchCursor(_ db: Database) throws -> MapCursor<RowCursor, (left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder)> {
        return try RowDecoder.fetchCursor(db, self)
    }
    
    public func fetchAll(_ db: Database) throws -> [(left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder)] {
        return try RowDecoder.fetchAll(db, self)
    }
    
    public func fetchOne(_ db: Database) throws -> (left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder)? {
        return try RowDecoder.fetchOne(db, self)
    }
}

// MARK: - Left Join (RowConvertible, RowConvertible?)

extension JoinedPairDecoder where LeftDecoder: RowConvertible, RightDecoder: _OptionalProtocol, RightDecoder._Wrapped: RowConvertible {
    
    // MARK: Fetching From SelectStatement
    
    static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> MapCursor<RowCursor, (left: LeftDecoder, right: RightDecoder._Wrapped?)> {
        return try Row.fetchCursor(statement, arguments: arguments, adapter: adapter).map { row in
            (left: LeftDecoder(row: leftRow(row)), right: RightDecoder._Wrapped(leftJoinedRow: rightRow(row)))
        }
    }
    
    static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [(left: LeftDecoder, right: RightDecoder._Wrapped?)] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> (left: LeftDecoder, right: RightDecoder._Wrapped?)? {
        return try fetchCursor(statement, arguments: arguments, adapter: adapter).next()
    }
}

extension JoinedPairDecoder where LeftDecoder: RowConvertible, RightDecoder: _OptionalProtocol, RightDecoder._Wrapped: RowConvertible {
    
    // MARK: Fetching From Request
    
    static func fetchCursor(_ db: Database, _ request: Request) throws -> MapCursor<RowCursor, (left: LeftDecoder, right: RightDecoder._Wrapped?)> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    static func fetchAll(_ db: Database, _ request: Request) throws -> [(left: LeftDecoder, right: RightDecoder._Wrapped?)] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    static func fetchOne(_ db: Database, _ request: Request) throws -> (left: LeftDecoder, right: RightDecoder._Wrapped?)? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension TypedRequest where RowDecoder: JoinedPairDecoder, RowDecoder.LeftDecoder: RowConvertible, RowDecoder.RightDecoder: _OptionalProtocol, RowDecoder.RightDecoder._Wrapped: RowConvertible {
    public func fetchCursor(_ db: Database) throws -> MapCursor<RowCursor, (left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder._Wrapped?)> {
        return try RowDecoder.fetchCursor(db, self)
    }
    
    public func fetchAll(_ db: Database) throws -> [(left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder._Wrapped?)] {
        return try RowDecoder.fetchAll(db, self)
    }
    
    public func fetchOne(_ db: Database) throws -> (left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder._Wrapped?)? {
        return try RowDecoder.fetchOne(db, self)
    }
}

// MARK: - Left Join (RowConvertible, DatabaseValueConvertible?)

extension JoinedPairDecoder where LeftDecoder: RowConvertible, RightDecoder: _OptionalProtocol, RightDecoder._Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From SelectStatement
    
    static func fetchCursor(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> MapCursor<RowCursor, (left: LeftDecoder, right: RightDecoder._Wrapped?)> {
        return try Row.fetchCursor(statement, arguments: arguments, adapter: adapter).map { row in
            (left: LeftDecoder(row: leftRow(row)), right: rightRow(row)[0])
        }
    }
    
    static func fetchAll(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> [(left: LeftDecoder, right: RightDecoder._Wrapped?)] {
        return try Array(fetchCursor(statement, arguments: arguments, adapter: adapter))
    }
    
    static func fetchOne(_ statement: SelectStatement, arguments: StatementArguments? = nil, adapter: RowAdapter? = nil) throws -> (left: LeftDecoder, right: RightDecoder._Wrapped?)? {
        return try fetchCursor(statement, arguments: arguments, adapter: adapter).next()
    }
}

extension JoinedPairDecoder where LeftDecoder: RowConvertible, RightDecoder: _OptionalProtocol, RightDecoder._Wrapped: DatabaseValueConvertible {
    
    // MARK: Fetching From Request
    
    static func fetchCursor(_ db: Database, _ request: Request) throws -> MapCursor<RowCursor, (left: LeftDecoder, right: RightDecoder._Wrapped?)> {
        let (statement, adapter) = try request.prepare(db)
        return try fetchCursor(statement, adapter: adapter)
    }
    
    static func fetchAll(_ db: Database, _ request: Request) throws -> [(left: LeftDecoder, right: RightDecoder._Wrapped?)] {
        let (statement, adapter) = try request.prepare(db)
        return try fetchAll(statement, adapter: adapter)
    }
    
    static func fetchOne(_ db: Database, _ request: Request) throws -> (left: LeftDecoder, right: RightDecoder._Wrapped?)? {
        let (statement, adapter) = try request.prepare(db)
        return try fetchOne(statement, adapter: adapter)
    }
}

extension TypedRequest where RowDecoder: JoinedPairDecoder, RowDecoder.LeftDecoder: RowConvertible, RowDecoder.RightDecoder: _OptionalProtocol, RowDecoder.RightDecoder._Wrapped: DatabaseValueConvertible {
    public func fetchCursor(_ db: Database) throws -> MapCursor<RowCursor, (left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder._Wrapped?)> {
        return try RowDecoder.fetchCursor(db, self)
    }
    
    public func fetchAll(_ db: Database) throws -> [(left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder._Wrapped?)] {
        return try RowDecoder.fetchAll(db, self)
    }
    
    public func fetchOne(_ db: Database) throws -> (left: RowDecoder.LeftDecoder, right: RowDecoder.RightDecoder._Wrapped?)? {
        return try RowDecoder.fetchOne(db, self)
    }
}
