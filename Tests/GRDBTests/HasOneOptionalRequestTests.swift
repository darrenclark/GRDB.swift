import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private typealias Country = AssociationFixture.Country
private typealias CountryProfile = AssociationFixture.CountryProfile

class HasOneOptionalRequestTests: GRDBTestCase {
    
    func testRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            
            do {
                let country = try Country.fetchOne(db, key: "FR")!
                let request = country.request(Country.optionalProfile)
                let profile = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"countryProfiles\" WHERE (\"countryCode\" = 'FR')")
                assertMatch(profile, ["countryCode": "FR", "area": 643801, "currency": "EUR"])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "AA")!
                let request = country.request(Country.optionalProfile)
                let profile = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"countryProfiles\" WHERE (\"countryCode\" = 'AA')")
                XCTAssertNil(profile)
            }
        }
    }
    
    func testFetchOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            
            do {
                // TODO: way to make the author non-optional?
                let country = try Country.fetchOne(db, key: "FR")!
                let profile = try country.fetchOne(db, Country.optionalProfile)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"countryProfiles\" WHERE (\"countryCode\" = 'FR')")
                assertMatch(profile, ["countryCode": "FR", "area": 643801, "currency": "EUR"])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "AA")!
                let profile = try country.fetchOne(db, Country.optionalProfile)
                assertEqualSQL(lastSQLQuery, "SELECT * FROM \"countryProfiles\" WHERE (\"countryCode\" = 'AA')")
                XCTAssertNil(profile)
            }
        }
    }
    
    func testRecursion() throws {
        struct Person : TableMapping, MutablePersistable {
            static let databaseTableName = "persons"
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
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
                let association = Person.hasOne(optional: Person.self)
                let request = Person().request(association)
                try assertEqualSQL(db, request, "SELECT * FROM \"persons\" WHERE (\"parentId\" = 1)")
            }
        }
    }
    
    func testRightAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try AssociationFixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let country = try Country.fetchOne(db, key: "FR")!
                let request = country.request(Country.optionalProfile.aliased("a"))
                try assertEqualSQL(db, request, "SELECT \"a\".* FROM \"countryProfiles\" \"a\" WHERE (\"a\".\"countryCode\" = 'FR')")
            }
            
            do {
                // alias last
                let country = try Country.fetchOne(db, key: "FR")!
                let request = country.request(Country.optionalProfile).aliased("a")
                try assertEqualSQL(db, request, "SELECT \"a\".* FROM \"countryProfiles\" \"a\" WHERE (\"a\".\"countryCode\" = 'FR')")
            }
        }
    }
}
