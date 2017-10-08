import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private typealias Book = HasOneThrough_BelongsTo_HasOne_Fixture.Book
private typealias LibraryAddress = HasOneThrough_BelongsTo_HasOne_Fixture.LibraryAddress

class HasOneThroughRequest_BelongsTo_HasOne_Tests: GRDBTestCase {
    
    func testRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let book = try Book.fetchOne(db, key: "book1")!
                let request = book.request(Book.libraryAddress)
                let libraryAddress = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "libraryAddresses".* \
                    FROM "libraryAddresses" \
                    JOIN "libraries" ON (("libraries"."id" = "libraryAddresses"."libraryId") AND ("libraries"."id" IS NULL))
                    """)    // TODO: this request is weird.
                XCTAssertNil(libraryAddress)
            }
            
            do {
                let book = try Book.fetchOne(db, key: "book2")!
                let request = book.request(Book.libraryAddress)
                let libraryAddress = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "libraryAddresses".* \
                    FROM "libraryAddresses" \
                    JOIN "libraries" ON (("libraries"."id" = "libraryAddresses"."libraryId") AND ("libraries"."id" = 1))
                    """)    // TODO: this request is weird.
                assertMatch(libraryAddress, ["city": "Paris", "libraryId": 1])
            }
            
            do {
                let book = try Book.fetchOne(db, key: "book5")!
                let request = book.request(Book.libraryAddress)
                let libraryAddress = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "libraryAddresses".* \
                    FROM "libraryAddresses" \
                    JOIN "libraries" ON (("libraries"."id" = "libraryAddresses"."libraryId") AND ("libraries"."id" = 2))
                    """)    // TODO: this request is weird.
                assertMatch(libraryAddress, ["city": "London", "libraryId": 2])
            }
            
            do {
                let book = try Book.fetchOne(db, key: "book8")!
                let request = book.request(Book.libraryAddress)
                let libraryAddress = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "libraryAddresses".* \
                    FROM "libraryAddresses" \
                    JOIN "libraries" ON (("libraries"."id" = "libraryAddresses"."libraryId") AND ("libraries"."id" = 4))
                    """)    // TODO: this request is weird.
                XCTAssertNil(libraryAddress)
            }
        }
    }
    
    func testFetchOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let book = try Book.fetchOne(db, key: "book1")!
                let libraryAddress = try book.fetchOne(db, Book.libraryAddress)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "libraryAddresses".* \
                    FROM "libraryAddresses" \
                    JOIN "libraries" ON (("libraries"."id" = "libraryAddresses"."libraryId") AND ("libraries"."id" IS NULL))
                    """)    // TODO: this request is weird.
                XCTAssertNil(libraryAddress)
            }
            
            do {
                let book = try Book.fetchOne(db, key: "book2")!
                let libraryAddress = try book.fetchOne(db, Book.libraryAddress)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "libraryAddresses".* \
                    FROM "libraryAddresses" \
                    JOIN "libraries" ON (("libraries"."id" = "libraryAddresses"."libraryId") AND ("libraries"."id" = 1))
                    """)    // TODO: this request is weird.
                assertMatch(libraryAddress, ["city": "Paris", "libraryId": 1])
            }
            
            do {
                let book = try Book.fetchOne(db, key: "book5")!
                let libraryAddress = try book.fetchOne(db, Book.libraryAddress)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "libraryAddresses".* \
                    FROM "libraryAddresses" \
                    JOIN "libraries" ON (("libraries"."id" = "libraryAddresses"."libraryId") AND ("libraries"."id" = 2))
                    """)    // TODO: this request is weird.
                assertMatch(libraryAddress, ["city": "London", "libraryId": 2])
            }
            
            do {
                let book = try Book.fetchOne(db, key: "book8")!
                let libraryAddress = try book.fetchOne(db, Book.libraryAddress)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "libraryAddresses".* \
                    FROM "libraryAddresses" \
                    JOIN "libraries" ON (("libraries"."id" = "libraryAddresses"."libraryId") AND ("libraries"."id" = 4))
                    """)    // TODO: this request is weird.
                XCTAssertNil(libraryAddress)
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
                t.column("childId", .integer).references("persons")
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let middleAssociation = Person.belongsTo(Person.self, foreignKey: ["parentId"])
                let rightAssociation = Person.hasOne(Person.self, foreignKey: ["childId"])
                let association = Person.hasOne(rightAssociation, through: middleAssociation)
                let request = Person().request(association)
                try assertEqualSQL(db, request, """
                    SELECT "persons2".* \
                    FROM "persons" "persons2" \
                    JOIN "persons" "persons1" ON (("persons1"."id" = "persons2"."childId") AND ("persons1"."id" = 1))
                    """)    // TODO: this request is weird.
            }
        }
    }
    
    func testRightAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_BelongsTo_HasOne_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let book = try Book.fetchOne(db, key: "book1")!
                let request = book.request(Book.libraryAddress.aliased("a"))
                try assertEqualSQL(db, request, """
                    SELECT "a".* \
                    FROM "libraryAddresses" "a" \
                    JOIN "libraries" ON (("libraries"."id" = "a"."libraryId") AND ("libraries"."id" IS NULL))
                    """)    // TODO: this request is weird.
            }
            
            do {
                // alias last
                let book = try Book.fetchOne(db, key: "book1")!
                let request = book.request(Book.libraryAddress).aliased("a")
                try assertEqualSQL(db, request, """
                    SELECT "a".* \
                    FROM "libraryAddresses" "a" \
                    JOIN "libraries" ON (("libraries"."id" = "a"."libraryId") AND ("libraries"."id" IS NULL))
                    """)    // TODO: this request is weird.
            }
        }
    }
}
