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

class HasManyThroughAnnotationPredicateRequest_HasMany_BelongsTo_Tests: GRDBTestCase {
    
    // TODO: conditions on middle table
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Country
                .filter(Country.citizens.count > 0)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, """
                SELECT "countries".* \
                FROM "countries" \
                LEFT JOIN "citizenships" ON ("citizenships"."countryCode" = "countries"."code") \
                LEFT JOIN "persons" ON ("persons"."id" = "citizenships"."personId") \
                GROUP BY "countries"."code" \
                HAVING (COUNT("persons"."id") > 0)
                """)
            
            assertMatch(graph, [
                ["code": "FR", "name": "France"],
                ["code": "US", "name": "United States"],
                ])
        }
    }
    
    func testLeftRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filter before
                let graph = try Country
                    .filter(Column("code") != "FR")
                    .filter(Country.citizens.count > 0)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "countries".* \
                    FROM "countries" \
                    LEFT JOIN "citizenships" ON ("citizenships"."countryCode" = "countries"."code") \
                    LEFT JOIN "persons" ON ("persons"."id" = "citizenships"."personId") \
                    WHERE ("countries"."code" <> 'FR') \
                    GROUP BY "countries"."code" \
                    HAVING (COUNT("persons"."id") > 0)
                    """)
                
                assertMatch(graph, [
                    ["code": "US", "name": "United States"],
                    ])
            }
            
            do {
                // filter after
                let graph = try Country
                    .filter(Country.citizens.count > 0)
                    .filter(Column("code") != "FR")
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "countries".* \
                    FROM "countries" \
                    LEFT JOIN "citizenships" ON ("citizenships"."countryCode" = "countries"."code") \
                    LEFT JOIN "persons" ON ("persons"."id" = "citizenships"."personId") \
                    WHERE ("countries"."code" <> 'FR') \
                    GROUP BY "countries"."code" \
                    HAVING (COUNT("persons"."id") > 0)
                    """)
                
                assertMatch(graph, [
                    ["code": "US", "name": "United States"],
                    ])
            }
            
            do {
                // order before
                let graph = try Country
                    .order(Column("name").desc)
                    .filter(Country.citizens.count > 0)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "countries".* \
                    FROM "countries" \
                    LEFT JOIN "citizenships" ON ("citizenships"."countryCode" = "countries"."code") \
                    LEFT JOIN "persons" ON ("persons"."id" = "citizenships"."personId") \
                    GROUP BY "countries"."code" \
                    HAVING (COUNT("persons"."id") > 0) \
                    ORDER BY "countries"."name" DESC
                    """)
                
                assertMatch(graph, [
                    ["code": "US", "name": "United States"],
                    ["code": "FR", "name": "France"],
                    ])
            }
            
            do {
                // order after
                let graph = try Country
                    .filter(Country.citizens.count > 0)
                    .order(Column("name").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "countries".* \
                    FROM "countries" \
                    LEFT JOIN "citizenships" ON ("citizenships"."countryCode" = "countries"."code") \
                    LEFT JOIN "persons" ON ("persons"."id" = "citizenships"."personId") \
                    GROUP BY "countries"."code" \
                    HAVING (COUNT("persons"."id") > 0) \
                    ORDER BY "countries"."name" DESC
                    """)
                
                assertMatch(graph, [
                    ["code": "US", "name": "United States"],
                    ["code": "FR", "name": "France"],
                    ])
            }
        }
    }
    
    func testRightRequestDerivation() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filtered citizens
                let graph = try Country
                    .filter(Country.citizens.filter(Column("name") != "Craig").count > 0)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, """
                    SELECT "countries".* \
                    FROM "countries" \
                    LEFT JOIN "citizenships" ON ("citizenships"."countryCode" = "countries"."code") \
                    LEFT JOIN "persons" ON (("persons"."id" = "citizenships"."personId") AND ("persons"."name" <> 'Craig')) \
                    GROUP BY "countries"."code" \
                    HAVING (COUNT("persons"."id") > 0)
                    """)
                
                assertMatch(graph, [
                    ["code": "FR", "name": "France"],
                    ["code": "US", "name": "United States"],
                    ])
            }
        }
    }
    
    func testEqual() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Country
                .filter(Country.citizens.count == 2)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, """
                SELECT "countries".* \
                FROM "countries" \
                LEFT JOIN "citizenships" ON ("citizenships"."countryCode" = "countries"."code") \
                LEFT JOIN "persons" ON ("persons"."id" = "citizenships"."personId") \
                GROUP BY "countries"."code" \
                HAVING (COUNT("persons"."id") = 2)
                """)

            assertMatch(graph, [
                ["code": "FR", "name": "France"],
                ["code": "US", "name": "United States"],
                ])
        }
    }
    
    func testIsEmpty() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Country
                .filter(Country.citizens.isEmpty)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, """
                SELECT "countries".* \
                FROM "countries" \
                LEFT JOIN "citizenships" ON ("citizenships"."countryCode" = "countries"."code") \
                LEFT JOIN "persons" ON ("persons"."id" = "citizenships"."personId") \
                GROUP BY "countries"."code" \
                HAVING (COUNT("persons"."id") = 0)
                """)
            
            assertMatch(graph, [
                ["code": "DE", "name": "Germany"],
                ])
        }
    }
    
    func testNotIsEmpty() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Country
                .filter(!Country.citizens.isEmpty)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, """
                SELECT "countries".* \
                FROM "countries" \
                LEFT JOIN "citizenships" ON ("citizenships"."countryCode" = "countries"."code") \
                LEFT JOIN "persons" ON ("persons"."id" = "citizenships"."personId") \
                GROUP BY "countries"."code" \
                HAVING (COUNT("persons"."id") <> 0)
                """)
            
            assertMatch(graph, [
                ["code": "FR", "name": "France"],
                ["code": "US", "name": "United States"],
                ])
        }
    }
}
