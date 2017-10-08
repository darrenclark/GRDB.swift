#if SQLITE_ENABLE_FTS5
    extension QueryInterfaceRequest {
        
        // MARK: Full Text Search
        
        /// Returns a new QueryInterfaceRequest with a matching predicate added
        /// to the eventual set of already applied predicates.
        ///
        ///     // SELECT * FROM books WHERE books MATCH '...'
        ///     var request = Book.all()
        ///     request = request.matching(pattern)
        ///
        /// If the search pattern is nil, the request does not match any
        /// database row.
        ///
        /// The selection defaults to all columns. This default can be changed for
        /// all requests by the `TableMapping.databaseSelection` property, or
        /// for individual requests with the `TableMapping.select` method.
        public func matching(_ pattern: FTS5Pattern?) -> QueryInterfaceRequest<T> {
            guard let qualifiedName = query.source.qualifiedName else {
                fatalError("fts5 match requires a table")
            }
            if let pattern = pattern {
                return filter(SQLExpressionBinary(.match, Column(qualifiedName), pattern))
            } else {
                return filter(false)
            }
        }
    }
    
    extension TableMapping {
        
        // MARK: Full Text Search
        
        /// Returns a QueryInterfaceRequest with a matching predicate.
        ///
        ///     // SELECT * FROM books WHERE books MATCH '...'
        ///     var request = Book.matching(pattern)
        ///
        /// If the search pattern is nil, the request does not match any
        /// database row.
        public static func matching(_ pattern: FTS5Pattern?) -> QueryInterfaceRequest<Self> {
            return all().matching(pattern)
        }
    }
#endif
