import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private typealias Country = HasOneThrough_HasOne_BelongsTo_Fixture.Country
private typealias Continent = HasOneThrough_HasOne_BelongsTo_Fixture.Continent

class HasOneOptionalThroughRequest_HasOne_BelongsToOptional_Tests: GRDBTestCase {
    
    func testRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let country = try Country.fetchOne(db, key: "FR")!
                let request = country.request(Country.optionalContinent)
                let continent = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "continents".* \
                    FROM "continents" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "continents"."id") AND ("countryProfiles"."countryCode" = 'FR'))
                    """)
                assertMatch(continent, ["id": 1, "name": "Europe"])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "US")!
                let request = country.request(Country.optionalContinent)
                let continent = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "continents".* \
                    FROM "continents" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "continents"."id") AND ("countryProfiles"."countryCode" = 'US'))
                    """)
                assertMatch(continent, ["id": 2, "name": "America"])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "MX")!
                let request = country.request(Country.optionalContinent)
                let continent = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "continents".* \
                    FROM "continents" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "continents"."id") AND ("countryProfiles"."countryCode" = 'MX'))
                    """)
                XCTAssertNil(continent)
            }
            
            do {
                let country = try Country.fetchOne(db, key: "AA")!
                let request = country.request(Country.optionalContinent)
                let continent = try request.fetchOne(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "continents".* \
                    FROM "continents" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "continents"."id") AND ("countryProfiles"."countryCode" = 'AA'))
                    """)
                XCTAssertNil(continent)
            }
        }
    }
    
    func testFetchOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let country = try Country.fetchOne(db, key: "FR")!
                let continent = try country.fetchOne(db, Country.optionalContinent)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "continents".* \
                    FROM "continents" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "continents"."id") AND ("countryProfiles"."countryCode" = 'FR'))
                    """)
                assertMatch(continent, ["id": 1, "name": "Europe"])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "US")!
                let continent = try country.fetchOne(db, Country.optionalContinent)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "continents".* \
                    FROM "continents" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "continents"."id") AND ("countryProfiles"."countryCode" = 'US'))
                    """)
                assertMatch(continent, ["id": 2, "name": "America"])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "MX")!
                let continent = try country.fetchOne(db, Country.optionalContinent)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "continents".* \
                    FROM "continents" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "continents"."id") AND ("countryProfiles"."countryCode" = 'MX'))
                    """)
                XCTAssertNil(continent)
            }
            
            do {
                let country = try Country.fetchOne(db, key: "AA")!
                let continent = try country.fetchOne(db, Country.optionalContinent)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "continents".* \
                    FROM "continents" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "continents"."id") AND ("countryProfiles"."countryCode" = 'AA'))
                    """)
                XCTAssertNil(continent)
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
                t.column("childId", .integer).references("persons")
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let middleAssociation = Person.hasOne(Person.self, foreignKey: ["childId"])
                let rightAssociation = Person.belongsTo(optional: Person.self, foreignKey: ["parentId"])
                let association = Person.hasOne(optional: rightAssociation, through: middleAssociation)
                let request = Person().request(association)
                try assertEqualSQL(db, request, """
                    SELECT "persons2".* \
                    FROM "persons" "persons2" \
                    JOIN "persons" "persons1" ON (("persons1"."parentId" = "persons2"."id") AND ("persons1"."childId" = 1))
                    """)
            }
        }
    }
    
    func testRightAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let country = try Country.fetchOne(db, key: "FR")!
                let request = country.request(Country.optionalContinent.aliased("a"))
                try assertEqualSQL(db, request, """
                    SELECT "a".* \
                    FROM "continents" "a" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "a"."id") AND ("countryProfiles"."countryCode" = 'FR'))
                    """)
            }
            
            do {
                // alias last
                let country = try Country.fetchOne(db, key: "FR")!
                let request = country.request(Country.optionalContinent).aliased("a")
                try assertEqualSQL(db, request, """
                    SELECT "a".* \
                    FROM "continents" "a" \
                    JOIN "countryProfiles" ON (("countryProfiles"."continentId" = "a"."id") AND ("countryProfiles"."countryCode" = 'FR'))
                    """)
            }
        }
    }
}
