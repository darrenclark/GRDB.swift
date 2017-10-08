import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private typealias Author = AssociationFixture.Author
private typealias Book = AssociationFixture.Book

class BelongsToOptionalIncludingRequestTests: GRDBTestCase {
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Book
                .including(Book.optionalAuthor)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, """
                SELECT "books".*, "authors".* \
                FROM "books" \
                LEFT JOIN "authors" ON ("authors"."id" = "books"."authorId")
                """)
            
            assertMatch(graph, [
                (["id": 1, "authorId": 2, "title": "Foe", "year": 1986], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                (["id": 2, "authorId": 2, "title": "Three Stories", "year": 2014], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                (["id": 3, "authorId": 3, "title": "Moby-Dick", "year": 1851], ["id": 3, "name": "Herman Melville", "birthYear": 1819]),
                (["id": 4, "authorId": 4, "title": "New York 2140", "year": 2017], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                (["id": 5, "authorId": 4, "title": "2312", "year": 2012], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                (["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                (["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                (["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                (["id": 9, "authorId": nil, "title": "Unattributed", "year": 2017], nil),
                ])
        }
    }
    
    func testLeftRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filter before
                let graph = try Book
                    .filter(Column("year") < 2000)
                    .including(Book.optionalAuthor)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".*, "authors".* \
                    FROM "books" \
                    LEFT JOIN "authors" ON ("authors"."id" = "books"."authorId") \
                    WHERE ("books"."year" < 2000)
                    """)
                
                assertMatch(graph, [
                    (["id": 1, "authorId": 2, "title": "Foe", "year": 1986], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 3, "authorId": 3, "title": "Moby-Dick", "year": 1851], ["id": 3, "name": "Herman Melville", "birthYear": 1819]),
                    (["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    ])
            }
            
            do {
                // filter after
                let graph = try Book
                    .including(Book.optionalAuthor)
                    .filter(Column("year") < 2000)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".*, "authors".* \
                    FROM "books" \
                    LEFT JOIN "authors" ON ("authors"."id" = "books"."authorId") \
                    WHERE ("books"."year" < 2000)
                    """)
                
                assertMatch(graph, [
                    (["id": 1, "authorId": 2, "title": "Foe", "year": 1986], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 3, "authorId": 3, "title": "Moby-Dick", "year": 1851], ["id": 3, "name": "Herman Melville", "birthYear": 1819]),
                    (["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    ])
            }
            
            do {
                // order before
                let graph = try Book
                    .order(Column("title"))
                    .including(Book.optionalAuthor)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".*, "authors".* \
                    FROM "books" \
                    LEFT JOIN "authors" ON ("authors"."id" = "books"."authorId") \
                    ORDER BY "books"."title"
                    """)
                
                assertMatch(graph, [
                    (["id": 5, "authorId": 4, "title": "2312", "year": 2012], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 1, "authorId": 2, "title": "Foe", "year": 1986], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 3, "authorId": 3, "title": "Moby-Dick", "year": 1851], ["id": 3, "name": "Herman Melville", "birthYear": 1819]),
                    (["id": 4, "authorId": 4, "title": "New York 2140", "year": 2017], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 2, "authorId": 2, "title": "Three Stories", "year": 2014], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 9, "authorId": nil, "title": "Unattributed", "year": 2017], nil),
                    ])
            }
            
            do {
                // order after
                let graph = try Book
                    .including(Book.optionalAuthor)
                    .order(Column("title"))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".*, "authors".* \
                    FROM "books" \
                    LEFT JOIN "authors" ON ("authors"."id" = "books"."authorId") \
                    ORDER BY "books"."title"
                    """)
                
                assertMatch(graph, [
                    (["id": 5, "authorId": 4, "title": "2312", "year": 2012], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 1, "authorId": 2, "title": "Foe", "year": 1986], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 3, "authorId": 3, "title": "Moby-Dick", "year": 1851], ["id": 3, "name": "Herman Melville", "birthYear": 1819]),
                    (["id": 4, "authorId": 4, "title": "New York 2140", "year": 2017], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 2, "authorId": 2, "title": "Three Stories", "year": 2014], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 9, "authorId": nil, "title": "Unattributed", "year": 2017], nil),
                    ])
            }
        }
    }
    
    func testRightRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filtered authors
                let graph = try Book
                    .including(Book.optionalAuthor.filter(Column("birthYear") >= 1900))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".*, "authors".* \
                    FROM "books" \
                    LEFT JOIN "authors" ON (("authors"."id" = "books"."authorId") AND ("authors"."birthYear" >= 1900))
                    """)
                
                assertMatch(graph, [
                    (["id": 1, "authorId": 2, "title": "Foe", "year": 1986], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 2, "authorId": 2, "title": "Three Stories", "year": 2014], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 3, "authorId": 3, "title": "Moby-Dick", "year": 1851], nil),
                    (["id": 4, "authorId": 4, "title": "New York 2140", "year": 2017], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 5, "authorId": 4, "title": "2312", "year": 2012], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 9, "authorId": nil, "title": "Unattributed", "year": 2017], nil),
                    ])
            }
            
            do {
                // ordered books
                let graph = try Book
                    .including(Book.optionalAuthor.order(Column("name")))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".*, "authors".* \
                    FROM "books" \
                    LEFT JOIN "authors" ON ("authors"."id" = "books"."authorId") \
                    ORDER BY "authors"."name"
                    """)
                
                assertMatch(graph, [
                    (["id": 9, "authorId": nil, "title": "Unattributed", "year": 2017], nil),
                    (["id": 3, "authorId": 3, "title": "Moby-Dick", "year": 1851], ["id": 3, "name": "Herman Melville", "birthYear": 1819]),
                    (["id": 1, "authorId": 2, "title": "Foe", "year": 1986], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 2, "authorId": 2, "title": "Three Stories", "year": 2014], ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940]),
                    (["id": 4, "authorId": 4, "title": "New York 2140", "year": 2017], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 5, "authorId": 4, "title": "2312", "year": 2012], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    (["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993], ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952]),
                    ])
            }
        }
    }
    
    func testRecursion() throws {
        struct Person : TableMapping {
            static let databaseTableName = "persons"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("parentId", .integer).references("persons")
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Person.belongsTo(optional: Person.self)
                let request = Person.including(association)
                try assertEqualSQL(db, request, """
                    SELECT "persons1".*, "persons2".* \
                    FROM "persons" "persons1" \
                    LEFT JOIN "persons" "persons2" ON ("persons2"."id" = "persons1"."parentId")
                    """)
            }
        }
    }
    
    func testLeftAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let request = Book.all()
                    .aliased("b")
                    .filter(Column("year") < 2000)
                    .including(Book.optionalAuthor)
                try assertEqualSQL(db, request, """
                    SELECT "b".*, "authors".* \
                    FROM "books" "b" \
                    LEFT JOIN "authors" ON ("authors"."id" = "b"."authorId") \
                    WHERE ("b"."year" < 2000)
                    """)
            }
            
            do {
                // alias last
                let request = Book
                    .including(Book.optionalAuthor)
                    .filter(Column("year") < 2000)
                    .aliased("b")
                try assertEqualSQL(db, request, """
                    SELECT "b".*, "authors".* \
                    FROM "books" "b" \
                    LEFT JOIN "authors" ON ("authors"."id" = "b"."authorId") \
                    WHERE ("b"."year" < 2000)
                    """)
            }
        }
    }
    
    func testRightAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let request = Book
                    .including(Book.optionalAuthor
                        .aliased("a")
                        .order(Column("name")))
                    .filter(Column("birthYear").from("a") >= 1900)
                try assertEqualSQL(db, request, """
                    SELECT "books".*, "a".* \
                    FROM "books" \
                    LEFT JOIN "authors" "a" ON ("a"."id" = "books"."authorId") \
                    WHERE ("a"."birthYear" >= 1900) \
                    ORDER BY "a"."name"
                    """)
            }
            
            do {
                // alias last
                let request = Book
                    .including(Book.optionalAuthor
                        .filter(Column("birthYear") >= 1900)
                        .aliased("a"))
                    .order(Column("name").from("a"))
                try assertEqualSQL(db, request, """
                    SELECT "books".*, "a".* \
                    FROM "books" \
                    LEFT JOIN "authors" "a" ON (("a"."id" = "books"."authorId") AND ("a"."birthYear" >= 1900)) \
                    ORDER BY "a"."name"
                    """)
            }
        }
    }
    
    func testLockedAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias left
                let request = Book.including(Book.optionalAuthor).aliased("AUTHORS")
                try assertEqualSQL(db, request, """
                    SELECT "AUTHORS".*, "authors1".* \
                    FROM "books" "AUTHORS" \
                    LEFT JOIN "authors" "authors1" ON ("authors1"."id" = "AUTHORS"."authorId")
                    """)
            }
            
            do {
                // alias right
                let request = Book.including(Book.optionalAuthor.aliased("BOOKS"))
                try assertEqualSQL(db, request, """
                    SELECT "books1".*, "BOOKS".* \
                    FROM "books" "books1" \
                    LEFT JOIN "authors" "BOOKS" ON ("BOOKS"."id" = "books1"."authorId")
                    """)
            }
        }
    }
    
    func testConflictingAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let request = Book.including(Book.optionalAuthor.aliased("a")).aliased("A")
                _ = try request.fetchAll(db)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "ambiguous alias: A")
                XCTAssertNil(error.sql)
                XCTAssertEqual(error.description, "SQLite error 1: ambiguous alias: A")
            }
        }
    }
}
