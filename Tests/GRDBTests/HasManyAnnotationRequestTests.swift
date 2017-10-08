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

class HasManyAnnotationRequestTests: GRDBTestCase {
    
    // TODO: tests for left implicit row id, and compound keys
    // TODO: test fetchOne, fetchCursor
    // TODO: test sql snippets with table aliases
    // TODO: test left and right derivations at the same time
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Author
                .annotated(with: Author.books.count)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, "SELECT \"authors\".*, COUNT(\"books\".\"id\") FROM \"authors\" LEFT JOIN \"books\" ON (\"books\".\"authorId\" = \"authors\".\"id\") GROUP BY \"authors\".\"id\"")
            
            assertMatch(graph, [
                (["id": 1, "name": "Gwendal Roué", "birthYear": 1973], 0),
                (["id": 2, "name": "J. M. Coetzee", "birthYear": 1940], 2),
                (["id": 3, "name": "Herman Melville", "birthYear": 1819], 1),
                (["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952], 5),
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
                    .annotated(with: Author.books.count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"authors\".*, COUNT(\"books\".\"id\") FROM \"authors\" LEFT JOIN \"books\" ON (\"books\".\"authorId\" = \"authors\".\"id\") WHERE (\"authors\".\"birthYear\" >= 1900) GROUP BY \"authors\".\"id\"")
                
                assertMatch(graph, [
                    (["id": 1, "name": "Gwendal Roué", "birthYear": 1973], 0),
                    (["id": 2, "name": "J. M. Coetzee", "birthYear": 1940], 2),
                    (["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952], 5),
                    ])
            }
            
            do {
                // filter after
                let graph = try Author
                    .annotated(with: Author.books.count)
                    .filter(Column("birthYear") >= 1900)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"authors\".*, COUNT(\"books\".\"id\") FROM \"authors\" LEFT JOIN \"books\" ON (\"books\".\"authorId\" = \"authors\".\"id\") WHERE (\"authors\".\"birthYear\" >= 1900) GROUP BY \"authors\".\"id\"")
                
                assertMatch(graph, [
                    (["id": 1, "name": "Gwendal Roué", "birthYear": 1973], 0),
                    (["id": 2, "name": "J. M. Coetzee", "birthYear": 1940], 2),
                    (["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952], 5),
                    ])
            }
            
            do {
                // order before
                let graph = try Author
                    .order(Column("name").desc)
                    .annotated(with: Author.books.count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"authors\".*, COUNT(\"books\".\"id\") FROM \"authors\" LEFT JOIN \"books\" ON (\"books\".\"authorId\" = \"authors\".\"id\") GROUP BY \"authors\".\"id\" ORDER BY \"authors\".\"name\" DESC")
                
                assertMatch(graph, [
                    (["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952], 5),
                    (["id": 2, "name": "J. M. Coetzee", "birthYear": 1940], 2),
                    (["id": 3, "name": "Herman Melville", "birthYear": 1819], 1),
                    (["id": 1, "name": "Gwendal Roué", "birthYear": 1973], 0),
                    ])
            }
            
            do {
                // order after
                let graph = try Author
                    .annotated(with: Author.books.count)
                    .order(Column("name").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"authors\".*, COUNT(\"books\".\"id\") FROM \"authors\" LEFT JOIN \"books\" ON (\"books\".\"authorId\" = \"authors\".\"id\") GROUP BY \"authors\".\"id\" ORDER BY \"authors\".\"name\" DESC")
                
                assertMatch(graph, [
                    (["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952], 5),
                    (["id": 2, "name": "J. M. Coetzee", "birthYear": 1940], 2),
                    (["id": 3, "name": "Herman Melville", "birthYear": 1819], 1),
                    (["id": 1, "name": "Gwendal Roué", "birthYear": 1973], 0),
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
                    .annotated(with: Author.books.filter(Column("year") < 2000).count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"authors\".*, COUNT(\"books\".\"id\") FROM \"authors\" LEFT JOIN \"books\" ON ((\"books\".\"authorId\" = \"authors\".\"id\") AND (\"books\".\"year\" < 2000)) GROUP BY \"authors\".\"id\"")
                
                assertMatch(graph, [
                    (["id": 1, "name": "Gwendal Roué", "birthYear": 1973], 0),
                    (["id": 2, "name": "J. M. Coetzee", "birthYear": 1940], 1),
                    (["id": 3, "name": "Herman Melville", "birthYear": 1819], 1),
                    (["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952], 3),
                    ])
            }
            
            do {
                // ordered books
                let graph = try Author
                    .annotated(with: Author.books.order(Column("title")).count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"authors\".*, COUNT(\"books\".\"id\") FROM \"authors\" LEFT JOIN \"books\" ON (\"books\".\"authorId\" = \"authors\".\"id\") GROUP BY \"authors\".\"id\"")
                
                assertMatch(graph, [
                    (["id": 1, "name": "Gwendal Roué", "birthYear": 1973], 0),
                    (["id": 2, "name": "J. M. Coetzee", "birthYear": 1940], 2),
                    (["id": 3, "name": "Herman Melville", "birthYear": 1819], 1),
                    (["id": 4, "name": "Kim Stanley Robinson", "birthYear": 1952], 5),
                    ])
            }
        }
    }
}
