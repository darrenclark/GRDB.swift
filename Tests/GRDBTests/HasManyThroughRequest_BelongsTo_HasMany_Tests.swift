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

class HasManyThroughRequest_BelongsTo_HasMany_Tests: GRDBTestCase {
    
    // TODO: conditions on middle table
    
    func testRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in

            do {
                let reader = try Reader.fetchOne(db, key: "arthur@example.com")!
                let request = reader.request(Reader.books)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" IS NULL))")
                XCTAssertTrue(books.isEmpty)
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "barbara@example.com")!
                let request = reader.request(Reader.books)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 1))")
                assertMatch(books, [
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ])
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "craig@example.com")!
                let request = reader.request(Reader.books)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 2))")
                assertMatch(books, [
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ])
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "eve@example.com")!
                let request = reader.request(Reader.books)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 3))")
                XCTAssertTrue(books.isEmpty)
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "barbara@example.com")!
                let request = reader.request(Reader.books).filter(Column("title") != "Walden")
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 1)) WHERE (\"books\".\"title\" <> \'Walden\')")
                assertMatch(books, [
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ])
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "barbara@example.com")!
                let request = reader.request(Reader.books).order(Column("title").desc)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 1)) ORDER BY \"books\".\"title\" DESC")
                assertMatch(books, [
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ])
            }
        }
    }
    
    func testFetchAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_BelongsTo_HasMany_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            
            do {
                let reader = try Reader.fetchOne(db, key: "arthur@example.com")!
                let books = try reader.fetchAll(db, Reader.books)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" IS NULL))")
                XCTAssertTrue(books.isEmpty)
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "barbara@example.com")!
                let books = try reader.fetchAll(db, Reader.books)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 1))")
                assertMatch(books, [
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ])
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "craig@example.com")!
                let books = try reader.fetchAll(db, Reader.books)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 2))")
                assertMatch(books, [
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ])
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "eve@example.com")!
                let books = try reader.fetchAll(db, Reader.books)
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 3))")
                XCTAssertTrue(books.isEmpty)
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "barbara@example.com")!
                let books = try reader.fetchAll(db, Reader.books.filter(Column("title") != "Walden"))
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 1)) WHERE (\"books\".\"title\" <> \'Walden\')")
                assertMatch(books, [
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ])
            }
            
            do {
                let reader = try Reader.fetchOne(db, key: "barbara@example.com")!
                let books = try reader.fetchAll(db, Reader.books.order(Column("title").desc))
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"id\" = 1)) ORDER BY \"books\".\"title\" DESC")
                assertMatch(books, [
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ])
            }
        }
    }
}
