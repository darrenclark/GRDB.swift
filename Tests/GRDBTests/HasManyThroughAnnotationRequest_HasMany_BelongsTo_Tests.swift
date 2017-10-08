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

class HasManyThroughAnnotationRequest_HasMany_BelongsTo_Tests: GRDBTestCase {
    
    // TODO: conditions on middle table
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Country
                .annotated(with: Country.citizens.count)
                .fetchAll(db)
            
            // TODO: check request & results
            assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, COUNT(\"persons\".\"id\") FROM \"countries\" LEFT JOIN \"citizenships\" ON (\"citizenships\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"persons\" ON (\"persons\".\"id\" = \"citizenships\".\"personId\") GROUP BY \"countries\".\"code\"")
            
            assertMatch(graph, [
                (["code": "DE", "name": "Germany"], 0),
                (["code": "FR", "name": "France"], 2),
                (["code": "US", "name": "United States"], 2),
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
                    .annotated(with: Country.citizens.count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, COUNT(\"persons\".\"id\") FROM \"countries\" LEFT JOIN \"citizenships\" ON (\"citizenships\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"persons\" ON (\"persons\".\"id\" = \"citizenships\".\"personId\") WHERE (\"countries\".\"code\" <> \'FR\') GROUP BY \"countries\".\"code\"")
                
                assertMatch(graph, [
                    (["code": "DE", "name": "Germany"], 0),
                    (["code": "US", "name": "United States"], 2),
                    ])
            }
            
            do {
                // filter after
                let graph = try Country
                    .annotated(with: Country.citizens.count)
                    .filter(Column("code") != "FR")
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, COUNT(\"persons\".\"id\") FROM \"countries\" LEFT JOIN \"citizenships\" ON (\"citizenships\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"persons\" ON (\"persons\".\"id\" = \"citizenships\".\"personId\") WHERE (\"countries\".\"code\" <> \'FR\') GROUP BY \"countries\".\"code\"")
                
                assertMatch(graph, [
                    (["code": "DE", "name": "Germany"], 0),
                    (["code": "US", "name": "United States"], 2),
                    ])
            }
            
            do {
                // order before
                let graph = try Country
                    .order(Column("name").desc)
                    .annotated(with: Country.citizens.count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, COUNT(\"persons\".\"id\") FROM \"countries\" LEFT JOIN \"citizenships\" ON (\"citizenships\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"persons\" ON (\"persons\".\"id\" = \"citizenships\".\"personId\") GROUP BY \"countries\".\"code\" ORDER BY \"countries\".\"name\" DESC")
                
                assertMatch(graph, [
                    (["code": "US", "name": "United States"], 2),
                    (["code": "DE", "name": "Germany"], 0),
                    (["code": "FR", "name": "France"], 2),
                    ])
            }
            
            do {
                // order after
                let graph = try Country
                    .annotated(with: Country.citizens.count)
                    .order(Column("name").desc)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, COUNT(\"persons\".\"id\") FROM \"countries\" LEFT JOIN \"citizenships\" ON (\"citizenships\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"persons\" ON (\"persons\".\"id\" = \"citizenships\".\"personId\") GROUP BY \"countries\".\"code\" ORDER BY \"countries\".\"name\" DESC")
                
                assertMatch(graph, [
                    (["code": "US", "name": "United States"], 2),
                    (["code": "DE", "name": "Germany"], 0),
                    (["code": "FR", "name": "France"], 2),
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
                    .annotated(with: Country.citizens.filter(Column("name") != "Craig").count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, COUNT(\"persons\".\"id\") FROM \"countries\" LEFT JOIN \"citizenships\" ON (\"citizenships\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"persons\" ON ((\"persons\".\"id\" = \"citizenships\".\"personId\") AND (\"persons\".\"name\" <> \'Craig\')) GROUP BY \"countries\".\"code\"")
                
                assertMatch(graph, [
                    (["code": "DE", "name": "Germany"], 0),
                    (["code": "FR", "name": "France"], 2),
                    (["code": "US", "name": "United States"], 1),
                    ])
            }
            
            do {
                // ordered citizens
                let graph = try Country
                    .annotated(with: Country.citizens.order(Column("title")).count)
                    .fetchAll(db)
                
                assertEqualSQL(lastSQLQuery, "SELECT \"countries\".*, COUNT(\"persons\".\"id\") FROM \"countries\" LEFT JOIN \"citizenships\" ON (\"citizenships\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"persons\" ON (\"persons\".\"id\" = \"citizenships\".\"personId\") GROUP BY \"countries\".\"code\"")
                
                assertMatch(graph, [
                    (["code": "DE", "name": "Germany"], 0),
                    (["code": "FR", "name": "France"], 2),
                    (["code": "US", "name": "United States"], 2),
                    ])
            }
        }
    }
}
