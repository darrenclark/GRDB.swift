/// The protocol for requests that can be derived:
///
///     let request = ...
///     let derivedRequest = request.filter(...).order(...)
public protocol DerivableRequest {
    /// Creates a request with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM players
    ///     var request = Player.all()
    ///     request = request.select([Column("id"), Column("email")])
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM players
    ///     request
    ///         .select([Column("id")])
    ///         .select([Column("email")])
    func select(_ selection: [SQLSelectable]) -> Self

    /// Creates a request which returns distinct rows.
    ///
    ///     // SELECT DISTINCT * FROM players
    ///     var request = Player.all()
    ///     request = request.distinct()
    ///
    ///     // SELECT DISTINCT name FROM players
    ///     var request = Player.select(Column("name"))
    ///     request = request.distinct()
    func distinct() -> Self
    
    /// Creates a request with the provided *predicate* added to the eventual
    /// set of already applied predicates.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(Column("email") == "arthur@example.com")
    func filter(_ predicate: SQLExpressible) -> Self

    /// Creates a request grouped according to *expressions*.
    func group(_ expressions: [SQLExpressible]) -> Self
    
    /// Creates a request with the provided *predicate* added to the eventual
    /// set of already applied predicates.
    func having(_ predicate: SQLExpressible) -> Self
    
    /// Creates a request with the provided *orderings*.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order([Column("name")])
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     request
    ///         .order([Column("email")])
    ///         .reversed()
    ///         .order([Column("name")])
    func order(_ orderings: [SQLOrderingTerm]) -> Self
    
    /// Creates a request sorted in reversed order.
    ///
    ///     // SELECT * FROM players ORDER BY name DESC
    ///     var request = Player.all().order(Column("name"))
    ///     request = request.reversed()
    func reversed() -> Self

    /// A QueryInterfaceRequest which fetches *limit* rows, starting
    /// at *offset*.
    ///
    ///     // SELECT * FROM players LIMIT 1
    ///     var request = Player.all()
    ///     request = request.limit(1)
    func limit(_ limit: Int, offset: Int?) -> Self
}

extension DerivableRequest {
    
    // MARK: Request Derivation
    
    /// Creates a new request with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM players
    ///     var request = Player.all()
    ///     request = request.select(Column("id"), Column("email"))
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM players
    ///     request
    ///         .select(Column("id"))
    ///         .select(Column("email"))
    public func select(_ selection: SQLSelectable...) -> Self {
        return select(selection)
    }
    
    /// Creates a new request with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM players
    ///     var request = Player.all()
    ///     request = request.select(sql: "id, email")
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM players
    ///     request
    ///         .select(sql: "id")
    ///         .select(sql: "email")
    public func select(sql: String, arguments: StatementArguments? = nil) -> Self {
        return select(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// Creates a new request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public func filter(sql: String, arguments: StatementArguments? = nil) -> Self {
        return filter(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// Creates a new request grouped according to *expressions*.
    public func group(_ expressions: SQLExpressible...) -> Self {
        return group(expressions)
    }
    
    /// Creates a new request with a new grouping.
    public func group(sql: String, arguments: StatementArguments? = nil) -> Self {
        return group(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// Creates a new request with the provided *sql* added to the
    /// eventual set of already applied predicates.
    public func having(sql: String, arguments: StatementArguments? = nil) -> Self {
        return having(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// Creates a new request with the provided *orderings*.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(Column("name"))
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     request
    ///         .order(Column("email"))
    ///         .reversed()
    ///         .order(Column("name"))
    public func order(_ orderings: SQLOrderingTerm...) -> Self {
        return order(orderings)
    }
    
    /// Creates a new request with the provided *sql* used for sorting.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(sql: "name")
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     request
    ///         .order(sql: "email")
    ///         .order(sql: "name")
    public func order(sql: String, arguments: StatementArguments? = nil) -> Self {
        return order([SQLExpressionLiteral(sql, arguments: arguments)])
    }
}
