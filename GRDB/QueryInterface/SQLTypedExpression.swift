public protocol SQLTypedExpression : SQLSelectable, SQLOrderingTerm {
    associatedtype SQLValueType
    var sqlExpression: SQLExpression { get }
}

public struct AnyTypedExpression<Value> : SQLTypedExpression {
    public typealias SQLValueType = Value
    public let sqlExpression: SQLExpression
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

public func == <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType == R.SQLValueType {
    return AnyTypedExpression(sqlExpression: lhs.sqlExpression == rhs.sqlExpression)
}

public func == <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType {
    return AnyTypedExpression(sqlExpression: lhs.sqlExpression == rhs.sqlExpression)
}

public func == <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, R.SQLValueType: _OptionalProtocol, L.SQLValueType == R.SQLValueType._Wrapped {
    return AnyTypedExpression(sqlExpression: lhs.sqlExpression == rhs.sqlExpression)
}

public func == <L, R>(lhs: L, rhs: R) -> AnyTypedExpression<Bool?> where L: SQLTypedExpression, R: SQLTypedExpression, L.SQLValueType: _OptionalProtocol, R.SQLValueType: _OptionalProtocol, L.SQLValueType._Wrapped == R.SQLValueType._Wrapped {
    return AnyTypedExpression(sqlExpression: lhs.sqlExpression == rhs.sqlExpression)
}

public func == <E>(lhs: E, rhs: E.SQLValueType) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(sqlExpression: lhs.sqlExpression == rhs)
}

public func == <E>(lhs: E, rhs: E.SQLValueType._Wrapped?) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(sqlExpression: lhs.sqlExpression == rhs)
}

public func == <E>(lhs: E.SQLValueType, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: SQLExpressible {
    return AnyTypedExpression(sqlExpression: lhs == rhs.sqlExpression)
}

public func == <E>(lhs: E.SQLValueType._Wrapped?, rhs: E) -> AnyTypedExpression<Bool> where E: SQLTypedExpression, E.SQLValueType: _OptionalProtocol, E.SQLValueType._Wrapped: SQLExpressible {
    return AnyTypedExpression(sqlExpression: lhs == rhs.sqlExpression)
}
