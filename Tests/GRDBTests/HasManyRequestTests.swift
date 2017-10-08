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

class HasManyRequestTests: GRDBTestCase {
    
    // TODO: tests for left implicit row id, and compound keys
    // TODO: test fetchOne, fetchCursor
    
    func testRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in

            do {
                let author = try Author.fetchOne(db, key: 2)!
                let request = author.all(Author.books)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE (\"authorId\" = 2)")
                assertMatch(books, [
                    ["id": 1, "authorId": 2, "title": "Foe", "year": 1986],
                    ["id": 2, "authorId": 2, "title": "Three Stories", "year": 2014],
                    ])
            }
            
            do {
                let author = try Author.fetchOne(db, key: 4)!
                let request = author.all(Author.books)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE (\"authorId\" = 4)")
                assertMatch(books, [
                    ["id": 4, "authorId": 4, "title": "New York 2140", "year": 2017],
                    ["id": 5, "authorId": 4, "title": "2312", "year": 2012],
                    ["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996],
                    ["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994],
                    ["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993],
                    ])
            }
            
            do {
                let author = try Author.fetchOne(db, key: 1)!
                let request = author.all(Author.books)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE (\"authorId\" = 1)")
                XCTAssertTrue(books.isEmpty)
            }
            
            do {
                let author = try Author.fetchOne(db, key: 4)!
                let request = author.all(Author.books).filter(Column("year") < 2000)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE ((\"year\" < 2000) AND (\"authorId\" = 4))")
                assertMatch(books, [
                    ["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996],
                    ["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994],
                    ["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993],
                    ])
            }
            
            do {
                let author = try Author.fetchOne(db, key: 4)!
                let request = author.all(Author.books).order(Column("title").desc)
                let books = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE (\"authorId\" = 4) ORDER BY \"title\" DESC")
                assertMatch(books, [
                    ["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993],
                    ["id": 4, "authorId": 4, "title": "New York 2140", "year": 2017],
                    ["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994],
                    ["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996],
                    ["id": 5, "authorId": 4, "title": "2312", "year": 2012],
                    ])
            }
        }
    }
    
    func testFetchAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            
            do {
                let author = try Author.fetchOne(db, key: 2)!
                let books = try author.fetchAll(db, Author.books)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE (\"authorId\" = 2)")
                assertMatch(books, [
                    ["id": 1, "authorId": 2, "title": "Foe", "year": 1986],
                    ["id": 2, "authorId": 2, "title": "Three Stories", "year": 2014],
                    ])
            }
            
            do {
                let author = try Author.fetchOne(db, key: 4)!
                let books = try author.fetchAll(db, Author.books)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE (\"authorId\" = 4)")
                assertMatch(books, [
                    ["id": 4, "authorId": 4, "title": "New York 2140", "year": 2017],
                    ["id": 5, "authorId": 4, "title": "2312", "year": 2012],
                    ["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996],
                    ["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994],
                    ["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993],
                    ])
            }
            
            do {
                let author = try Author.fetchOne(db, key: 1)!
                let books = try author.fetchAll(db, Author.books)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE (\"authorId\" = 1)")
                XCTAssertTrue(books.isEmpty)
            }
            
            do {
                let author = try Author.fetchOne(db, key: 4)!
                let books = try author.fetchAll(db, Author.books.filter(Column("year") < 2000))
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE ((\"year\" < 2000) AND (\"authorId\" = 4))")
                assertMatch(books, [
                    ["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996],
                    ["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994],
                    ["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993],
                    ])
            }
            
            do {
                let author = try Author.fetchOne(db, key: 4)!
                let books = try author.fetchAll(db, Author.books.order(Column("title").desc))
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"books\" WHERE (\"authorId\" = 4) ORDER BY \"title\" DESC")
                assertMatch(books, [
                    ["id": 8, "authorId": 4, "title": "Red Mars", "year": 1993],
                    ["id": 4, "authorId": 4, "title": "New York 2140", "year": 2017],
                    ["id": 7, "authorId": 4, "title": "Green Mars", "year": 1994],
                    ["id": 6, "authorId": 4, "title": "Blue Mars", "year": 1996],
                    ["id": 5, "authorId": 4, "title": "2312", "year": 2012],
                    ])
            }
        }
    }
}
