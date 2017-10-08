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

class BelongsToRequestTests: GRDBTestCase {
    
    func testRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            
            do {
                let book = try Book.fetchOne(db, key: 1)!
                let request = book.request(Book.author)
                let author = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"authors\" WHERE (\"id\" = 2)")
                assertMatch(author, ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940])
            }
            
            do {
                let book = try Book.fetchOne(db, key: 9)!
                let request = book.request(Book.author)
                let author = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"authors\" WHERE (\"id\" IS NULL)")
                XCTAssertNil(author)
            }
        }
    }
    
    func testFetchOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            
            do {
                let book = try Book.fetchOne(db, key: 1)!
                let author = try book.fetchOne(db, Book.author)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"authors\" WHERE (\"id\" = 2)")
                assertMatch(author, ["id": 2, "name": "J. M. Coetzee", "birthYear": 1940])
            }
            
            do {
                let book = try Book.fetchOne(db, key: 9)!
                let author = try book.fetchOne(db, Book.author)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"authors\" WHERE (\"id\" IS NULL)")
                XCTAssertNil(author)
            }
        }
    }
    
    func testRecursion() throws {
        struct Person : TableMapping, MutablePersistable {
            static let databaseTableName = "persons"
            func encode(to container: inout PersistenceContainer) {
                container["parentId"] = 1
            }
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
                let association = Person.belongsTo(Person.self)
                let request = Person().request(association)
                try assertEqualSQL(db, request, "SELECT * FROM \"persons\" WHERE (\"id\" = 1)")
            }
        }
    }
    
    func testRightAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let book = try Book.fetchOne(db, key: 1)!
                let request = book.request(Book.author.aliased("a"))
                try assertEqualSQL(db, request, "SELECT \"a\".* FROM \"authors\" \"a\" WHERE (\"a\".\"id\" = 2)")
            }
            
            do {
                // alias last
                let book = try Book.fetchOne(db, key: 1)!
                let request = book.request(Book.author).aliased("a")
                try assertEqualSQL(db, request, "SELECT \"a\".* FROM \"authors\" \"a\" WHERE (\"a\".\"id\" = 2)")
            }
        }
    }
}
