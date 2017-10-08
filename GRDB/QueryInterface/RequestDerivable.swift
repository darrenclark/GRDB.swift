public protocol RequestDerivable {
    /// A new request with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM persons
    ///     var request = Person.all()
    ///     request = request.select([Column("id"), Column("email")])
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM persons
    ///     request
    ///         .select([Column("id")])
    ///         .select([Column("email")])
    func select(_ selection: [SQLSelectable]) -> Self
    
    /// A new request which returns distinct rows.
    ///
    ///     // SELECT DISTINCT * FROM persons
    ///     var request = Person.all()
    ///     request = request.distinct()
    ///
    ///     // SELECT DISTINCT name FROM persons
    ///     var request = Person.select(Column("name"))
    ///     request = request.distinct()
    func distinct() -> Self
    
    /// A new request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM persons WHERE email = 'arthur@example.com'
    ///     var request = Person.all()
    ///     request = request.filter(Column("email") == "arthur@example.com")
    func filter(_ predicate: SQLExpressible) -> Self
    
    /// A new request grouped according to *expressions*.
    func group(_ expressions: [SQLExpressible]) -> Self
    
    /// A new request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    func having(_ predicate: SQLExpressible) -> Self
    
    /// A new request with the provided *orderings*.
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     var request = Person.all()
    ///     request = request.order([Column("name")])
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     request
    ///         .order([Column("email")])
    ///         .reversed()
    ///         .order([Column("name")])
    func order(_ orderings: [SQLOrderingTerm]) -> Self
    
    /// A new request sorted in reversed order.
    ///
    ///     // SELECT * FROM persons ORDER BY name DESC
    ///     var request = Person.all().order(Column("name"))
    ///     request = request.reversed()
    func reversed() -> Self
    
    /// A request which fetches *limit* rows, starting
    /// at *offset*.
    ///
    ///     // SELECT * FROM persons LIMIT 10 OFFSET 20
    ///     var request = Person.all()
    ///     request = request.limit(1, offset: 20)
    func limit(_ limit: Int, offset: Int?) -> Self
    
    /// TODO
    func aliased(_ alias: String) -> Self
}

extension RequestDerivable {
    
    /// A new request with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM persons
    ///     var request = Person.all()
    ///     request = request.select(Column("id"), Column("email"))
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM persons
    ///     request
    ///         .select(Column("id"))
    ///         .select(Column("email"))
    public func select(_ selection: SQLSelectable...) -> Self {
        return select(selection)
    }
    
    /// A new request with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM persons
    ///     var request = Person.all()
    ///     request = request.select(sql: "id, email")
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM persons
    ///     request
    ///         .select(sql: "id")
    ///         .select(sql: "email")
    public func select(sql: String, arguments: StatementArguments? = nil) -> Self {
        return select(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// A new request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM persons WHERE email = 'arthur@example.com'
    ///     var request = Person.all()
    ///     request = request.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public func filter(sql: String, arguments: StatementArguments? = nil) -> Self {
        return filter(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// A new request grouped according to *expressions*.
    public func group(_ expressions: SQLExpressible...) -> Self {
        return group(expressions)
    }
    
    /// A new request with a new grouping.
    public func group(sql: String, arguments: StatementArguments? = nil) -> Self {
        return group([SQLExpressionLiteral(sql, arguments: arguments)])
    }
    
    /// A new request with the provided *sql* added to the
    /// eventual set of already applied predicates.
    public func having(sql: String, arguments: StatementArguments? = nil) -> Self {
        return having(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// A new request with the provided *orderings*.
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     var request = Person.all()
    ///     request = request.order(Column("name"))
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     request
    ///         .order(Column("email"))
    ///         .reversed()
    ///         .order(Column("name"))
    public func order(_ orderings: SQLOrderingTerm...) -> Self {
        return order(orderings)
    }
    
    /// A new request with the provided *sql* used for sorting.
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     var request = Person.all()
    ///     request = request.order(sql: "name")
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM persons ORDER BY name
    ///     request
    ///         .order(sql: "email")
    ///         .order(sql: "name")
    public func order(sql: String, arguments: StatementArguments? = nil) -> Self {
        return order([SQLExpressionLiteral(sql, arguments: arguments)])
    }
    
    /// A request which fetches *limit* rows, starting
    /// at *offset*.
    ///
    ///     // SELECT * FROM persons LIMIT 1
    ///     var request = Person.all()
    ///     request = request.limit(1)
    public func limit(_ limit: Int) -> Self {
        return self.limit(limit, offset: nil)
    }
}

/// TODO
public protocol RequestDerivableWrapper : RequestDerivable {
    /// TODO
    associatedtype WrappedRequest: RequestDerivable
    /// TODO
    func mapRequest(_ transform: (WrappedRequest) -> (WrappedRequest)) -> Self
}

extension RequestDerivableWrapper {
    /// TODO
    public func select(_ selection: [SQLSelectable]) -> Self {
        return mapRequest { $0.select(selection) }
    }
    
    /// TODO
    public func distinct() -> Self {
        return mapRequest { $0.distinct() }
    }
    
    /// TODO
    public func filter(_ predicate: SQLExpressible) -> Self {
        return mapRequest { $0.filter(predicate) }
    }
    
    /// TODO
    public func group(_ expressions: [SQLExpressible]) -> Self {
        return mapRequest { $0.group(expressions) }
    }
    
    /// TODO
    public func having(_ predicate: SQLExpressible) -> Self {
        return mapRequest { $0.having(predicate) }
    }
    
    /// TODO
    public func order(_ orderings: [SQLOrderingTerm]) -> Self {
        return mapRequest { $0.order(orderings) }
    }
    
    /// TODO
    public func reversed() -> Self {
        return mapRequest { $0.reversed() }
    }
    
    /// TODO
    public func limit(_ limit: Int, offset: Int?) -> Self {
        return mapRequest { $0.limit(limit, offset: offset) }
    }
    
    /// TODO
    public func aliased(_ alias: String) -> Self {
        return mapRequest { $0.aliased(alias) }
    }
}
