import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private typealias Country = HasOneThrough_HasOne_BelongsTo_Fixture.Country
private typealias CountryProfile = HasOneThrough_HasOne_BelongsTo_Fixture.CountryProfile
private typealias Continent = HasOneThrough_HasOne_BelongsTo_Fixture.Continent

class HasOneThroughJoinedRequest_HasOne_BelongsTo_Tests: GRDBTestCase {
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Country
                .joined(with: Country.continent)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
            
            assertMatch(graph, [
                ["code": "DE", "name": "Germany"],
                ["code": "FR", "name": "France"],
                ["code": "US", "name": "United States"],
                ["code": "MX", "name": "Mexico"],
                ["code": "AA", "name": "Atlantis"],
                ])
        }
    }
    
    func testLeftRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filter before
                let graph = try Country
                    .filter(Column("code") != "DE")
                    .joined(with: Country.continent)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"countries\".\"code\" <> \'DE\')")
                
                assertMatch(graph, [
                    ["code": "FR", "name": "France"],
                    ["code": "US", "name": "United States"],
                    ["code": "MX", "name": "Mexico"],
                    ["code": "AA", "name": "Atlantis"],
                    ])
            }
            
            do {
                // filter after
                let graph = try Country
                    .joined(with: Country.continent)
                    .filter(Column("code") != "DE")
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"countries\".\"code\" <> \'DE\')")
                
                assertMatch(graph, [
                    ["code": "FR", "name": "France"],
                    ["code": "US", "name": "United States"],
                    ["code": "MX", "name": "Mexico"],
                    ["code": "AA", "name": "Atlantis"],
                    ])
            }
            
            do {
                // order before
                let graph = try Country
                    .order(Column("name").desc)
                    .joined(with: Country.continent)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") ORDER BY \"countries\".\"name\" DESC")
                
                assertMatch(graph, [
                    ["code": "US", "name": "United States"],
                    ["code": "MX", "name": "Mexico"],
                    ["code": "DE", "name": "Germany"],
                    ["code": "FR", "name": "France"],
                    ["code": "AA", "name": "Atlantis"],
                    ])
            }
            
            do {
                // order after
                let graph = try Country
                    .joined(with: Country.continent)
                    .order(Column("name").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") ORDER BY \"countries\".\"name\" DESC")
                
                assertMatch(graph, [
                    ["code": "US", "name": "United States"],
                    ["code": "MX", "name": "Mexico"],
                    ["code": "DE", "name": "Germany"],
                    ["code": "FR", "name": "France"],
                    ["code": "AA", "name": "Atlantis"],
                    ])
            }
        }
    }
    
    func testMiddleRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let middleAssociation = Country.profile.filter(Column("currency") != "EUR")
                let association = Country.hasOne(CountryProfile.continent, through: middleAssociation)
                let graph = try Country
                    .joined(with: association)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON ((\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") AND (\"countryProfiles\".\"currency\" <> \'EUR\')) LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
                
                // TODO: is it expected to have countries whose currency is Euro here?
                // TODO: how to get countries whose currency is not Euro?
                assertMatch(graph, [
                    ["code": "DE", "name": "Germany"],
                    ["code": "FR", "name": "France"],
                    ["code": "US", "name": "United States"],
                    ["code": "MX", "name": "Mexico"],
                    ["code": "AA", "name": "Atlantis"],
                    ])
            }
            
            do {
                let middleAssociation = Country.profile.order(Column("currency").desc)
                let association = Country.hasOne(CountryProfile.continent, through: middleAssociation)
                let graph = try Country
                    .joined(with: association)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
                
                assertMatch(graph, [
                    ["code": "DE", "name": "Germany"],
                    ["code": "FR", "name": "France"],
                    ["code": "US", "name": "United States"],
                    ["code": "MX", "name": "Mexico"],
                    ["code": "AA", "name": "Atlantis"],
                    ])
            }
        }
    }
    
    func testRightRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let graph = try Country
                    .joined(with: Country.continent.filter(Column("name") != "America"))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON ((\"continents\".\"id\" = \"countryProfiles\".\"continentId\") AND (\"continents\".\"name\" <> \'America\'))")
                
                // TODO: is it expected to have countries whose continent is America here?
                // TODO: how to get countries whose continent is not America?
                assertMatch(graph, [
                    ["code": "DE", "name": "Germany"],
                    ["code": "FR", "name": "France"],
                    ["code": "US", "name": "United States"],
                    ["code": "MX", "name": "Mexico"],
                    ["code": "AA", "name": "Atlantis"],
                    ])
            }
            
            do {
                let graph = try Country
                    .joined(with: Country.continent.order(Column("name")))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
                
                assertMatch(graph, [
                    ["code": "DE", "name": "Germany"],
                    ["code": "FR", "name": "France"],
                    ["code": "US", "name": "United States"],
                    ["code": "MX", "name": "Mexico"],
                    ["code": "AA", "name": "Atlantis"],
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
                let middleAssociation = Person.hasOne(Person.self, from: "childId")
                let rightAssociation = Person.belongsTo(Person.self, from: "parentId")
                let association = Person.hasOne(rightAssociation, through: middleAssociation)
                let request = Person.joined(with: association)
                try assertEqualSQL(db, request, "SELECT \"persons1\".* FROM \"persons\" \"persons1\" LEFT JOIN \"persons\" \"persons2\" ON (\"persons2\".\"childId\" = \"persons1\".\"id\") LEFT JOIN \"persons\" \"persons3\" ON (\"persons3\".\"id\" = \"persons2\".\"parentId\")")
            }
        }
    }
    
    func testLeftAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let request = Country.all()
                    .aliased("c")
                    .filter(Column("code") != "DE")
                    .joined(with: Country.continent)
                try assertEqualSQL(db, request, "SELECT \"c\".* FROM \"countries\" \"c\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"c\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"c\".\"code\" <> 'DE')")
            }
            
            do {
                // alias last
                let request = Country
                    .filter(Column("code") != "DE")
                    .joined(with: Country.continent)
                    .aliased("c")
                try assertEqualSQL(db, request, "SELECT \"c\".* FROM \"countries\" \"c\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"c\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"c\".\"code\" <> 'DE')")
            }
            
            do {
                // alias with table name (TODO: port this test to all testLeftAlias() tests)
                let request = Country.all()
                    .aliased("countries")
                    .joined(with: Country.continent)
                try assertEqualSQL(db, request, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
        }
    }
    
    func testMiddleAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let association = Country.hasOne(CountryProfile.continent, through: Country.profile.aliased("a"))
                let request = Country.joined(with: association)
                try assertEqualSQL(db, request, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" \"a\" ON (\"a\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"a\".\"continentId\")")
            }
            do {
                // alias with table name
                let association = Country.hasOne(CountryProfile.continent, through: Country.profile.aliased("countryProfiles"))
                let request = Country.joined(with: association)
                try assertEqualSQL(db, request, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
        }
    }
    
    func testRightAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let request = Country.joined(with:
                    Country.continent
                        .aliased("a")
                        .filter(Column("name") != "America"))
                    .order(Column("name").from("a"))
                try assertEqualSQL(db, request, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" \"a\" ON ((\"a\".\"id\" = \"countryProfiles\".\"continentId\") AND (\"a\".\"name\" <> \'America\')) ORDER BY \"a\".\"name\"")
            }
            
            do {
                // alias last
                let request = Country.joined(with:
                    Country.continent
                        .order(Column("name"))
                        .aliased("a"))
                    .filter(Column("name").from("a") != "America")
                try assertEqualSQL(db, request, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" \"a\" ON (\"a\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"a\".\"name\" <> \'America\')")
            }
            
            do {
                // alias with table name (TODO: port this test to all testRightAlias() tests)
                let request = Country.joined(with: Country.continent.aliased("continents"))
                try assertEqualSQL(db, request, "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
            
        }
    }
    
    func testLockedAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias left
                let request = Country.joined(with: Country.continent).aliased("CONTINENTS")
                try assertEqualSQL(db, request, "SELECT \"CONTINENTS\".* FROM \"countries\" \"CONTINENTS\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"CONTINENTS\".\"code\") LEFT JOIN \"continents\" \"continents1\" ON (\"continents1\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
            
            do {
                // alias right
                let request = Country.joined(with: Country.continent.aliased("COUNTRIES"))
                try assertEqualSQL(db, request, "SELECT \"countries1\".* FROM \"countries\" \"countries1\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries1\".\"code\") LEFT JOIN \"continents\" \"COUNTRIES\" ON (\"COUNTRIES\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
        }
    }
    
    func testConflictingAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let request = Country.joined(with: Country.continent.aliased("a")).aliased("A")
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
