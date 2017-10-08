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

class HasManyThroughJoinedRequest_BelongsTo_HasMany_Tests: GRDBTestCase {
    
    // TODO: conditions on middle table
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Reader
                .joined(with: Reader.books)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, """
                SELECT "readers".*, "books".* \
                FROM "readers" \
                JOIN "libraries" ON ("libraries"."id" = "readers"."libraryId") \
                JOIN "books" ON ("books"."libraryId" = "libraries"."id")
                """)
            
            assertMatch(graph, [
                (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1]),
                (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book3", "title": "Walden", "libraryId": 1]),
                (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1]),
                (["email": "craig@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                (["email": "craig@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                (["email": "david@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                (["email": "david@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
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
                    .joined(with: Reader.books)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "readers".*, "books".* \
                    FROM "readers" \
                    JOIN "libraries" ON ("libraries"."id" = "readers"."libraryId") \
                    JOIN "books" ON ("books"."libraryId" = "libraries"."id") \
                    WHERE ("readers"."email" <> 'barbara@example.com')
                    """)
                
                assertMatch(graph, [
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    ])
            }
            
            do {
                // filter after
                let graph = try Reader
                    .joined(with: Reader.books)
                    .filter(Column("email") != "barbara@example.com")
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "readers".*, "books".* \
                    FROM "readers" \
                    JOIN "libraries" ON ("libraries"."id" = "readers"."libraryId") \
                    JOIN "books" ON ("books"."libraryId" = "libraries"."id") \
                    WHERE ("readers"."email" <> 'barbara@example.com')
                    """)
                
                assertMatch(graph, [
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    ])
            }
            
            do {
                // order before
                let graph = try Reader
                    .order(Column("email").desc)
                    .joined(with: Reader.books)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "readers".*, "books".* \
                    FROM "readers" \
                    JOIN "libraries" ON ("libraries"."id" = "readers"."libraryId") \
                    JOIN "books" ON ("books"."libraryId" = "libraries"."id") \
                    ORDER BY "readers"."email" DESC
                    """)
                
                assertMatch(graph, [
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book3", "title": "Walden", "libraryId": 1]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1]),
                    ])
            }
            
            do {
                // order after
                let graph = try Reader
                    .joined(with: Reader.books)
                    .order(Column("email").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "readers".*, "books".* \
                    FROM "readers" \
                    JOIN "libraries" ON ("libraries"."id" = "readers"."libraryId") \
                    JOIN "books" ON ("books"."libraryId" = "libraries"."id") \
                    ORDER BY "readers"."email" DESC
                    """)
                
                assertMatch(graph, [
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book3", "title": "Walden", "libraryId": 1]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1]),
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
                    .joined(with: Reader.books.filter(Column("title") != "Walden"))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "readers".*, "books".* \
                    FROM "readers" \
                    JOIN "libraries" ON ("libraries"."id" = "readers"."libraryId") \
                    JOIN "books" ON (("books"."libraryId" = "libraries"."id") AND ("books"."title" <> 'Walden'))
                    """)
                
                assertMatch(graph, [
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1]),
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    ])
            }
            
            do {
                // ordered books
                let graph = try Reader
                    .joined(with: Reader.books.order(Column("title")))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "readers".*, "books".* \
                    FROM "readers" \
                    JOIN "libraries" ON ("libraries"."id" = "readers"."libraryId") \
                    JOIN "books" ON ("books"."libraryId" = "libraries"."id") \
                    ORDER BY "books"."title"
                    """)
                
                assertMatch(graph, [
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1]),
                    (["email": "craig@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "david@example.com", "libraryId": 2], ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1]),
                    (["email": "barbara@example.com", "libraryId": 1], ["isbn": "book3", "title": "Walden", "libraryId": 1]),
                    ])
            }
        }
    }
}
