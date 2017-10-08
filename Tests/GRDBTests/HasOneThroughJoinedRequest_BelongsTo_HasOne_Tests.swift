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

class HasOneThroughJoinedRequest_BelongsTo_HasOne_Tests: GRDBTestCase {
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Book
                .joined(with: Book.libraryAddress)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, """
                SELECT "books".* \
                FROM "books" \
                LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id")
                """)
            
            assertMatch(graph, [
                ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil],
                ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                ["isbn": "book3", "title": "Walden", "libraryId": 1],
                ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3],
                ["isbn": "book8", "title": "Necronomicon", "libraryId": 4],
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
                    .joined(with: Book.libraryAddress)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id") \
                    WHERE ("books"."title" <> 'Walden')
                    """)
                
                assertMatch(graph, [
                    ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3],
                    ["isbn": "book8", "title": "Necronomicon", "libraryId": 4],
                    ])
            }
            
            do {
                // filter after
                let graph = try Book
                    .joined(with: Book.libraryAddress)
                    .filter(Column("title") != "Walden")
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id") \
                    WHERE ("books"."title" <> 'Walden')
                    """)
                
                assertMatch(graph, [
                    ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3],
                    ["isbn": "book8", "title": "Necronomicon", "libraryId": 4],
                    ])
            }
            
            do {
                // order before
                let graph = try Book
                    .order(Column("title").desc)
                    .joined(with: Book.libraryAddress)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id") \
                    ORDER BY "books"."title" DESC
                    """)
                
                assertMatch(graph, [
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book8", "title": "Necronomicon", "libraryId": 4],
                    ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ])
            }
            
            do {
                // order after
                let graph = try Book
                    .joined(with: Book.libraryAddress)
                    .order(Column("title").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id") \
                    ORDER BY "books"."title" DESC
                    """)
                
                assertMatch(graph, [
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book8", "title": "Necronomicon", "libraryId": 4],
                    ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
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
                    .joined(with: association)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON (("libraries"."id" = "books"."libraryId") AND ("libraries"."name" <> 'Secret Library')) \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id")
                    """)
                
                // TODO: is it expected to have books of the secret library here?
                // TODO: how to get books that are not in the secret library?
                assertMatch(graph, [
                    ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3],
                    ["isbn": "book8", "title": "Necronomicon", "libraryId": 4],
                    ])
            }
            
            do {
                let middleAssociation = Book.library.order(Column("name").desc)
                let association = Book.hasOne(Library.address, through: middleAssociation)
                let graph = try Book
                    .joined(with: association)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id")
                    """)
                
                assertMatch(graph, [
                    ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3],
                    ["isbn": "book8", "title": "Necronomicon", "libraryId": 4],
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
                    .joined(with: Book.libraryAddress.filter(Column("city") != "Paris"))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON (("libraryAddresses"."libraryId" = "libraries"."id") AND ("libraryAddresses"."city" <> 'Paris'))
                    """)
                
                // TODO: is it expected to have books in Paris here?
                // TODO: how to get books that are not in Paris?
                assertMatch(graph, [
                    ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3],
                    ["isbn": "book8", "title": "Necronomicon", "libraryId": 4],
                    ])
            }
            
            do {
                let graph = try Book
                    .joined(with: Book.libraryAddress.order(Column("city").desc))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id")
                    """)
                
                assertMatch(graph, [
                    ["isbn": "book1", "title": "Moby-Dick", "libraryId": nil],
                    ["isbn": "book2", "title": "The Fellowship of the Ring", "libraryId": 1],
                    ["isbn": "book3", "title": "Walden", "libraryId": 1],
                    ["isbn": "book4", "title": "Le Comte de Monte-Cristo", "libraryId": 1],
                    ["isbn": "book5", "title": "Querelle de Brest", "libraryId": 2],
                    ["isbn": "book6", "title": "Eden, Eden, Eden", "libraryId": 2],
                    ["isbn": "book7", "title": "Jonathan Livingston Seagull", "libraryId": 3],
                    ["isbn": "book8", "title": "Necronomicon", "libraryId": 4],
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
                let middleAssociation = Person.belongsTo(Person.self, foreignKey: ["parentId"])
                let rightAssociation = Person.hasOne(Person.self, foreignKey: ["childId"])
                let association = Person.hasOne(rightAssociation, through: middleAssociation)
                let request = Person.joined(with: association)
                try assertEqualSQL(db, request, """
                    SELECT "persons1".* \
                    FROM "persons" "persons1" \
                    LEFT JOIN "persons" "persons2" ON ("persons2"."id" = "persons1"."parentId") \
                    LEFT JOIN "persons" "persons3" ON ("persons3"."childId" = "persons2"."id")
                    """)
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
                    .joined(with: Book.libraryAddress)
                try assertEqualSQL(db, request, """
                    SELECT "c".* \
                    FROM "books" "c" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "c"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id") \
                    WHERE ("c"."title" <> 'Walden')
                    """)
            }
            
            do {
                // alias last
                let request = Book
                    .filter(Column("title") != "Walden")
                    .joined(with: Book.libraryAddress)
                    .aliased("c")
                try assertEqualSQL(db, request, """
                    SELECT "c".* \
                    FROM "books" "c" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "c"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id") \
                    WHERE ("c"."title" <> 'Walden')
                    """)
            }
            
            do {
                // alias with table name (TODO: port this test to all testLeftAlias() tests)
                let request = Book.all()
                    .aliased("books")
                    .joined(with: Book.libraryAddress)
                try assertEqualSQL(db, request, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id")
                    """)
            }
        }
    }
    
    func testMiddleAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let association = Book.hasOne(Library.address, through: Book.library.aliased("a"))
                let request = Book.joined(with: association)
                try assertEqualSQL(db, request, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" "a" ON ("a"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "a"."id")
                    """)
            }
            do {
                // alias with table name
                let association = Book.hasOne(Library.address, through: Book.library.aliased("libraries"))
                let request = Book.joined(with: association)
                try assertEqualSQL(db, request, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id")
                    """)
            }
        }
    }
    
    func testRightAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let request = Book.joined(with:
                    Book.libraryAddress
                        .aliased("a")
                        .filter(Column("city") != "Paris"))
                    .order(Column("city").from("a").desc)
                try assertEqualSQL(db, request, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" "a" ON (("a"."libraryId" = "libraries"."id") AND ("a"."city" <> 'Paris')) \
                    ORDER BY "a"."city" DESC
                    """)
            }
            
            do {
                // alias last
                let request = Book.joined(with:
                    Book.libraryAddress
                        .order(Column("city").desc)
                        .aliased("a"))
                    .filter(Column("city").from("a") != "Paris")
                try assertEqualSQL(db, request, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" "a" ON ("a"."libraryId" = "libraries"."id") \
                    WHERE ("a"."city" <> 'Paris')
                    """)
            }
            
            do {
                // alias with table name (TODO: port this test to all testRightAlias() tests)
                let request = Book.joined(with: Book.libraryAddress.aliased("libraryAddresses"))
                try assertEqualSQL(db, request, """
                    SELECT "books".* \
                    FROM "books" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books"."libraryId") \
                    LEFT JOIN "libraryAddresses" ON ("libraryAddresses"."libraryId" = "libraries"."id")
                    """)
            }
            
        }
    }
    
    func testLockedAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias left
                let request = Book.joined(with: Book.libraryAddress).aliased("LIBRARYADDRESSES")
                try assertEqualSQL(db, request, """
                    SELECT "LIBRARYADDRESSES".* \
                    FROM "books" "LIBRARYADDRESSES" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "LIBRARYADDRESSES"."libraryId") \
                    LEFT JOIN "libraryAddresses" "libraryAddresses1" ON ("libraryAddresses1"."libraryId" = "libraries"."id")
                    """)
            }
            
            do {
                // alias right
                let request = Book.joined(with: Book.libraryAddress.aliased("BOOKS"))
                try assertEqualSQL(db, request, """
                    SELECT "books1".* \
                    FROM "books" "books1" \
                    LEFT JOIN "libraries" ON ("libraries"."id" = "books1"."libraryId") \
                    LEFT JOIN "libraryAddresses" "BOOKS" ON ("BOOKS\"."libraryId" = "libraries"."id")
                    """)
            }
        }
    }
    
    func testConflictingAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let request = Book.joined(with: Book.libraryAddress.aliased("a")).aliased("A")
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
