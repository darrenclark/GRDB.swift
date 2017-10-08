import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

struct AssociationFixture {
    
    struct Book : Codable, TableMapping, RowConvertible, MutablePersistable {
        static let databaseTableName = "books"
        static let author = belongsTo(Author.self)
        static let optionalAuthor = belongsTo(optional: Author.self)
        let id: Int64?
        let authorId: Int64?
        let title: String
        let year: Int
    }
    
    struct Author : Codable, TableMapping, RowConvertible, MutablePersistable {
        static let databaseTableName = "authors"
        static let books = hasMany(Book.self)
        let id: Int64?
        let name: String
        let birthYear: Int
    }
    
    struct Country : Codable, TableMapping, RowConvertible, MutablePersistable {
        static let databaseTableName = "countries"
        static let profile = hasOne(CountryProfile.self)
        static let optionalProfile = hasOne(optional: CountryProfile.self)
        let code: String
        let name: String
    }
    
    struct CountryProfile : Codable, TableMapping, RowConvertible, MutablePersistable {
        static let databaseTableName = "countryProfiles"
        let countryCode: String
        let area: Double
        let currency: String
    }
    
    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("fixtures") { db in
            try db.create(table: "authors") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text).notNull()
                t.column("birthYear", .integer).notNull()
            }
            try db.execute("INSERT INTO authors (name, birthYear) VALUES (?, ?)", arguments: ["Gwendal Roué", 1973])
            try db.execute("INSERT INTO authors (name, birthYear) VALUES (?, ?)", arguments: ["J. M. Coetzee", 1940])
            let coetzeeId = db.lastInsertedRowID
            try db.execute("INSERT INTO authors (name, birthYear) VALUES (?, ?)", arguments: ["Herman Melville", 1819])
            let melvilleId = db.lastInsertedRowID
            try db.execute("INSERT INTO authors (name, birthYear) VALUES (?, ?)", arguments: ["Kim Stanley Robinson", 1952])
            let robinsonId = db.lastInsertedRowID
            
            try db.create(table: "books") { t in
                t.column("id", .integer).primaryKey()
                t.column("authorId", .integer).references("authors")
                t.column("title", .text).notNull()
                t.column("year", .integer).notNull()
            }
            
            try db.execute("INSERT INTO books (authorId, title, year) VALUES (?, ?, ?)", arguments: [coetzeeId, "Foe", 1986])
            try db.execute("INSERT INTO books (authorId, title, year) VALUES (?, ?, ?)", arguments: [coetzeeId, "Three Stories", 2014])
            try db.execute("INSERT INTO books (authorId, title, year) VALUES (?, ?, ?)", arguments: [melvilleId, "Moby-Dick", 1851])
            try db.execute("INSERT INTO books (authorId, title, year) VALUES (?, ?, ?)", arguments: [robinsonId, "New York 2140", 2017])
            try db.execute("INSERT INTO books (authorId, title, year) VALUES (?, ?, ?)", arguments: [robinsonId, "2312", 2012])
            try db.execute("INSERT INTO books (authorId, title, year) VALUES (?, ?, ?)", arguments: [robinsonId, "Blue Mars", 1996])
            try db.execute("INSERT INTO books (authorId, title, year) VALUES (?, ?, ?)", arguments: [robinsonId, "Green Mars", 1994])
            try db.execute("INSERT INTO books (authorId, title, year) VALUES (?, ?, ?)", arguments: [robinsonId, "Red Mars", 1993])
            try db.execute("INSERT INTO books (authorId, title, year) VALUES (?, ?, ?)", arguments: [nil, "Unattributed", 2017])
            
            try db.create(table: "countries") { t in
                t.column("code", .text).primaryKey()
                t.column("name", .text)
            }
            try db.execute("INSERT INTO countries (code, name) VALUES (?, ?)", arguments: ["FR", "France"])
            try db.execute("INSERT INTO countries (code, name) VALUES (?, ?)", arguments: ["US", "United States"])
            try db.execute("INSERT INTO countries (code, name) VALUES (?, ?)", arguments: ["DE", "Germany"])
            try db.execute("INSERT INTO countries (code, name) VALUES (?, ?)", arguments: ["AA", "Atlantis"])
            
            try db.create(table: "countryProfiles") { t in
                t.column("countryCode", .text).primaryKey().references("countries")
                t.column("area", .double)
                t.column("currency", .text)
            }
            try db.execute("INSERT INTO countryProfiles (countryCode, area, currency) VALUES (?, ?, ?)", arguments: ["FR", 643801, "EUR"])
            try db.execute("INSERT INTO countryProfiles (countryCode, area, currency) VALUES (?, ?, ?)", arguments: ["US", 9833520, "USD"])
            try db.execute("INSERT INTO countryProfiles (countryCode, area, currency) VALUES (?, ?, ?)", arguments: ["DE", 357168, "EUR"])
        }
        
        return migrator
    }
}

