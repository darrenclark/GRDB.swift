import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private typealias Book = HasOneThrough_BelongsTo_HasOne_Fixture.Book
private typealias Library = HasOneThrough_BelongsTo_HasOne_Fixture.Library
private typealias LibraryAddress = HasOneThrough_BelongsTo_HasOne_Fixture.LibraryAddress

class HasOneThroughIncludingRequest_BelongsTo_HasOne_Tests: GRDBTestCase {
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Book
                .including(Book.libraryAddress)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\")")
            
            assertMatch(graph, [
                (["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                (["isbn": "book3", "title": "Walden", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                (["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                (["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2], ["city": "London", "libraryId": 2]),
                (["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2], ["city": "London", "libraryId": 2]),
                (["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3], ["city": "Barcelona", "libraryId": 3]),
                ])
        }
    }
    
    func testLeftRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filter before
                let graph = try Book
                    .filter(Column("title") != "Walden")
                    .including(Book.libraryAddress)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\") WHERE (\"books\".\"title\" <> \'Walden\')")
                
                assertMatch(graph, [
                    (["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3], ["city": "Barcelona", "libraryId": 3]),
                    ])
            }
            
            do {
                // filter after
                let graph = try Book
                    .including(Book.libraryAddress)
                    .filter(Column("title") != "Walden")
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\") WHERE (\"books\".\"title\" <> \'Walden\')")
                
                assertMatch(graph, [
                    (["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3], ["city": "Barcelona", "libraryId": 3]),
                    ])
            }
            
            do {
                // order before
                let graph = try Book
                    .order(Column("title").desc)
                    .including(Book.libraryAddress)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\") ORDER BY \"books\".\"title\" DESC")
                
                assertMatch(graph, [
                    (["isbn": "book3", "title": "Walden", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3], ["city": "Barcelona", "libraryId": 3]),
                    (["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    ])
            }
            
            do {
                // order after
                let graph = try Book
                    .including(Book.libraryAddress)
                    .order(Column("title").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\") ORDER BY \"books\".\"title\" DESC")
                
                assertMatch(graph, [
                    (["isbn": "book3", "title": "Walden", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3], ["city": "Barcelona", "libraryId": 3]),
                    (["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    ])
            }
        }
    }
    
    func testMiddleRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let middleAssociation = Book.library.filter(Column("name") != "Secret Library")
                let association = Book.hasOne(Library.address, through: middleAssociation)
                let graph = try Book
                    .including(association)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON ((\"libraries\".\"id\" = \"books\".\"libraryId\") AND (\"libraries\".\"name\" <> \'Secret Library\')) JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\")")
                
                assertMatch(graph, [
                    (["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book3", "title": "Walden", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3], ["city": "Barcelona", "libraryId": 3]),
                    ])
            }
            
            do {
                let middleAssociation = Book.library.order(Column("name").desc)
                let association = Book.hasOne(Library.address, through: middleAssociation)
                let graph = try Book
                    .including(association)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\")")
                
                assertMatch(graph, [
                    (["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book3", "title": "Walden", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3], ["city": "Barcelona", "libraryId": 3]),
                    ])
            }
        }
    }
    
    func testRightRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let graph = try Book
                    .including(Book.libraryAddress.filter(Column("city") != "Paris"))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON ((\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\") AND (\"libraryAddresses\".\"city\" <> \'Paris\'))")
                
                assertMatch(graph, [
                    (["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3], ["city": "Barcelona", "libraryId": 3]),
                    ])
            }
            
            do {
                let graph = try Book
                    .including(Book.libraryAddress.order(Column("city").desc))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\") ORDER BY \"libraryAddresses\".\"city\" DESC")
                
                assertMatch(graph, [
                    (["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book3", "title": "Walden", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1], ["city": "Paris", "libraryId": 1]),
                    (["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2], ["city": "London", "libraryId": 2]),
                    (["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3], ["city": "Barcelona", "libraryId": 3]),
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
                t.column("childId", .integer).references("persons")
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let middleAssociation = Person.belongsTo(Person.self, from: "parentId")
                let rightAssociation = Person.hasOne(Person.self, from: "childId")
                let association = Person.hasOne(rightAssociation, through: middleAssociation)
                let request = Person.including(association)
                try assertEqualSQL(db, request, "SELECT \"persons1\".*, \"persons3\".* FROM \"persons\" \"persons1\" JOIN \"persons\" \"persons2\" ON (\"persons2\".\"id\" = \"persons1\".\"parentId\") JOIN \"persons\" \"persons3\" ON (\"persons3\".\"childId\" = \"persons2\".\"id\")")
            }
        }
    }
    
    func testLeftAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let request = Book.all()
                    .aliased("c")
                    .filter(Column("title") != "Walden")
                    .including(Book.libraryAddress)
                try assertEqualSQL(db, request, "SELECT \"c\".*, \"libraryAddresses\".* FROM \"books\" \"c\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"c\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\") WHERE (\"c\".\"title\" <> 'Walden')")
            }
            
            do {
                // alias last
                let request = Book
                    .filter(Column("title") != "Walden")
                    .including(Book.libraryAddress)
                    .aliased("c")
                try assertEqualSQL(db, request, "SELECT \"c\".*, \"libraryAddresses\".* FROM \"books\" \"c\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"c\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\") WHERE (\"c\".\"title\" <> 'Walden')")
            }
            
            do {
                // alias with table name (TODO: port this test to all testLeftAlias() tests)
                let request = Book.all()
                    .aliased("books")
                    .including(Book.libraryAddress)
                try assertEqualSQL(db, request, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\")")
            }
        }
    }
    
    func testMiddleAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let association = Book.hasOne(Library.address, through: Book.library.aliased("a"))
                let request = Book.including(association)
                try assertEqualSQL(db, request, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" \"a\" ON (\"a\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"a\".\"id\")")
            }
            do {
                // alias with table name
                let association = Book.hasOne(Library.address, through: Book.library.aliased("libraries"))
                let request = Book.including(association)
                try assertEqualSQL(db, request, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\")")
            }
        }
    }
    
    func testRightAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let request = Book.including(
                    Book.libraryAddress
                        .aliased("a")
                        .filter(Column("city") != "Paris"))
                    .order(Column("city").from("a").desc)
                try assertEqualSQL(db, request, "SELECT \"books\".*, \"a\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" \"a\" ON ((\"a\".\"libraryId\" = \"libraries\".\"id\") AND (\"a\".\"city\" <> \'Paris\')) ORDER BY \"a\".\"city\" DESC")
            }
            
            do {
                // alias last
                let request = Book.including(
                    Book.libraryAddress
                        .order(Column("city").desc)
                        .aliased("a"))
                    .filter(Column("city").from("a") != "Paris")
                try assertEqualSQL(db, request, "SELECT \"books\".*, \"a\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" \"a\" ON (\"a\".\"libraryId\" = \"libraries\".\"id\") WHERE (\"a\".\"city\" <> \'Paris\') ORDER BY \"a\".\"city\" DESC")
            }
            
            do {
                // alias with table name (TODO: port this test to all testRightAlias() tests)
                let request = Book.including(Book.libraryAddress.aliased("libraryAddresses"))
                try assertEqualSQL(db, request, "SELECT \"books\".*, \"libraryAddresses\".* FROM \"books\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books\".\"libraryId\") JOIN \"libraryAddresses\" ON (\"libraryAddresses\".\"libraryId\" = \"libraries\".\"id\")")
            }
            
        }
    }
    
    func testLockedAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias left
                let request = Book.including(Book.libraryAddress).aliased("LIBRARYADDRESSES")
                try assertEqualSQL(db, request, "SELECT \"LIBRARYADDRESSES\".*, \"libraryAddresses1\".* FROM \"books\" \"LIBRARYADDRESSES\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"LIBRARYADDRESSES\".\"libraryId\") JOIN \"libraryAddresses\" \"libraryAddresses1\" ON (\"libraryAddresses1\".\"libraryId\" = \"libraries\".\"id\")")
            }
            
            do {
                // alias right
                let request = Book.including(Book.libraryAddress.aliased("BOOKS"))
                try assertEqualSQL(db, request, "SELECT \"books1\".*, \"BOOKS\".* FROM \"books\" \"books1\" JOIN \"libraries\" ON (\"libraries\".\"id\" = \"books1\".\"libraryId\") JOIN \"libraryAddresses\" \"BOOKS\" ON (\"BOOKS\".\"libraryId\" = \"libraries\".\"id\")")
            }
        }
    }
    
    func testConflictingAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let request = Book.including(Book.libraryAddress.aliased("a")).aliased("A")
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
