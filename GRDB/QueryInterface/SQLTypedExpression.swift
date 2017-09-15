public protocol SQLTypedExpression : SQLSelectable, SQLOrderingTerm {
    associatedtype SQLValueType
    var sqlExpression: SQLExpression { get }
}

public struct AnyTypedExpression<Value> : SQLTypedExpression {
    public typealias SQLValueType = Value
    public let sqlExpression: SQLExpression
    
    init(_ sqlExpression: SQLExpression) {
        self.sqlExpression = sqlExpression
    }
}

// MARK: - SQLExpressible & SQLOrderingTerm

extension SQLTypedExpression {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public var reversed: SQLOrderingTerm {
        return SQLOrdering.desc(sqlExpression)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func orderingTermSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.expressionSQL(&arguments)
    }
}

// MARK: - SQLExpressible & SQLSelectable

extension SQLTypedExpression {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.expressionSQL(&arguments)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.expressionSQL(&arguments)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func count(distinct: Bool) -> SQLCount? {
        return sqlExpression.count(distinct: distinct)
    }
}

extension DerivableRequest {
    /// Creates a request with the provided *predicate* added to the eventual
    /// set of already applied predicates.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(Column("email") == "arthur@example.com")
    public func filter<E>(_ predicate: E) -> Self where E: SQLTypedExpression {
        return filter(predicate.sqlExpression)
    }
}

