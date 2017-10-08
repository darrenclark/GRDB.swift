import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private typealias Reader = HasManyThrough_BelongsTo_HasMany_Fixture.Reader
private typealias Book = HasManyThrough_BelongsTo_HasMany_Fixture.Book

class HasManyThroughIncludingRequest_BelongsTo_HasMany_Tests: GRDBTestCase {
    
    // TODO: conditions on middle table
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Reader
                .including(Reader.books)
                .fetchAll(db)
            
            XCTAssertEqual(sqlQueries[sqlQueries.count - 3], "SELECT * FROM \"readers\"")
            XCTAssertTrue([1, 2, 3].sqlPermutations.contains {
                sqlQueries[sqlQueries.count - 1] == String(format: """
                    SELECT "libraries"."id", "books".* \
                    FROM "books" \
                    JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."id" IN (%@)))
                    """, $0)
            })
            
            assertMatch(graph, [
                (["email": "arthur@example.com", "libraryId": nil], []),
                (["email": "barbara@example.com", "libraryId": 1], [
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ]),
                (["email": "craig@example.com", "libraryId": 2], [
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ]),
                (["email": "david@example.com", "libraryId": 2], [
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ]),
                (["email": "eve@example.com", "libraryId": 3], []),
                ])
        }
    }
    
    func testLeftRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filter before
                let graph = try Reader
                    .filter(Column("email") != "barbara@example.com")
                    .including(Reader.books)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 3], "SELECT * FROM \"readers\" WHERE (\"email\" <> \'barbara@example.com\')")
                XCTAssertTrue([2, 3].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: """
                        SELECT "libraries"."id", "books".* \
                        FROM "books" \
                        JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."id" IN (%@)))
                        """, $0)
                })
                
                assertMatch(graph, [
                    (["email": "arthur@example.com", "libraryId": nil], []),
                    (["email": "craig@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "david@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "eve@example.com", "libraryId": 3], []),
                    ])
            }
            
            do {
                // filter after
                let graph = try Reader
                    .including(Reader.books)
                    .filter(Column("email") != "barbara@example.com")
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"readers\" WHERE (\"email\" <> \'barbara@example.com\')")
                XCTAssertTrue([2, 3].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: """
                        SELECT "libraries"."id", "books".* \
                        FROM "books" \
                        JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."id" IN (%@)))
                        """, $0)
                })
                
                assertMatch(graph, [
                    (["email": "arthur@example.com", "libraryId": nil], []),
                    (["email": "craig@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "david@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "eve@example.com", "libraryId": 3], []),
                    ])
            }
            
            do {
                // order before including
                let graph = try Reader
                    .order(Column("email").desc)
                    .including(Reader.books)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"readers\" ORDER BY \"email\" DESC")
                XCTAssertTrue([1, 2, 3].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: """
                        SELECT "libraries"."id", "books".* \
                        FROM "books" \
                        JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."id" IN (%@)))
                        """, $0)
                })
                
                assertMatch(graph, [
                    (["email": "eve@example.com", "libraryId": 3], []),
                    (["email": "david@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "craig@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "barbara@example.com", "libraryId": 1], [
                        ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                        ["isbn": "book3", "title": "Walden", "libraryId": 1],
                        ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                        ]),
                    (["email": "arthur@example.com", "libraryId": nil], []),
                    ])
            }
            
            do {
                // order after including
                let graph = try Reader
                    .including(Reader.books)
                    .order(Column("email").desc)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"readers\" ORDER BY \"email\" DESC")
                XCTAssertTrue([1, 2, 3].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: """
                        SELECT "libraries"."id", "books".* \
                        FROM "books" \
                        JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."id" IN (%@)))
                        """, $0)
                })
                
                assertMatch(graph, [
                    (["email": "eve@example.com", "libraryId": 3], []),
                    (["email": "david@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "craig@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "barbara@example.com", "libraryId": 1], [
                        ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                        ["isbn": "book3", "title": "Walden", "libraryId": 1],
                        ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                        ]),
                    (["email": "arthur@example.com", "libraryId": nil], []),
                    ])
            }
        }
    }
    
    func testRightRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filtered books
                let graph = try Reader
                    .including(Reader.books.filter(Column("title") != "Walden"))
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 3], "SELECT * FROM \"readers\"")
                XCTAssertTrue([1, 2, 3].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: """
                        SELECT "libraries"."id", "books".* \
                        FROM "books" \
                        JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."id" IN (%@))) \
                        WHERE ("books"."title" <> 'Walden')
                        """, $0)
                })
                
                assertMatch(graph, [
                    (["email": "arthur@example.com", "libraryId": nil], []),
                    (["email": "barbara@example.com", "libraryId": 1], [
                        ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                        ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                        ]),
                    (["email": "craig@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "david@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "eve@example.com", "libraryId": 3], []),
                    ])
            }
            
            do {
                // ordered books
                let graph = try Reader
                    .including(Reader.books.order(Column("title")))
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"readers\"")
                XCTAssertTrue([1, 2, 3].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: """
                        SELECT "libraries"."id", "books".* \
                        FROM "books" \
                        JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."id" IN (%@))) \
                        ORDER BY "books"."title"
                        """, $0)
                })
                
                assertMatch(graph, [
                    (["email": "arthur@example.com", "libraryId": nil], []),
                    (["email": "barbara@example.com", "libraryId": 1], [
                        ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                        ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                        ["isbn": "book3", "title": "Walden", "libraryId": 1],
                        ]),
                    (["email": "craig@example.com", "libraryId": 2], [
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ]),
                    (["email": "david@example.com", "libraryId": 2], [
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ]),
                    (["email": "eve@example.com", "libraryId": 3], []),
                    ])
            }
        }
    }
    
    func testAnnotationPredicate() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filter before
                let graph = try Reader
                    .filter(Reader.books.count == 2) // TODO: test for another hasManyThrough annotation, and for a hasMany annotation
                    .including(Reader.books)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], """
                    SELECT "readers".* \
                    FROM "readers" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "readers"."libraryId") \
                    LEFT JOIN "books" ON ("books"."libraryId" = "libraries"."id") \
                    GROUP BY "readers"."email" \
                    HAVING (COUNT("books"."isbn") = 2)
                    """)
                XCTAssertEqual(sqlQueries[sqlQueries.count - 1], """
                    SELECT "libraries"."id", "books".* \
                    FROM "books" \
                    JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."id" IN (2)))
                    """) // TODO: is this JOIN useful? If not, remove it.
                
                assertMatch(graph, [
                    (["email": "craig@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "david@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    ])
            }
            do {
                // filter after
                let graph = try Reader
                    .including(Reader.books)
                    .filter(Reader.books.count == 2)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], """
                    SELECT "readers".* \
                    FROM "readers" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "readers"."libraryId") \
                    LEFT JOIN "books" ON ("books"."libraryId" = "libraries"."id") \
                    GROUP BY "readers"."email" \
                    HAVING (COUNT("books"."isbn") = 2)
                    """)
                XCTAssertEqual(sqlQueries[sqlQueries.count - 1], """
                    SELECT "libraries"."id", "books".* \
                    FROM "books" \
                    JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."id" IN (2)))
                    """) // TODO: is this JOIN useful? If not, remove it.
                
                assertMatch(graph, [
                    (["email": "craig@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    (["email": "david@example.com", "libraryId": 2], [
                        ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                        ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                        ]),
                    ])
            }
        }
    }
}
