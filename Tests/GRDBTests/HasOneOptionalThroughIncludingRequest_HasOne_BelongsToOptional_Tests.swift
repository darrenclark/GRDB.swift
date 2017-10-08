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

class HasOneOptionalThroughIncludingRequest_HasOne_BelongsToOptional_Tests: GRDBTestCase {
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Country
                .including(Country.optionalContinent)
                .fetchAll(db)
            
            assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
            
            assertMatch(graph, [
                (["code": "DE", "name": "Germany"], ["id": 1, "name": "Europe"]),
                (["code": "FR", "name": "France"], ["id": 1, "name": "Europe"]),
                (["code": "US", "name": "United States"], ["id": 2, "name": "America"]),
                (["code": "MX", "name": "Mexico"], nil),
                (["code": "AA", "name": "Atlantis"], nil),
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
                    .including(Country.optionalContinent)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"countries\".\"code\" <> \'DE\')")
                
                assertMatch(graph, [
                    (["code": "FR", "name": "France"], ["id": 1, "name": "Europe"]),
                    (["code": "US", "name": "United States"], ["id": 2, "name": "America"]),
                    (["code": "MX", "name": "Mexico"], nil),
                    (["code": "AA", "name": "Atlantis"], nil),
                    ])
            }
            
            do {
                // filter after
                let graph = try Country
                    .including(Country.optionalContinent)
                    .filter(Column("code") != "DE")
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"countries\".\"code\" <> \'DE\')")
                
