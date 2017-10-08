import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private typealias Country = HasManyThrough_HasMany_BelongsTo_Fixture.Country
private typealias Person = HasManyThrough_HasMany_BelongsTo_Fixture.Person

class HasManyThroughRequest_HasMany_BelongsTo_Tests: GRDBTestCase {
    
    // TODO: conditions on middle table
    
    func testRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in

            do {
                let country = try Country.fetchOne(db, key: "FR")!
                let request = country.all(Country.citizens)
                let persons = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'FR'))
                    """)
                assertMatch(persons, [
                    ["id": 1, "name": "Arthur"],
                    ["id": 2, "name": "Barbara"],
                    ])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "US")!
                let request = country.all(Country.citizens)
                let persons = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'US'))
                    """)
                assertMatch(persons, [
                    ["id": 2, "name": "Barbara"],
                    ["id": 3, "name": "Craig"],
                    ])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "DE")!
                let request = country.all(Country.citizens)
                let persons = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'DE'))
                    """)
                XCTAssertTrue(persons.isEmpty)
            }
            
            do {
                let country = try Country.fetchOne(db, key: "US")!
                let request = country.all(Country.citizens).filter(Column("name") != "Craig")
                let persons = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'US')) \
                    WHERE ("persons"."name" <> 'Craig')
                    """)
                assertMatch(persons, [
                    ["id": 2, "name": "Barbara"],
                    ])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "US")!
                let request = country.all(Country.citizens).order(Column("name").desc)
                let persons = try request.fetchAll(db)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'US')) \
                    ORDER BY "persons"."name" DESC
                    """)
                assertMatch(persons, [
                    ["id": 3, "name": "Craig"],
                    ["id": 2, "name": "Barbara"],
                    ])
            }
        }
    }
    
    func testFetchAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            
            do {
                let country = try Country.fetchOne(db, key: "FR")!
                let persons = try country.fetchAll(db, Country.citizens)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'FR'))
                    """)
                assertMatch(persons, [
                    ["id": 1, "name": "Arthur"],
                    ["id": 2, "name": "Barbara"],
                    ])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "US")!
                let persons = try country.fetchAll(db, Country.citizens)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'US'))
                    """)
                assertMatch(persons, [
                    ["id": 2, "name": "Barbara"],
                    ["id": 3, "name": "Craig"],
                    ])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "DE")!
                let persons = try country.fetchAll(db, Country.citizens)
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'DE'))
                    """)
                XCTAssertTrue(persons.isEmpty)
            }
            
            do {
                let country = try Country.fetchOne(db, key: "US")!
                let persons = try country.fetchAll(db, Country.citizens.filter(Column("name") != "Craig"))
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'US')) \
                    WHERE ("persons"."name" <> 'Craig')
                    """)
                assertMatch(persons, [
                    ["id": 2, "name": "Barbara"],
                    ])
            }
            
            do {
                let country = try Country.fetchOne(db, key: "US")!
                let persons = try country.fetchAll(db, Country.citizens.order(Column("name").desc))
                assertEqualSQL(lastSQLQuery, """
                    SELECT "persons".* \
                    FROM "persons" \
                    JOIN "citizenships" ON (("citizenships"."personId" = "persons"."id") AND ("citizenships"."countryCode" = 'US')) \
                    ORDER BY "persons"."name" DESC
                    """)
                assertMatch(persons, [
                    ["id": 3, "name": "Craig"],
                    ["id": 2, "name": "Barbara"],
                    ])
            }
        }
    }
}