// TODO: move into general GRDBTestCase
extension GRDBTestCase {
    func assertMatch<Left, Annotation>(_ pair: (Left, Annotation), _ expectedPair: (Row, DatabaseValueConvertible), file: StaticString = #file, line: UInt = #line) where Left: MutablePersistable, Annotation: DatabaseValueConvertible {
        assertMatch(pair.0, expectedPair.0, file: file, line: line)
        XCTAssertEqual(pair.1.databaseValue, expectedPair.1.databaseValue, file: file, line: line)
    }
    
    func assertMatch<Left, Annotation>(_ graph: [(Left, Annotation)], _ expectedGraph: [(Row, DatabaseValueConvertible)], file: StaticString = #file, line: UInt = #line) where Left: MutablePersistable, Annotation: DatabaseValueConvertible {
        XCTAssertEqual(graph.count, expectedGraph.count, "count mismatch for \(expectedGraph)", file: file, line: line)
        for (pair, expectedPair) in zip(graph, expectedGraph) {
            assertMatch(pair, expectedPair, file: file, line: line)
        }
    }
    
    func assertMatch<Left, Right>(_ pair: (Left, Right), _ expectedPair: (Row, Row), file: StaticString = #file, line: UInt = #line) where Left: MutablePersistable, Right: MutablePersistable {
        assertMatch(pair.0, expectedPair.0, file: file, line: line)
        assertMatch(pair.1, expectedPair.1, file: file, line: line)
    }
    
    func assertMatch<Left, Right>(_ graph: [(Left, Right)], _ expectedGraph: [(Row, Row)], file: StaticString = #file, line: UInt = #line) where Left: MutablePersistable, Right: MutablePersistable {
        XCTAssertEqual(graph.count, expectedGraph.count, "count mismatch for \(expectedGraph)", file: file, line: line)
        for (pair, expectedPair) in zip(graph, expectedGraph) {
            assertMatch(pair, expectedPair, file: file, line: line)
        }
    }
    
    func assertMatch<Left, Right>(_ pair: (Left, Right?), _ expectedPair: (Row, Row?), file: StaticString = #file, line: UInt = #line) where Left: MutablePersistable, Right: MutablePersistable {
        assertMatch(pair.0, expectedPair.0, file: file, line: line)
        assertMatch(pair.1, expectedPair.1, file: file, line: line)
    }
    
    func assertMatch<Left, Right>(_ graph: [(Left, Right?)], _ expectedGraph: [(Row, Row?)], file: StaticString = #file, line: UInt = #line) where Left: MutablePersistable, Right: MutablePersistable {
        XCTAssertEqual(graph.count, expectedGraph.count, "count mismatch for \(expectedGraph)", file: file, line: line)
        for (pair, expectedPair) in zip(graph, expectedGraph) {
            assertMatch(pair, expectedPair, file: file, line: line)
        }
    }
    
    func assertMatch<Left, Right>(_ pair: (Left, [Right]), _ expectedPair: (Row, [Row]), file: StaticString = #file, line: UInt = #line) where Left: MutablePersistable, Right: MutablePersistable {
        assertMatch(pair.0, expectedPair.0, file: file, line: line)
        assertMatch(pair.1, expectedPair.1, file: file, line: line)
    }
    
    func assertMatch<Left, Right>(_ graph: [(Left, [Right])], _ expectedGraph: [(Row, [Row])], file: StaticString = #file, line: UInt = #line) where Left: MutablePersistable, Right: MutablePersistable {
        XCTAssertEqual(graph.count, expectedGraph.count, "count mismatch for \(expectedGraph)", file: file, line: line)
        for (pair, expectedPair) in zip(graph, expectedGraph) {
            assertMatch(pair, expectedPair, file: file, line: line)
        }
    }
    
    func assertMatch<T>(_ records: [T], _ expectedRows: [Row], file: StaticString = #file, line: UInt = #line) where T: MutablePersistable {
        XCTAssertEqual(records.count, expectedRows.count, "count mismatch for \(expectedRows)", file: file, line: line)
        for (record, expectedRow) in zip(records, expectedRows) {
            assertMatch(record, expectedRow, file: file, line: line)
        }
    }
}