                assertMatch(graph, [
                    (["code": "FR", "name": "France"], ["id": 1, "name": "Europe"]),
                    (["code": "US", "name": "United States"], ["id": 2, "name": "America"]),
                    (["code": "MX", "name": "Mexico"], nil),
                    (["code": "AA", "name": "Atlantis"], nil),
                    ])
            }
            
            do {
                // order before
                let graph = try Country
                    .order(Column("name").desc)
                    .including(Country.optionalContinent)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") ORDER BY \"countries\".\"name\" DESC")
                
                assertMatch(graph, [
                    (["code": "US", "name": "United States"], ["id": 2, "name": "America"]),
                    (["code": "MX", "name": "Mexico"], nil),
                    (["code": "DE", "name": "Germany"], ["id": 1, "name": "Europe"]),
                    (["code": "FR", "name": "France"], ["id": 1, "name": "Europe"]),
                    (["code": "AA", "name": "Atlantis"], nil),
                    ])
            }
            
            do {
                // order after
                let graph = try Country
                    .including(Country.optionalContinent)
                    .order(Column("name").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") ORDER BY \"countries\".\"name\" DESC")
                
                assertMatch(graph, [
                    (["code": "US", "name": "United States"], ["id": 2, "name": "America"]),
                    (["code": "MX", "name": "Mexico"], nil),
                    (["code": "DE", "name": "Germany"], ["id": 1, "name": "Europe"]),
                    (["code": "FR", "name": "France"], ["id": 1, "name": "Europe"]),
                    (["code": "AA", "name": "Atlantis"], nil),
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
                let association = Country.hasOne(optional: CountryProfile.optionalContinent, through: middleAssociation)
                let graph = try Country
                    .including(association)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON ((\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") AND (\"countryProfiles\".\"currency\" <> \'EUR\')) LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
                
                assertMatch(graph, [
                    (["code": "DE", "name": "Germany"], nil),
                    (["code": "FR", "name": "France"], nil),
                    (["code": "US", "name": "United States"], ["id": 2, "name": "America"]),
                    (["code": "MX", "name": "Mexico"], nil),
                    (["code": "AA", "name": "Atlantis"], nil),
                    ])
            }
            
            do {
                let middleAssociation = Country.profile.order(Column("currency").desc)
                let association = Country.hasOne(optional: CountryProfile.optionalContinent, through: middleAssociation)
                let graph = try Country
                    .including(association)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
                
                assertMatch(graph, [
                    (["code": "DE", "name": "Germany"], ["id": 1, "name": "Europe"]),
                    (["code": "FR", "name": "France"], ["id": 1, "name": "Europe"]),
                    (["code": "US", "name": "United States"], ["id": 2, "name": "America"]),
                    (["code": "MX", "name": "Mexico"], nil),
                    (["code": "AA", "name": "Atlantis"], nil),
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
                    .including(Country.optionalContinent.filter(Column("name") != "America"))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON ((\"continents\".\"id\" = \"countryProfiles\".\"continentId\") AND (\"continents\".\"name\" <> \'America\'))")
                
                assertMatch(graph, [
                    (["code": "DE", "name": "Germany"], ["id": 1, "name": "Europe"]),
                    (["code": "FR", "name": "France"], ["id": 1, "name": "Europe"]),
                    (["code": "US", "name": "United States"], nil),
                    (["code": "MX", "name": "Mexico"], nil),
                    (["code": "AA", "name": "Atlantis"], nil),
                    ])
            }
            
            do {
                let graph = try Country
                    .including(Country.optionalContinent.order(Column("name")))
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") ORDER BY \"continents\".\"name\"")
                
                assertMatch(graph, [
                    (["code": "MX", "name": "Mexico"], nil),
                    (["code": "AA", "name": "Atlantis"], nil),
                    (["code": "US", "name": "United States"], ["id": 2, "name": "America"]),
                    (["code": "DE", "name": "Germany"], ["id": 1, "name": "Europe"]),
                    (["code": "FR", "name": "France"], ["id": 1, "name": "Europe"]),
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
                let rightAssociation = Person.belongsTo(optional: Person.self, from: "parentId")
                let association = Person.hasOne(optional: rightAssociation, through: middleAssociation)
                let request = Person.including(association)
                try assertEqualSQL(db, request, "SELECT \"persons1\".*, \"persons3\".* FROM \"persons\" \"persons1\" LEFT JOIN \"persons\" \"persons2\" ON (\"persons2\".\"childId\" = \"persons1\".\"id\") LEFT JOIN \"persons\" \"persons3\" ON (\"persons3\".\"id\" = \"persons2\".\"parentId\")")
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
                    .including(Country.optionalContinent)
                try assertEqualSQL(db, request, "SELECT \"c\".*, \"continents\".* FROM \"countries\" \"c\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"c\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"c\".\"code\" <> 'DE')")
            }
            
            do {
                // alias last
                let request = Country
                    .filter(Column("code") != "DE")
                    .including(Country.optionalContinent)
                    .aliased("c")
                try assertEqualSQL(db, request, "SELECT \"c\".*, \"continents\".* FROM \"countries\" \"c\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"c\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"c\".\"code\" <> 'DE')")
            }
            
            do {
                // alias with table name (TODO: port this test to all testLeftAlias() tests)
                let request = Country.all()
                    .aliased("countries")
                    .including(Country.optionalContinent)
                try assertEqualSQL(db, request, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
        }
    }
    
    func testMiddleAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let association = Country.hasOne(optional: CountryProfile.optionalContinent, through: Country.profile.aliased("a"))
                let request = Country.including(association)
                try assertEqualSQL(db, request, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" \"a\" ON (\"a\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"a\".\"continentId\")")
            }
            do {
                // alias with table name
                let association = Country.hasOne(optional: CountryProfile.optionalContinent, through: Country.profile.aliased("countryProfiles"))
                let request = Country.including(association)
                try assertEqualSQL(db, request, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
        }
    }
    
    func testRightAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias first
                let request = Country.including(
                    Country.optionalContinent
                        .aliased("a")
                        .filter(Column("name") != "America"))
                    .order(Column("name").from("a"))
                try assertEqualSQL(db, request, "SELECT \"countries\".*, \"a\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" \"a\" ON ((\"a\".\"id\" = \"countryProfiles\".\"continentId\") AND (\"a\".\"name\" <> \'America\')) ORDER BY \"a\".\"name\"")
            }
            
            do {
                // alias last
                let request = Country.including(
                    Country.optionalContinent
                        .order(Column("name"))
                        .aliased("a"))
                    .filter(Column("name").from("a") != "America")
                try assertEqualSQL(db, request, "SELECT \"countries\".*, \"a\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" \"a\" ON (\"a\".\"id\" = \"countryProfiles\".\"continentId\") WHERE (\"a\".\"name\" <> \'America\') ORDER BY \"a\".\"name\"")
            }
            
            do {
                // alias with table name (TODO: port this test to all testRightAlias() tests)
                let request = Country.including(Country.optionalContinent.aliased("continents"))
                try assertEqualSQL(db, request, "SELECT \"countries\".*, \"continents\".* FROM \"countries\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"continents\" ON (\"continents\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
            
        }
    }
    
    func testLockedAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // alias left
                let request = Country.including(Country.optionalContinent).aliased("CONTINENTS")
                try assertEqualSQL(db, request, "SELECT \"CONTINENTS\".*, \"continents1\".* FROM \"countries\" \"CONTINENTS\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"CONTINENTS\".\"code\") LEFT JOIN \"continents\" \"continents1\" ON (\"continents1\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
            
            do {
                // alias right
                let request = Country.including(Country.optionalContinent.aliased("COUNTRIES"))
                try assertEqualSQL(db, request, "SELECT \"countries1\".*, \"COUNTRIES\".* FROM \"countries\" \"countries1\" LEFT JOIN \"countryProfiles\" ON (\"countryProfiles\".\"countryCode\" = \"countries1\".\"code\") LEFT JOIN \"continents\" \"COUNTRIES\" ON (\"COUNTRIES\".\"id\" = \"countryProfiles\".\"continentId\")")
            }
        }
    }
    
    func testConflictingAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasOneThrough_HasOne_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                let request = Country.including(Country.optionalContinent.aliased("a")).aliased("A")
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
