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

class HasManyThroughAnnotationPredicateRequest_BelongsTo_HasMany_Tests: GRDBTestCase {
    
    // TODO: conditions on middle table
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Reader
                .filter(Reader.books.count > 0)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, "SELECT \"readers\".* FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\" HAVING (COUNT(\"books\".\"isbn\") > 0)")
            
            assertMatch(graph, [
                ["email": "barbara@example.com", "libraryId": 1],
                ["email": "craig@example.com", "libraryId": 2],
                ["email": "david@example.com", "libraryId": 2],
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
                    .filter(Reader.books.count > 0)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".* FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") WHERE (\"readers\".\"email\" <> \'barbara@example.com\') GROUP BY \"readers\".\"email\" HAVING (COUNT(\"books\".\"isbn\") > 0)")
                
                assertMatch(graph, [
                    ["email": "craig@example.com", "libraryId": 2],
                    ["email": "david@example.com", "libraryId": 2],
                    ])
            }
            
            do {
                // filter after
                let graph = try Reader
                    .filter(Reader.books.count > 0)
                    .filter(Column("email") != "barbara@example.com")
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".* FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") WHERE (\"readers\".\"email\" <> \'barbara@example.com\') GROUP BY \"readers\".\"email\" HAVING (COUNT(\"books\".\"isbn\") > 0)")
                
                assertMatch(graph, [
                    ["email": "craig@example.com", "libraryId": 2],
                    ["email": "david@example.com", "libraryId": 2],
                    ])
            }
            
            do {
                // order before
                let graph = try Reader
                    .order(Column("email").desc)
                    .filter(Reader.books.count > 0)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".* FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\" HAVING (COUNT(\"books\".\"isbn\") > 0) ORDER BY \"readers\".\"email\" DESC")
                
                assertMatch(graph, [
                    ["email": "david@example.com", "libraryId": 2],
                    ["email": "craig@example.com", "libraryId": 2],
                    ["email": "barbara@example.com", "libraryId": 1],
                    ])
            }
            
            do {
                // order after
                let graph = try Reader
                    .filter(Reader.books.count > 0)
                    .order(Column("email").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".* FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\" HAVING (COUNT(\"books\".\"isbn\") > 0) ORDER BY \"readers\".\"email\" DESC")
                
                assertMatch(graph, [
                    ["email": "david@example.com", "libraryId": 2],
                    ["email": "craig@example.com", "libraryId": 2],
                    ["email": "barbara@example.com", "libraryId": 1],
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
                    .filter(Reader.books.filter(Column("title") != "Walden").count == 2)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"readers\".* FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON ((\"books\".\"libraryId\" = \"libraries\".\"id\") AND (\"books\".\"title\" <> \'Walden\')) GROUP BY \"readers\".\"email\" HAVING (COUNT(\"books\".\"isbn\") = 2)")
                
                assertMatch(graph, [
                    ["email": "barbara@example.com", "libraryId": 1],
                    ["email": "craig@example.com", "libraryId": 2],
                    ["email": "david@example.com", "libraryId": 2],
                    ])
            }
        }
    }
    
    func testEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Reader
                .filter(Reader.books.count > 2)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, "SELECT \"readers\".* FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\" HAVING (COUNT(\"books\".\"isbn\") > 2)")
            
            assertMatch(graph, [
                ["email": "barbara@example.com", "libraryId": 1],
                ])
        }
    }
    
    func testIsEmpty() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Reader
                .filter(Reader.books.isEmpty)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, "SELECT \"readers\".* FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\" HAVING (COUNT(\"books\".\"isbn\") = 0)")
            
            assertMatch(graph, [
                ["email": "arthur@example.com", "libraryId": nil],
                ["email": "eve@example.com", "libraryId": 3],
                ])
        }
    }
    
    func testNotIsEmpty() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Reader
                .filter(!Reader.books.isEmpty)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, "SELECT \"readers\".* FROM \"readers\" LEFT JOIN \"libraries\" ON (\"libraries\".\"id\" = \"readers\".\"libraryId\") LEFT JOIN \"books\" ON (\"books\".\"libraryId\" = \"libraries\".\"id\") GROUP BY \"readers\".\"email\" HAVING (COUNT(\"books\".\"isbn\") <> 0)")
            
            assertMatch(graph, [
                ["email": "barbara@example.com", "libraryId": 1],
                ["email": "craig@example.com", "libraryId": 2],
                ["email": "david@example.com", "libraryId": 2],
                ])
        }
    }
}