extension TableMapping {
    /// Creates a QueryInterfaceRequest with the provided *predicate*.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     let request = Player.filter(Column("email") == "arthur@example.com")
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableMapping.databaseSelection` property, or
    /// for individual requests with the `TableMapping.select` method.
    public static func filter<E>(_ predicate: E) -> QueryInterfaceRequest<Self> where E: SQLTypedExpression {
        return all().filter(predicate)
    }
}

public prefix func ! <E>(value: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression {
    return AnyTypedExpression(!value.sqlExpression)
}

public func == <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression == rhs.sqlExpression)
}

public func == <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression == rhs.sqlExpression)
}

public func == <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, R.SQLValueType: _OptionalProtocol, L.SQLValueType == R.SQLValueType._Wrapped {
    return AnyTypedExpression(lhs.sqlExpression == rhs.sqlExpression)
}

public func == <E>(lhs: E, rhs: E.SQLValueType) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression == rhs)
}

public func == <E>(lhs: E, rhs: E.SQLValueType._Wrapped?) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression == rhs)
}

public func == <E>(lhs: E.SQLValueType, rhs: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs == rhs.sqlExpression)
}

public func == <E>(lhs: E.SQLValueType._Wrapped?, rhs: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs == rhs.sqlExpression)
}


public func != <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression != rhs.sqlExpression)
}

public func != <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression != rhs.sqlExpression)
}

public func != <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, R.SQLValueType: _OptionalProtocol, L.SQLValueType == R.SQLValueType._Wrapped {
    return AnyTypedExpression(lhs.sqlExpression != rhs.sqlExpression)
}

public func != <E>(lhs: E, rhs: E.SQLValueType) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression != rhs)
}

public func != <E>(lhs: E, rhs: E.SQLValueType._Wrapped?) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression != rhs)
}

public func != <E>(lhs: E.SQLValueType, rhs: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs != rhs.sqlExpression)
}

// This one has Cursor.swift fail to compile
//public func != <E>(lhs: E.SQLValueType._Wrapped?, rhs: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
//    return AnyTypedExpression(lhs != rhs.sqlExpression)
//}


public func === <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression === rhs.sqlExpression)
}

public func === <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression === rhs.sqlExpression)
}

public func === <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool> where L: SQLTypedExpression, R: SQLTypedExpression, R.SQLValueType: _OptionalProtocol, L.SQLValueType == R.SQLValueType._Wrapped {
    return AnyTypedExpression(lhs.sqlExpression === rhs.sqlExpression)
}

public func === <E>(lhs: E, rhs: E.SQLValueType) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression === rhs)
}

public func === <E>(lhs: E, rhs: E.SQLValueType._Wrapped?) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression === rhs)
}

public func === <E>(lhs: E.SQLValueType, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs === rhs.sqlExpression)
}

public func === <E>(lhs: E.SQLValueType._Wrapped?, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs === rhs.sqlExpression)
}


public func !== <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression !== rhs.sqlExpression)
}

public func !== <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression !== rhs.sqlExpression)
}

public func !== <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool> where L: SQLTypedExpression, R: SQLTypedExpression, R.SQLValueType: _OptionalProtocol, L.SQLValueType == R.SQLValueType._Wrapped {
    return AnyTypedExpression(lhs.sqlExpression !== rhs.sqlExpression)
}

public func !== <E>(lhs: E, rhs: E.SQLValueType) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression !== rhs)
}

public func !== <E>(lhs: E, rhs: E.SQLValueType._Wrapped?) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression !== rhs)
}

public func !== <E>(lhs: E.SQLValueType, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs !== rhs.sqlExpression)
}

public func !== <E>(lhs: E.SQLValueType._Wrapped?, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs !== rhs.sqlExpression)
}


public func <= <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression <= rhs.sqlExpression)
}

public func <= <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression <= rhs.sqlExpression)
}

public func <= <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, R.SQLValueType: _OptionalProtocol, L.SQLValueType == R.SQLValueType._Wrapped {
    return AnyTypedExpression(lhs.sqlExpression <= rhs.sqlExpression)
}

public func <= <E>(lhs: E, rhs: E.SQLValueType) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression <= rhs)
}

public func <= <E>(lhs: E, rhs: E.SQLValueType._Wrapped) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression <= rhs)
}

public func <= <E>(lhs: E.SQLValueType, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs <= rhs.sqlExpression)
}

public func <= <E>(lhs: E.SQLValueType._Wrapped, rhs: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs <= rhs.sqlExpression)
}


public func < <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression < rhs.sqlExpression)
}

public func < <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression < rhs.sqlExpression)
}

public func < <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, R.SQLValueType: _OptionalProtocol, L.SQLValueType == R.SQLValueType._Wrapped {
    return AnyTypedExpression(lhs.sqlExpression < rhs.sqlExpression)
}

public func < <E>(lhs: E, rhs: E.SQLValueType) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression < rhs)
}

public func < <E>(lhs: E, rhs: E.SQLValueType._Wrapped) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression < rhs)
}

public func < <E>(lhs: E.SQLValueType, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs < rhs.sqlExpression)
}

public func < <E>(lhs: E.SQLValueType._Wrapped, rhs: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs < rhs.sqlExpression)
}


public func >= <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression >= rhs.sqlExpression)
}

public func >= <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression >= rhs.sqlExpression)
}

public func >= <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, R.SQLValueType: _OptionalProtocol, L.SQLValueType == R.SQLValueType._Wrapped {
    return AnyTypedExpression(lhs.sqlExpression >= rhs.sqlExpression)
}

public func >= <E>(lhs: E, rhs: E.SQLValueType) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression >= rhs)
}

public func >= <E>(lhs: E, rhs: E.SQLValueType._Wrapped) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression >= rhs)
}

public func >= <E>(lhs: E.SQLValueType, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs >= rhs.sqlExpression)
}

public func >= <E>(lhs: E.SQLValueType._Wrapped, rhs: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs >= rhs.sqlExpression)
}


public func > <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression > rhs.sqlExpression)
}

public func > <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType {
    return AnyTypedExpression(lhs.sqlExpression > rhs.sqlExpression)
}

public func > <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, R.SQLValueType: _OptionalProtocol, L.SQLValueType == R.SQLValueType._Wrapped {
    return AnyTypedExpression(lhs.sqlExpression > rhs.sqlExpression)
}

public func > <E>(lhs: E, rhs: E.SQLValueType) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression > rhs)
}

public func > <E>(lhs: E, rhs: E.SQLValueType._Wrapped) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs.sqlExpression > rhs)
}

public func > <E>(lhs: E.SQLValueType, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(lhs > rhs.sqlExpression)
}

public func > <E>(lhs: E.SQLValueType._Wrapped, rhs: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(lhs > rhs.sqlExpression)
}


//public func && <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == Bool, R.SQLValueType == Bool {
//    return AnyTypedExpression(lhs.sqlExpression && rhs.sqlExpression)
//}
//
public func && <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == Bool?, R.SQLValueType == Bool {
    return AnyTypedExpression(lhs.sqlExpression && rhs.sqlExpression)
}
//
//public func && <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == Bool, R.SQLValueType == Bool? {
//    return AnyTypedExpression(lhs.sqlExpression && rhs.sqlExpression)
//}
//
//public func && <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == Bool?, R.SQLValueType == Bool? {
//    return AnyTypedExpression(lhs.sqlExpression && rhs.sqlExpression)
//}
//
//public func && <E>(lhs: E, rhs: Bool) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType == Bool? {
//    return AnyTypedExpression(lhs.sqlExpression && rhs.databaseValue.sqlExpression)
//}
//
//public func && <E>(lhs: Bool, rhs: E) -> AnyTypedExpression<Bool?> where E: SQLTypedExpression, E.SQLValueType == Bool? {
//    return AnyTypedExpression(lhs.databaseValue.sqlExpression && rhs.sqlExpression)
//}
//
//public func && <E>(lhs: E, rhs: Bool) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType == Bool {
//    return AnyTypedExpression(rhs ? lhs.sqlExpression : false.databaseValue.sqlExpression)
//}
//
//public func && <E>(lhs: Bool, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType == Bool {
//    return AnyTypedExpression(lhs ? rhs.sqlExpression : false.databaseValue.sqlExpression)
//}


func f(_ db: Database) throws {
    struct Player : RowConvertible, MutablePersistable {
        var id: Int64?
        let name: String
        let score: Int
        
        // GRDB
        
        enum Columns {
            static let id = TypedColumn("id", \Player.id)
            static let name = TypedColumn("name", \Player.name)
            static let score = TypedColumn("score", \Player.score)
        }
        
        static var databaseTableName = "players"
        
        init(row: Row) {
            id = row[Columns.id]
            name = row[Columns.name]
            score = row[Columns.score]
        }
        
        func encode(to container: inout PersistenceContainer) {
            encode(Columns.id, to: &container)
            encode(Columns.name, to: &container)
            encode(Columns.score, to: &container)
        }
        
        mutating func didInsert(with rowID: Int64, for column: String?) {
            id = rowID
        }
    }
    
    let x = Player.Columns.id == 1
    let y = Player.Columns.score > 1000
    let z = x && y
//    let c = ((Player.Columns.id == 1) && true)
//    let d = (true && Player.Columns.score > 1000)
    let e: AnyTypedExpression<Bool?> = ((Player.Columns.id == 1) && (Player.Columns.score > 1000))
    _ = try Player.select((Player.Columns.id == 1) && (Player.Columns.score > 1000)).fetchOne(db)
    
    _ = try Player.select(Player.Columns.id).fetchOne(db)
    _ = try Player.order(Player.Columns.id).fetchOne(db)
    _ = try Player.filter(Player.Columns.id).fetchOne(db)
    _ = try Player.filter(!Player.Columns.id).fetchOne(db)
    _ = try Player.filter(1 == Player.Columns.id).fetchOne(db)
    _ = try Player.filter(AnyTypedExpression<Int64>(1.databaseValue) == Player.Columns.id).fetchOne(db)
    _ = try Player.filter(AnyTypedExpression<Int64?>(1.databaseValue) == Player.Columns.id).fetchOne(db)
    _ = try Player.filter(Player.Columns.id == AnyTypedExpression<Int64>(1.databaseValue)).fetchOne(db)
    _ = try Player.filter(Player.Columns.id == AnyTypedExpression<Int64?>(1.databaseValue)).fetchOne(db)
    _ = try Player.filter(nil == Player.Columns.id).fetchOne(db)
    _ = try Player.filter(AnyTypedExpression<Int64>(DatabaseValue.null) == Player.Columns.id).fetchOne(db)
    _ = try Player.filter(AnyTypedExpression<Int64?>(DatabaseValue.null) == Player.Columns.id).fetchOne(db)
    _ = try Player.filter(Player.Columns.id == nil).fetchOne(db)
    _ = try Player.filter(Player.Columns.id == AnyTypedExpression<Int64>(DatabaseValue.null)).fetchOne(db)
    _ = try Player.filter(Player.Columns.id == AnyTypedExpression<Int64?>(DatabaseValue.null)).fetchOne(db)
    _ = try Player.filter(Player.Columns.id == Player.Columns.id).fetchOne(db)
    
    _ = try Player.select(Player.Columns.score).fetchOne(db)
    _ = try Player.order(Player.Columns.score).fetchOne(db)
    _ = try Player.filter(Player.Columns.score).fetchOne(db)
    _ = try Player.filter(!Player.Columns.score).fetchOne(db)
    _ = try Player.filter(1 == Player.Columns.score).fetchOne(db)
    _ = try Player.filter(AnyTypedExpression<Int>(1.databaseValue) == Player.Columns.score).fetchOne(db)
    _ = try Player.filter(AnyTypedExpression<Int?>(1.databaseValue) == Player.Columns.score).fetchOne(db)
    _ = try Player.filter(Player.Columns.score == AnyTypedExpression<Int>(1.databaseValue)).fetchOne(db)
    _ = try Player.filter(Player.Columns.score == AnyTypedExpression<Int?>(1.databaseValue)).fetchOne(db)
    _ = try Player.filter(AnyTypedExpression<Int>(DatabaseValue.null) == Player.Columns.score).fetchOne(db)
    _ = try Player.filter(AnyTypedExpression<Int?>(DatabaseValue.null) == Player.Columns.score).fetchOne(db)
    _ = try Player.filter(Player.Columns.score == AnyTypedExpression<Int>(DatabaseValue.null)).fetchOne(db)
    _ = try Player.filter(Player.Columns.score == AnyTypedExpression<Int?>(DatabaseValue.null)).fetchOne(db)
    _ = try Player.filter(Player.Columns.score == Player.Columns.score).fetchOne(db)
}
