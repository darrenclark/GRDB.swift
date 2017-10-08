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

class HasManyThroughAnnotationRequest_BelongsTo_HasMany_Tests: GRDBTestCase {
    
    // TODO: conditions on middle table
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Reader
                .annotated(with: Reader.books.count)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, "SELECT \"readers\".*, COUNT(\"books\".\"isbn\") FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\"")
            
            assertMatch(graph, [
                (["email": "arthur@example.com", "libraryId": nil], 0),
                (["email": "barbara@example.com", "libraryId": 1], 3),
                (["email": "craig@example.com", "libraryId": 2], 2),
                (["email": "david@example.com", "libraryId": 2], 2),
                (["email": "eve@example.com", "libraryId": 3], 0),
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
                    .annotated(with: Reader.books.count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".*, COUNT(\"books\".\"isbn\") FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") WHERE (\"readers\".\"email\" <> \'barbara@example.com\') GROUP BY \"readers\".\"email\"")
                
                assertMatch(graph, [
                    (["email": "arthur@example.com", "libraryId": nil], 0),
                    (["email": "craig@example.com", "libraryId": 2], 2),
                    (["email": "david@example.com", "libraryId": 2], 2),
                    (["email": "eve@example.com", "libraryId": 3], 0),
                    ])
            }
            
            do {
                // filter after
                let graph = try Reader
                    .annotated(with: Reader.books.count)
                    .filter(Column("email") != "barbara@example.com")
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".*, COUNT(\"books\".\"isbn\") FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") WHERE (\"readers\".\"email\" <> \'barbara@example.com\') GROUP BY \"readers\".\"email\"")
                
                assertMatch(graph, [
                    (["email": "arthur@example.com", "libraryId": nil], 0),
                    (["email": "craig@example.com", "libraryId": 2], 2),
                    (["email": "david@example.com", "libraryId": 2], 2),
                    (["email": "eve@example.com", "libraryId": 3], 0),
                    ])
            }
            
            do {
                // order before
                let graph = try Reader
                    .order(Column("email").desc)
                    .annotated(with: Reader.books.count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".*, COUNT(\"books\".\"isbn\") FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\" ORDER BY \"readers\".\"email\" DESC")
                
                assertMatch(graph, [
                    (["email": "eve@example.com", "libraryId": 3], 0),
                    (["email": "david@example.com", "libraryId": 2], 2),
                    (["email": "craig@example.com", "libraryId": 2], 2),
                    (["email": "barbara@example.com", "libraryId": 1], 3),
                    (["email": "arthur@example.com", "libraryId": nil], 0),
                    ])
            }
            
            do {
                // order after
                let graph = try Reader
                    .annotated(with: Reader.books.count)
                    .order(Column("email").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".*, COUNT(\"books\".\"isbn\") FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\" ORDER BY \"readers\".\"email\" DESC")
                
                assertMatch(graph, [
                    (["email": "eve@example.com", "libraryId": 3], 0),
                    (["email": "david@example.com", "libraryId": 2], 2),
                    (["email": "craig@example.com", "libraryId": 2], 2),
                    (["email": "barbara@example.com", "libraryId": 1], 3),
                    (["email": "arthur@example.com", "libraryId": nil], 0),
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
                    .annotated(with: Reader.books.filter(Column("title") != "Walden").count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".*, COUNT(\"books\".\"isbn\") FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON ((\"books\".\"libraryId\" = \"libraries\".\"id\") AND (\"books\".\"title\" <> \'Walden\')) GROUP BY \"readers\".\"email\"")
                
                assertMatch(graph, [
                    (["email": "arthur@example.com", "libraryId": nil], 0),
                    (["email": "barbara@example.com", "libraryId": 1], 2),
                    (["email": "craig@example.com", "libraryId": 2], 2),
                    (["email": "david@example.com", "libraryId": 2], 2),
                    (["email": "eve@example.com", "libraryId": 3], 0),
                    ])
            }
            
            do {
                // ordered books
                let graph = try Reader
                    .annotated(with: Reader.books.order(Column("title")).count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".*, COUNT(\"books\".\"isbn\") FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\"")
                
                assertMatch(graph, [
                    (["email": "arthur@example.com", "libraryId": nil], 0),
                    (["email": "barbara@example.com", "libraryId": 1], 3),
                    (["email": "craig@example.com", "libraryId": 2], 2),
                    (["email": "david@example.com", "libraryId": 2], 2),
                    (["email": "eve@example.com", "libraryId": 3], 0),
                    ])
            }
        }
    }
}
