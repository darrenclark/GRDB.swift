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

class HasManyThroughIncludingRequest_HasMany_BelongsTo_Tests: GRDBTestCase {
    
    // TODO: conditions on middle table
    
    func testSimplestRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            let graph = try Country
                .including(Country.citizens)
                .fetchAll(db)
            
            XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"countries\"")
            XCTAssertTrue(["DE", "FR", "US"].sqlPermutations.contains {
                sqlQueries[sqlQueries.count - 1] == String(format: "SELECT \"citizenships\".\"countryCode\", \"persons\".* FROM \"persons\" JOIN \"citizenships\" ON ((\"citizenships\".\"personId\" = \"persons\".\"id\") AND (\"citizenships\".\"countryCode\" IN (%@)))", $0)
            })
            
            assertMatch(graph, [
                (["code": "FR", "name": "France"], [
                    ["id": 1, "name": "Arthur"],
                    ["id": 2, "name": "Barbara"],
                    ]),
                (["code": "US", "name": "United States"], [
                    ["id": 2, "name": "Barbara"],
                    ["id": 3, "name": "Craig"],
                    ]),
                (["code": "DE", "name": "Germany"], []),
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
                    .including(Country.citizens)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"countries\" WHERE (\"code\" <> 'FR')")
                XCTAssertTrue(["DE", "US"].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: "SELECT \"citizenships\".\"countryCode\", \"persons\".* FROM \"persons\" JOIN \"citizenships\" ON ((\"citizenships\".\"personId\" = \"persons\".\"id\") AND (\"citizenships\".\"countryCode\" IN (%@)))", $0)
                })
                
                assertMatch(graph, [
                    (["code": "US", "name": "United States"], [
                        ["id": 2, "name": "Barbara"],
                        ["id": 3, "name": "Craig"],
                        ]),
                    (["code": "DE", "name": "Germany"], []),
                    ])
            }
            
            do {
                // filter after
                let graph = try Country
                    .including(Country.citizens)
                    .filter(Column("code") != "FR")
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"countries\" WHERE (\"code\" <> 'FR')")
                XCTAssertTrue(["DE", "US"].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: "SELECT \"citizenships\".\"countryCode\", \"persons\".* FROM \"persons\" JOIN \"citizenships\" ON ((\"citizenships\".\"personId\" = \"persons\".\"id\") AND (\"citizenships\".\"countryCode\" IN (%@)))", $0)
                })
                
                assertMatch(graph, [
                    (["code": "US", "name": "United States"], [
                        ["id": 2, "name": "Barbara"],
                        ["id": 3, "name": "Craig"],
                        ]),
                    (["code": "DE", "name": "Germany"], []),
                    ])
            }
            
            do {
                // order before including
                let graph = try Country
                    .order(Column("name").desc)
                    .including(Country.citizens)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"countries\" ORDER BY \"name\" DESC")
                XCTAssertTrue(["DE", "FR", "US"].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: "SELECT \"citizenships\".\"countryCode\", \"persons\".* FROM \"persons\" JOIN \"citizenships\" ON ((\"citizenships\".\"personId\" = \"persons\".\"id\") AND (\"citizenships\".\"countryCode\" IN (%@)))", $0)
                })
                
                assertMatch(graph, [
                    (["code": "US", "name": "United States"], [
                        ["id": 2, "name": "Barbara"],
                        ["id": 3, "name": "Craig"],
                        ]),
                    (["code": "DE", "name": "Germany"], []),
                    (["code": "FR", "name": "France"], [
                        ["id": 1, "name": "Arthur"],
                        ["id": 2, "name": "Barbara"],
                        ]),
                    ])
            }
            
            do {
                // order after including
                let graph = try Country
                    .including(Country.citizens)
                    .order(Column("name").desc)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"countries\" ORDER BY \"name\" DESC")
                XCTAssertTrue(["DE", "FR", "US"].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: "SELECT \"citizenships\".\"countryCode\", \"persons\".* FROM \"persons\" JOIN \"citizenships\" ON ((\"citizenships\".\"personId\" = \"persons\".\"id\") AND (\"citizenships\".\"countryCode\" IN (%@)))", $0)
                })
                
                assertMatch(graph, [
                    (["code": "US", "name": "United States"], [
                        ["id": 2, "name": "Barbara"],
                        ["id": 3, "name": "Craig"],
                        ]),
                    (["code": "DE", "name": "Germany"], []),
                    (["code": "FR", "name": "France"], [
                        ["id": 1, "name": "Arthur"],
                        ["id": 2, "name": "Barbara"],
                        ]),
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
                    .including(Country.citizens.filter(Column("name") != "Craig"))
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"countries\"")
                XCTAssertTrue(["DE", "FR", "US"].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: "SELECT \"citizenships\".\"countryCode\", \"persons\".* FROM \"persons\" JOIN \"citizenships\" ON ((\"citizenships\".\"personId\" = \"persons\".\"id\") AND (\"citizenships\".\"countryCode\" IN (%@))) WHERE (\"persons\".\"name\" <> 'Craig')", $0)
                })
                
                assertMatch(graph, [
                    (["code": "FR", "name": "France"], [
                        ["id": 1, "name": "Arthur"],
                        ["id": 2, "name": "Barbara"],
                        ]),
                    (["code": "US", "name": "United States"], [
                        ["id": 2, "name": "Barbara"],
                        ]),
                    (["code": "DE", "name": "Germany"], []),
                    ])
            }
            
            do {
                // ordered citizens
                let graph = try Country
                    .including(Country.citizens.order(Column("name").desc))
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT * FROM \"countries\"")
                XCTAssertTrue(["DE", "FR", "US"].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: "SELECT \"citizenships\".\"countryCode\", \"persons\".* FROM \"persons\" JOIN \"citizenships\" ON ((\"citizenships\".\"personId\" = \"persons\".\"id\") AND (\"citizenships\".\"countryCode\" IN (%@))) ORDER BY \"persons\".\"name\" DESC", $0)
                })
                
                assertMatch(graph, [
                    (["code": "FR", "name": "France"], [
                        ["id": 2, "name": "Barbara"],
                        ["id": 1, "name": "Arthur"],
                        ]),
                    (["code": "US", "name": "United States"], [
                        ["id": 3, "name": "Craig"],
                        ["id": 2, "name": "Barbara"],
                        ]),
                    (["code": "DE", "name": "Germany"], []),
                    ])
            }
        }
    }
    
    func testAnnotationPredicate() throws {
        let dbQueue = try makeDatabaseQueue()
        try HasManyThrough_HasMany_BelongsTo_Fixture().migrator.migrate(dbQueue)
        
        try dbQueue.inDatabase { db in
            do {
                // filter before
                let graph = try Country
                    .filter(Country.citizens.count == 2) // TODO: test for another hasManyThrough annotation, and for a hasMany annotation
                    .including(Country.citizens)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"citizenships\" ON (\"citizenships\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"persons\" ON (\"persons\".\"id\" = \"citizenships\".\"personId\") GROUP BY \"countries\".\"code\" HAVING (COUNT(\"persons\".\"id\") = 2)")
                XCTAssertTrue(["FR", "US"].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: "SELECT \"citizenships\".\"countryCode\", \"persons\".* FROM \"persons\" JOIN \"citizenships\" ON ((\"citizenships\".\"personId\" = \"persons\".\"id\") AND (\"citizenships\".\"countryCode\" IN (%@)))", $0)
                })
                
                assertMatch(graph, [
                    (["code": "FR", "name": "France"], [
                        ["id": 1, "name": "Arthur"],
                        ["id": 2, "name": "Barbara"],
                        ]),
                    (["code": "US", "name": "United States"], [
                        ["id": 2, "name": "Barbara"],
                        ["id": 3, "name": "Craig"],
                        ]),
                    ])
            }
            do {
                // filter after
                let graph = try Country
                    .including(Country.citizens)
                    .filter(Country.citizens.count == 2)
                    .fetchAll(db)
                
                XCTAssertEqual(sqlQueries[sqlQueries.count - 2], "SELECT \"countries\".* FROM \"countries\" LEFT JOIN \"citizenships\" ON (\"citizenships\".\"countryCode\" = \"countries\".\"code\") LEFT JOIN \"persons\" ON (\"persons\".\"id\" = \"citizenships\".\"personId\") GROUP BY \"countries\".\"code\" HAVING (COUNT(\"persons\".\"id\") = 2)")
                XCTAssertTrue(["FR", "US"].sqlPermutations.contains {
                    sqlQueries[sqlQueries.count - 1] == String(format: "SELECT \"citizenships\".\"countryCode\", \"persons\".* FROM \"persons\" JOIN \"citizenships\" ON ((\"citizenships\".\"personId\" = \"persons\".\"id\") AND (\"citizenships\".\"countryCode\" IN (%@)))", $0)
                })
                
                assertMatch(graph, [
                    (["code": "FR", "name": "France"], [
                        ["id": 1, "name": "Arthur"],
                        ["id": 2, "name": "Barbara"],
                        ]),
                    (["code": "US", "name": "United States"], [
                        ["id": 2, "name": "Barbara"],
                        ["id": 3, "name": "Craig"],
                        ]),
                    ])
            }
        }
    }
}
