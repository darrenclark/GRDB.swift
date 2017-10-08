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

class HasManyAnnotationPredicateRequestTests: GRDBTestCase {
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Author
                .filter(Author.books.count > 0)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, """
                SELECT "authors".* \
                FROM "authors" \
                LEFT JOIN "books" ON ("books"."authorId" = "authors"."id") \
                GROUP BY "authors"."id" \
                HAVING (COUNT("books"."id") > 0)
                """)
            
            assertMatch(graph, [
                ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940],
                ["id": 3, "name": "Herman Melville", "birthYear": 1819],
                ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952],
                ])
        }
    }
    
    func testLeftRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filter before
                let graph = try Author
                    .filter(Column("birthYear") >= 1900)
                    .filter(Author.books.count > 0)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "authors".* \
                    FROM "authors" \
                    LEFT JOIN "books" ON ("books"."authorId" = "authors"."id") \
                    WHERE ("authors"."birthYear" >= 1900) \
                    GROUP BY "authors"."id" \
                    HAVING (COUNT("books"."id\") > 0)
                    """)
                
                assertMatch(graph, [
                    ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940],
                    ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952],
                    ])
            }
            
            do {
                // filter after
                let graph = try Author
                    .filter(Author.books.count > 0)
                    .filter(Column("birthYear") >= 1900)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "authors".* \
                    FROM "authors" \
                    LEFT JOIN "books" ON ("books"."authorId" = "authors"."id") \
                    WHERE ("authors"."birthYear" >= 1900) \
                    GROUP BY "authors"."id" \
                    HAVING (COUNT("books"."id") > 0)
                    """)
                
                assertMatch(graph, [
                    ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940],
                    ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952],
                    ])
            }
            
            do {
                // order before
                let graph = try Author
                    .order(Column("name").desc)
                    .filter(Author.books.count > 0)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "authors".* \
                    FROM "authors" \
                    LEFT JOIN "books" ON ("books"."authorId" = "authors"."id") \
                    GROUP BY "authors"."id" \
                    HAVING (COUNT("books"."id") > 0) \
                    ORDER BY "authors"."name" DESC
                    """)
                
                assertMatch(graph, [
                    ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952],
                    ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940],
                    ["id": 3, "name": "Herman Melville", "birthYear": 1819],
                    ])
            }
            
            do {
                // order after
                let graph = try Author
                    .filter(Author.books.count > 0)
                    .order(Column("name").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "authors".* \
                    FROM "authors" \
                    LEFT JOIN "books" ON ("books"."authorId" = "authors"."id") \
                    GROUP BY "authors"."id" \
                    HAVING (COUNT("books"."id") > 0) \
                    ORDER BY "authors"."name" DESC
                    """)
                
                assertMatch(graph, [
                    ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952],
                    ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940],
                    ["id": 3, "name": "Herman Melville", "birthYear": 1819],
                    ])
            }
        }
    }
    
    func testRightRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filtered books
                let graph = try Author
                    .filter(Author.books.filter(Column("year") >= 2000).count > 0)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "authors".* \
                    FROM "authors" \
                    LEFT JOIN "books" ON (("books"."authorId" = "authors"."id") AND ("books"."year" >= 2000)) \
                    GROUP BY "authors"."id" \
                    HAVING (COUNT("books"."id") > 0)
                    """)
                
                assertMatch(graph, [
                    ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940],
                    ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952],
                    ])
            }
        }
    }

    func testEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Author
                .filter(Author.books.count == 1)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, """
                SELECT "authors".* \
                FROM "authors" \
                LEFT JOIN "books" ON ("books"."authorId" = "authors"."id") \
                GROUP BY "authors"."id" \
                HAVING (COUNT("books"."id") = 1)
                """)
            
            assertMatch(graph, [
                ["id": 3, "name": "Herman Melville", "birthYear": 1819],
                ])
        }
    }
    
    func testIsEmpty() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Author
                .filter(Author.books.isEmpty)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, """
                SELECT "authors".* \
                FROM "authors" \
                LEFT JOIN "books" ON ("books"."authorId" = "authors"."id") \
                GROUP BY "authors"."id" \
                HAVING (COUNT("books"."id") = 0)
                """)
            
            assertMatch(graph, [
                ["id": 1, "name": "Gwendal Roué", "birthYear": 1973],
                ])
        }
    }
    
    func testNotIsEmpty() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Author
                .filter(!Author.books.isEmpty)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, """
                SELECT "authors".* \
                FROM "authors" \
                LEFT JOIN "books" ON ("books"."authorId" = "authors"."id") \
                GROUP BY "authors"."id" \
                HAVING (COUNT("books"."id") <> 0)
                """)
            
            assertMatch(graph, [
                ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940],
                ["id": 3, "name": "Herman Melville", "birthYear": 1819],
                ["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952],
                ])
        }
    }
}
