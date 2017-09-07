The Query Interface
===================

**The query interface lets you write pure Swift instead of SQL:**

```swift
try dbQueue.inDatabase { db in
    // Update database schema
    try db.create(table: "wines") { t in ... }
    
    // Fetch records
    let wines = try Wine.filter(origin == "Burgundy").order(price).fetchAll(db)
    
    // Count
    let count = try Wine.filter(color == Color.red).fetchCount(db)
    
    // Delete
    try Wine.filter(corked == true).deleteAll(db)
}
```

You need to open a [database connection](#database-connections) before you can query the database.

Please bear in mind that the query interface can not generate all possible SQL queries. You may also *prefer* writing SQL, and this is just OK. From little snippets to full queries, your SQL skills are welcome:

```swift
try dbQueue.inDatabase { db in
    // Update database schema (with SQL)
    try db.execute("CREATE TABLE wines (...)")
    
    // Fetch records (with SQL)
    let wines = try Wine.fetchAll(db,
        "SELECT * FROM wines WHERE origin = ? ORDER BY price",
        arguments: ["Burgundy"])
    
    // Count (with an SQL snippet)
    let count = try Wine
        .filter(sql: "color = ?", arguments: [Color.red])
        .fetchCount(db)
    
    // Delete (with SQL)
    try db.execute("DELETE FROM wines WHERE corked")
}
```

So don't miss the [SQL API](#sqlite-api).

- [Database Schema](#database-schema)
- [Requests](#requests)
    - [Columns Selected by a Request](#columns-selected-by-a-request)
- [Expressions](#expressions)
    - [SQL Operators](#sql-operators)
    - [SQL Functions](#sql-functions)
- [Fetching from Requests](#fetching-from-requests)
- [Fetching by Key](#fetching-by-key)
- [Fetching Aggregated Values](#fetching-aggregated-values)
- [Delete Requests](#delete-requests)
- [Custom Requests](#custom-requests)
- [GRDB Extension Guide](Documentation/ExtendingGRDB.md)


## Database Schema

Once granted with a [database connection](#database-connections), you can setup your database schema without writing SQL:

- [Create Tables](#create-tables)
- [Modify Tables](#modify-tables)
- [Drop Tables](#drop-tables)
- [Create Indexes](#create-indexes)


### Create Tables

```swift
// CREATE TABLE places (
//   id INTEGER PRIMARY KEY,
//   title TEXT,
//   favorite BOOLEAN NOT NULL DEFAULT 0,
//   latitude DOUBLE NOT NULL,
//   longitude DOUBLE NOT NULL
// )
try db.create(table: "places") { t in
    t.column("id", .integer).primaryKey()
    t.column("title", .text)
    t.column("favorite", .boolean).notNull().defaults(to: false)
    t.column("longitude", .double).notNull()
    t.column("latitude", .double).notNull()
}
```

The `create(table:)` method covers nearly all SQLite table creation features. For virtual tables, see [Full-Text Search](#full-text-search), or use raw SQL.

SQLite has many reference documents about table creation:

- [CREATE TABLE](https://www.sqlite.org/lang_createtable.html)
- [Datatypes In SQLite Version 3](https://www.sqlite.org/datatype3.html)
- [SQLite Foreign Key Support](https://www.sqlite.org/foreignkeys.html)
- [ON CONFLICT](https://www.sqlite.org/lang_conflict.html)
- [The WITHOUT ROWID Optimization](https://www.sqlite.org/withoutrowid.html)

**Configure table creation**:

```swift
// CREATE TABLE example ( ... )
try db.create(table: "example") { t in ... }
    
// CREATE TEMPORARY TABLE example IF NOT EXISTS (
try db.create(table: "example", temporary: true, ifNotExists: true) { t in
```

**Add regular columns** with their name and eventual type (text, integer, double, numeric, boolean, blob, date and datetime) - see [SQLite data types](https://www.sqlite.org/datatype3.html):

```swift
// CREATE TABLE example (
//   a,
//   name TEXT,
//   creationDate DATETIME,
try db.create(table: "example") { t in ... }
    t.column("a")
    t.column("name", .text)
    t.column("creationDate", .datetime)
```

Define **not null** columns, and set **default** values:

```swift
    // email TEXT NOT NULL,
    t.column("email", .text).notNull()
    
    // name TEXT NOT NULL DEFAULT 'Anonymous',
    t.column("name", .text).notNull().defaults(to: "Anonymous")
```
    
Use an individual column as **primary**, **unique**, or **foreign key**. When defining a foreign key, the referenced column is the primary key of the referenced table (unless you specify otherwise):

```swift
    // id INTEGER PRIMARY KEY,
    t.column("id", .integer).primaryKey()
    
    // email TEXT UNIQUE,
    t.column("email", .text).unique()
    
    // countryCode TEXT REFERENCES countries(code) ON DELETE CASCADE,
    t.column("countryCode", .text).references("countries", onDelete: .cascade)
```

**Create an index** on the column:

```swift
    t.column("score", .integer).indexed()
```

For extra index options, see [Create Indexes](#create-indexes) below.

**Perform integrity checks** on individual columns, and SQLite will only let conforming rows in. In the example below, the `$0` closure variable is a column which lets you build any SQL [expression](#expressions).

```swift
    // name TEXT CHECK (LENGTH(name) > 0)
    // score INTEGER CHECK (score > 0)
    t.column("name", .text).check { length($0) > 0 }
    t.column("score", .integer).check(sql: "score > 0")
```

Other **table constraints** can involve several columns:

```swift
    // PRIMARY KEY (a, b),
    t.primaryKey(["a", "b"])
    
    // UNIQUE (a, b) ON CONFLICT REPLACE,
    t.uniqueKey(["a", "b"], onConfict: .replace)
    
    // FOREIGN KEY (a, b) REFERENCES parents(c, d),
    t.foreignKey(["a", "b"], references: "parent")
    
    // CHECK (a + b < 10),
    t.check(Column("a") + Column("b") < 10)
    
    // CHECK (a + b < 10)
    t.check(sql: "a + b < 10")
}
```

### Modify Tables

SQLite lets you rename tables, and add columns to existing tables:

```swift
// ALTER TABLE referers RENAME TO referrers
try db.rename(table: "referers", to: "referrers")

// ALTER TABLE players ADD COLUMN url TEXT
try db.alter(table: "players") { t in
    t.add(column: "url", .text)
}
```

> :point_up: **Note**: SQLite restricts the possible table alterations, and may require you to recreate dependent triggers or views. See the documentation of the [ALTER TABLE](https://www.sqlite.org/lang_altertable.html) for details. See [Advanced Database Schema Changes](#advanced-database-schema-changes) for a way to lift restrictions.


### Drop Tables

Drop tables with the `drop(table:)` method:

```swift
try db.drop(table: "obsolete")
```

### Create Indexes

Create indexes with the `create(index:)` method:

```swift
// CREATE UNIQUE INDEX byEmail ON users(email)
try db.create(index: "byEmail", on: "users", columns: ["email"], unique: true)
```

Relevant SQLite documentation:

- [CREATE INDEX](https://www.sqlite.org/lang_createindex.html)
- [Indexes On Expressions](https://www.sqlite.org/expridx.html)
- [Partial Indexes](https://www.sqlite.org/partialindex.html)


## Requests

**The query interface requests** let you fetch values from the database:

```swift
let request = Player.filter(emailColumn != nil).order(nameColumn)
let players = try request.fetchAll(db)  // [Player]
let count = try request.fetchCount(db)  // Int
```

All requests start from **a type** that adopts the `TableMapping` protocol, such as a `Record` subclass (see [Records](#records)):

```swift
class Player : Record { ... }
```

Declare the table **columns** that you want to use for filtering, or sorting:

```swift
let idColumn = Column("id")
let nameColumn = Column("name")
```

You can now build requests with the following methods: `all`, `none`, `select`, `distinct`, `filter`, `matching`, `group`, `having`, `order`, `reversed`, `limit`. All those methods return another request, which you can further refine by applying another method: `Player.select(...).filter(...).order(...)`.

- `all()`, `none()`: the requests for all rows, or no row.

    ```swift
    // SELECT * FROM players
    Player.all()
    ```
    
    The hidden `rowid` column can be selected as well [when you need it](#the-implicit-rowid-primary-key).

- `select(expression, ...)` defines the selected columns.
    
    ```swift
    // SELECT id, name FROM players
    Player.select(idColumn, nameColumn)
    
    // SELECT MAX(score) AS maxScore FROM players
    Player.select(max(scoreColumn).aliased("maxScore"))
    ```

- `distinct()` performs uniquing.
    
    ```swift
    // SELECT DISTINCT name FROM players
    Player.select(nameColumn).distinct()
    ```

- `filter(expression)` applies conditions.
    
    ```swift
    // SELECT * FROM players WHERE id IN (1, 2, 3)
    Player.filter([1,2,3].contains(idColumn))
    
    // SELECT * FROM players WHERE (name IS NOT NULL) AND (height > 1.75)
    Player.filter(nameColumn != nil && heightColumn > 1.75)
    ```

- `matching(pattern)` performs [full-text search](#full-text-search).
    
    ```swift
    // SELECT * FROM documents WHERE documents MATCH 'sqlite database'
    let pattern = FTS3Pattern(matchingAllTokensIn: "SQLite database")
    Document.matching(pattern)
    ```
    
    When the pattern is nil, no row will match.

- `group(expression, ...)` groups rows.
    
    ```swift
    // SELECT name, MAX(score) FROM players GROUP BY name
    Player
        .select(nameColumn, max(scoreColumn))
        .group(nameColumn)
    ```

- `having(expression)` applies conditions on grouped rows.
    
    ```swift
    // SELECT team, MAX(score) FROM players GROUP BY team HAVING MIN(score) >= 1000
    Player
        .select(teamColumn, max(scoreColumn))
        .group(teamColumn)
        .having(min(scoreColumn) >= 1000)
    ```

- `order(ordering, ...)` sorts.
    
    ```swift
    // SELECT * FROM players ORDER BY name
    Player.order(nameColumn)
    
    // SELECT * FROM players ORDER BY score DESC, name
    Player.order(scoreColumn.desc, nameColumn)
    ```
    
    Each `order` call clears any previous ordering:
    
    ```swift
    // SELECT * FROM players ORDER BY name
    Player.order(scoreColumn).order(nameColumn)
    ```

- `reversed()` reverses the eventual orderings.
    
    ```swift
    // SELECT * FROM players ORDER BY score ASC, name DESC
    Player.order(scoreColumn.desc, nameColumn).reversed()
    ```
    
    If no ordering was specified, the result is ordered by rowID in reverse order.
    
    ```swift
    // SELECT * FROM players ORDER BY _rowid_ DESC
    Player.all().reversed()
    ```

- `limit(limit, offset: offset)` limits and pages results.
    
    ```swift
    // SELECT * FROM players LIMIT 5
    Player.limit(5)
    
    // SELECT * FROM players LIMIT 5 OFFSET 10
    Player.limit(5, offset: 10)
    ```

You can refine requests by chaining those methods:

```swift
// SELECT * FROM players WHERE (email IS NOT NULL) ORDER BY name
Player.order(nameColumn).filter(emailColumn != nil)
```

The `select`, `order`, `group`, and `limit` methods ignore and replace previously applied selection, orderings, grouping, and limits. On the opposite, `filter`, `matching`, and `having` methods extend the query:

```swift
Player                          // SELECT * FROM players
    .filter(nameColumn != nil)  // WHERE (name IS NOT NULL)
    .filter(emailColumn != nil) //        AND (email IS NOT NULL)
    .order(nameColumn)          // - ignored -
    .order(scoreColumn)         // ORDER BY score
    .limit(20, offset: 40)      // - ignored -
    .limit(10)                  // LIMIT 10
```


Raw SQL snippets are also accepted, with eventual [arguments](http://groue.github.io/GRDB.swift/docs/1.3/Structs/StatementArguments.html):

```swift
// SELECT DATE(creationDate), COUNT(*) FROM players WHERE name = 'Arthur' GROUP BY date(creationDate)
Player
    .select(sql: "DATE(creationDate), COUNT(*)")
    .filter(sql: "name = ?", arguments: ["Arthur"])
    .group(sql: "DATE(creationDate)")
```


### Columns Selected by a Request

By default, query interface requests select all columns:

```swift
// SELECT * FROM players
let request = Player.all()
```

**The selection can be changed for each individual requests, or for all requests built from a given type.**

To specify the selection of a specific request, use the `select` method:

```swift
// SELECT id, name FROM players
let request = Player.select(Column("id"), Column("name"))

// SELECT *, rowid FROM players
let request = Player.select(AllColumns(), Column.rowID)
```

To specify the default selection for all requests built from a type, define the `databaseSelection` property:

```swift
struct RestrictedPlayer : TableMapping {
    static let databaseTableName = "players"
    static let databaseSelection: [SQLSelectable] = [Column("id"), Column("name")]
}

struct ExtendedPlayer : TableMapping {
    static let databaseTableName = "players"
    static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
}

// SELECT id, name FROM players
let request = RestrictedPlayer.all()

// SELECT *, rowid FROM players
let request = ExtendedPlayer.all()
```

> :point_up: **Note**: make sure the `databaseSelection` property is explicitely declared as `[SQLSelectable]`. If it is not, the Swift compiler may infer a type which may silently miss the protocol requirement, resulting in sticky `SELECT *` requests.


## Expressions

Feed [requests](#requests) with SQL expressions built from your Swift code:


### SQL Operators

- `=`, `<>`, `<`, `<=`, `>`, `>=`, `IS`, `IS NOT`
    
    Comparison operators are based on the Swift operators `==`, `!=`, `===`, `!==`, `<`, `<=`, `>`, `>=`:
    
    ```swift
    // SELECT * FROM players WHERE (name = 'Arthur')
    Player.filter(nameColumn == "Arthur")
    
    // SELECT * FROM players WHERE (name IS NULL)
    Player.filter(nameColumn == nil)
    
    // SELECT * FROM players WHERE (score IS 1000)
    Player.filter(scoreColumn === 1000)
    
    // SELECT * FROM rectangles WHERE width < height
    Rectangle.filter(widthColumn < heightColumn)
    ```
    
    > :point_up: **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.

- `*`, `/`, `+`, `-`
    
    SQLite arithmetic operators are derived from their Swift equivalent:
    
    ```swift
    // SELECT ((temperature * 1.8) + 32) AS farenheit FROM players
    Planet.select((temperatureColumn * 1.8 + 32).aliased("farenheit"))
    ```
    
    > :point_up: **Note**: an expression like `nameColumn + "rrr"` will be interpreted by SQLite as a numerical addition (with funny results), not as a string concatenation.

- `AND`, `OR`, `NOT`
    
    The SQL logical operators are derived from the Swift `&&`, `||` and `!`:
    
    ```swift
    // SELECT * FROM players WHERE ((NOT verified) OR (score < 1000))
    Player.filter(!verifiedColumn || scoreColumn < 1000)
    ```

- `BETWEEN`, `IN`, `NOT IN`
    
    To check inclusion in a Swift sequence (array, set, range…), call the `contains` method:
    
    ```swift
    // SELECT * FROM players WHERE id IN (1, 2, 3)
    Player.filter([1, 2, 3].contains(idColumn))
    
    // SELECT * FROM players WHERE id NOT IN (1, 2, 3)
    Player.filter(![1, 2, 3].contains(idColumn))
    
    // SELECT * FROM players WHERE score BETWEEN 0 AND 1000
    Player.filter((0...1000).contains(scoreColumn))
    
    // SELECT * FROM players WHERE (score >= 0) AND (score < 1000)
    Player.filter((0..<1000).contains(scoreColumn))
    
    // SELECT * FROM players WHERE initial BETWEEN 'A' AND 'N'
    Player.filter(("A"..."N").contains(initialColumn))
    
    // SELECT * FROM players WHERE (initial >= 'A') AND (initial < 'N')
    Player.filter(("A"..<"N").contains(initialColumn))
    ```
    
    > :point_up: **Note**: SQLite string comparison, by default, is case-sensitive and not Unicode-aware. See [string comparison](#string-comparison) if you need more control.

- `LIKE`
    
    The SQLite LIKE operator is available as the `like` method:
    
    ```swift
    // SELECT * FROM players WHERE (email LIKE '%@example.com')
    Player.filter(emailColumn.like("%@example.com"))
    ```
    
    > :point_up: **Note**: the SQLite LIKE operator is case-unsensitive but not Unicode-aware. For example, the expression `'a' LIKE 'A'` is true but `'æ' LIKE 'Æ'` is false.

- `MATCH`
    
    The full-text MATCH operator is available through [FTS3Pattern](#fts3pattern) (for FTS3 and FTS4 tables) and [FTS5Pattern](#fts5pattern) (for FTS5):
    
    FTS3 and FTS4:
    
    ```swift
    let pattern = FTS3Pattern(matchingAllTokensIn: "SQLite database")
    
    // SELECT * FROM documents WHERE documents MATCH 'sqlite database'
    Document.matching(pattern)
    
    // SELECT * FROM documents WHERE content MATCH 'sqlite database'
    Document.filter(contentColumn.match(pattern))
    ```
    
    FTS5:
    
    ```swift
    let pattern = FTS5Pattern(matchingAllTokensIn: "SQLite database")
    
    // SELECT * FROM documents WHERE documents MATCH 'sqlite database'
    Document.matching(pattern)
    ```


### SQL Functions

- `ABS`, `AVG`, `COUNT`, `LENGTH`, `MAX`, `MIN`, `SUM`:
    
    Those are based on the `abs`, `average`, `count`, `length`, `max`, `min` and `sum` Swift functions:
    
    ```swift
    // SELECT MIN(score), MAX(score) FROM players
    Player.select(min(scoreColumn), max(scoreColumn))
    
    // SELECT COUNT(name) FROM players
    Player.select(count(nameColumn))
    
    // SELECT COUNT(DISTINCT name) FROM players
    Player.select(count(distinct: nameColumn))
    ```

- `IFNULL`
    
    Use the Swift `??` operator:
    
    ```swift
    // SELECT IFNULL(name, 'Anonymous') FROM players
    Player.select(nameColumn ?? "Anonymous")
    
    // SELECT IFNULL(name, email) FROM players
    Player.select(nameColumn ?? emailColumn)
    ```

- `LOWER`, `UPPER`
    
    The query interface does not give access to those SQLite functions. Nothing against them, but they are not unicode aware.
    
    Instead, GRDB extends SQLite with SQL functions that call the Swift built-in string functions `capitalized`, `lowercased`, `uppercased`, `localizedCapitalized`, `localizedLowercased` and `localizedUppercased`:
    
    ```swift
    Player.select(nameColumn.uppercased())
    ```
    
    > :point_up: **Note**: When *comparing* strings, you'd rather use a [collation](#string-comparison):
    >
    > ```swift
    > let name: String = ...
    >
    > // Not recommended
    > nameColumn.uppercased() == name.uppercased()
    >
    > // Better
    > nameColumn.collating(.caseInsensitiveCompare) == name
    > ```

- Custom SQL functions and aggregates
    
    You can apply your own [custom SQL functions and aggregates](#custom-functions-):
    
    ```swift
    let f = DatabaseFunction("f", ...)
    
    // SELECT f(name) FROM players
    Player.select(f.apply(nameColumn))
    ```

    
## Fetching from Requests

Once you have a request, you can fetch the records at the origin of the request:

```swift
// Some request based on `Player`
let request = Player.filter(...)... // QueryInterfaceRequest<Player>

// Fetch players:
try request.fetchCursor(db) // A Cursor of Player
try request.fetchAll(db)    // [Player]
try request.fetchOne(db)    // Player?
```

See [fetching methods](#fetching-methods) for information about the `fetchCursor`, `fetchAll` and `fetchOne` methods.

For example:

```swift
let allPlayers = try Player.fetchAll(db)                            // [Player]
let arthur = try Player.filter(nameColumn == "Arthur").fetchOne(db) // Player?
```


**When the selected columns don't fit the source type**, change your target: any other type that adopts the [RowConvertible](#rowconvertible-protocol) protocol, plain [database rows](#fetching-rows), and even [values](#values):

```swift
let maxScore = try Player.select(max(scoreColumn))
    .asRequest(of: Int.self)
    .fetchOne(db) // Int?

let row = try Player.select(min(scoreColumn), max(scoreColumn))
    .asRequest(of: Row.self)
    .fetchOne(db)!
let minScore = row[0] as Int?
let maxScore = row[1] as Int?
```

More information about `asRequest(of:)` can be found in the [Custom Requests](#custom-requests) chapter.


## Fetching By Key

**Fetching records according to their primary key** is a very common task. It has a shortcut which accepts any single-column primary key:

```swift
// SELECT * FROM players WHERE id = 1
try Player.fetchOne(db, key: 1)              // Player?

// SELECT * FROM players WHERE id IN (1, 2, 3)
try Player.fetchAll(db, keys: [1, 2, 3])     // [Player]

// SELECT * FROM players WHERE isoCode = 'FR'
try Country.fetchOne(db, key: "FR")          // Country?

// SELECT * FROM countries WHERE isoCode IN ('FR', 'US')
try Country.fetchAll(db, keys: ["FR", "US"]) // [Country]
```

When the table has no explicit primary key, GRDB uses the [hidden "rowid" column](#the-implicit-rowid-primary-key):

```swift
// SELECT * FROM documents WHERE rowid = 1
try Document.fetchOne(db, key: 1)            // Document?
```

For multiple-column primary keys and unique keys defined by unique indexes, provide a dictionary:

```swift
// SELECT * FROM citizenships WHERE playerID = 1 AND countryISOCode = 'FR'
try Citizenship.fetchOne(db, key: ["playerID": 1, "countryISOCode": "FR"]) // Citizenship?

// SELECT * FROM players WHERE email = 'arthur@example.com'
try Player.fetchOne(db, key: ["email": "arthur@example.com"])              // Player?
```


## Fetching Aggregated Values

**Requests can count.** The `fetchCount()` method returns the number of rows that would be returned by a fetch request:

```swift
// SELECT COUNT(*) FROM players
let count = try Player.fetchCount(db) // Int

// SELECT COUNT(*) FROM players WHERE email IS NOT NULL
let count = try Player.filter(emailColumn != nil).fetchCount(db)

// SELECT COUNT(DISTINCT name) FROM players
let count = try Player.select(nameColumn).distinct().fetchCount(db)

// SELECT COUNT(*) FROM (SELECT DISTINCT name, score FROM players)
let count = try Player.select(nameColumn, scoreColumn).distinct().fetchCount(db)
```


**Other aggregated values** can also be selected and fetched (see [SQL Functions](#sql-functions)):

```swift
let maxScore = try Player.select(max(scoreColumn))
    .asRequest(of: Int.self)
    .fetchOne(db) // Int?

let row = try Player.select(min(scoreColumn), max(scoreColumn))
    .asRequest(of: Row.self)
    .fetchOne(db)!
let minScore = row[0] as Int?
let maxScore = row[1] as Int?
```

More information about `asRequest(of:)` can be found in the [Custom Requests](#custom-requests) chapter.


## Delete Requests

**Requests can delete records**, with the `deleteAll()` method:

```swift
// DELETE FROM players WHERE email IS NULL
let request = Player.filter(emailColumn == nil)
try request.deleteAll(db)
```

> :point_up: **Note** Deletion methods are only available for records that adopts the [Persistable](#persistable-protocol) protocol.

**Deleting records according to their primary key** is also quite common. It has a shortcut which accepts any single-column primary key:

```swift
// DELETE FROM players WHERE id = 1
try Player.deleteOne(db, key: 1)

// DELETE FROM players WHERE id IN (1, 2, 3)
try Player.deleteAll(db, keys: [1, 2, 3])

// DELETE FROM players WHERE isoCode = 'FR'
try Country.deleteOne(db, key: "FR")

// DELETE FROM countries WHERE isoCode IN ('FR', 'US')
try Country.deleteAll(db, keys: ["FR", "US"])
```

When the table has no explicit primary key, GRDB uses the [hidden "rowid" column](#the-implicit-rowid-primary-key):

```swift
// DELETE FROM documents WHERE rowid = 1
try Document.deleteOne(db, key: 1)
```

For multiple-column primary keys and unique keys defined by unique indexes, provide a dictionary:

```swift
// DELETE FROM citizenships WHERE playerID = 1 AND countryISOCode = 'FR'
try Citizenship.deleteOne(db, key: ["playerID": 1, "countryISOCode": "FR"])

// DELETE FROM players WHERE email = 'arthur@example.com'
Player.deleteOne(db, key: ["email": "arthur@example.com"])
```


## Custom Requests

Until now, we have seen [requests](#requests) created from any type that adopts the [TableMapping](#tablemapping-protocol) protocol:

```swift
let request = Player.all()  // QueryInterfaceRequest<Player>
```

Those requests of type `QueryInterfaceRequest` can fetch, count, and delete records:

```swift
try request.fetchCursor(db) // A Cursor of Player
try request.fetchAll(db)    // [Player]
try request.fetchOne(db)    // Player?
try request.fetchCount(db)  // Int
try request.deleteAll(db)
```

**When the query interface can not generate the SQL you need**, you can still fallback to [raw SQL](#fetch-queries):

```swift
// Custom SQL is always welcome
try Player.fetchAll(db, "SELECT ...")   // [Player]
```

But you may prefer to bring some elegance back in, and build custom requests on top of the `Request` and `TypedRequest` protocols:

```swift
// No custom SQL in sight
try Player.customRequest().fetchAll(db) // [Player]
```

Unlike QueryInterfaceRequest, these protocols can't delete. But they can fetch and count:

```swift
/// The protocol for all types that define a way to fetch database rows.
protocol Request {
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?)
    
    /// The number of rows fetched by the request.
    func fetchCount(_ db: Database) throws -> Int
}

/// The protocol for requests that know how to decode database rows.
protocol TypedRequest : Request {
    /// The type that can convert raw database rows to fetched values
    associatedtype RowDecoder
}
```

The `prepare` method returns a tuple made of a [prepared statement](#prepared-statements) and an optional [row adapter](#row-adapters). The prepared statement tells which SQL query should be executed. The row adapter can help *presenting* the fetched rows in the way expected by the row consumers (we'll see an example below).

The `fetchCount` method has a default implementation that builds a correct but naive SQL query from the statement returned by `prepare`: `SELECT COUNT(*) FROM (...)`. Adopting types can refine the counting SQL by customizing their `fetchCount` implementation.


### Fetching From Custom Requests

A Request doesn't know what to fetch, but it can feed the [fetching methods](#fetching-methods) of any fetchable type ([Row](#fetching-rows), [value](#value-queries), or [record](#records)):

```swift
let request: Request = ...
try Row.fetchCursor(db, request) // A Cursor of Row
try String.fetchAll(db, request) // [String]
try Player.fetchOne(db, request) // Player?
```

On top of that, a TypedRequest knows exactly what it has to do when its RowDecoder associated type can decode database rows ([Row](#fetching-rows) itself, [values](#value-queries), or [records](#records)):

```swift
let request = ...                // Some TypedRequest that fetches Player
try request.fetchCursor(db)      // A Cursor of Player
try request.fetchAll(db)         // [Player]
try request.fetchOne(db)         // Player?
```


### Building Custom Requests

**To build custom requests**, you can create your own type that adopts the protocols, or derive requests from other requests, or use one of the built-in concrete types:

- [SQLRequest](http://groue.github.io/GRDB.swift/docs/1.3/Structs/SQLRequest.html): a Request built from raw SQL
- [AnyRequest](http://groue.github.io/GRDB.swift/docs/1.3/Structs/AnyRequest.html): a type-erased Request
- [AnyTypedRequest](http://groue.github.io/GRDB.swift/docs/1.3/Structs/AnyTypedRequest.html): a type-erased TypedRequest

Use the `asRequest(of:)` method to define the type fetched by the request:

```swift
let maxScore = Player.select(max(scoreColumn))
    .asRequest(of: Int.self)
    .fetchOne(db)

extension Player {
    static func customRequest(...) -> AnyTypedRequest<Player> {
        let request = SQLRequest("SELECT ...", arguments: ...)
        return request.asRequest(of: Player.self)
    }
}

try Player.customRequest(...).fetchAll(db)   // [Player]
try Player.customRequest(...).fetchCount(db) // Int
```

[**:fire: EXPERIMENTAL**](#what-are-experimental-features): Use the `adapted()` method to ease the consumption of complex rows with [row adapters](#row-adapters):

```swift
struct BookAuthorPair : RowConvertible {
    let book: Book
    let author: Author
    
    init(row: Row) {
        // Those scopes are defined by the all() method below
        book = Book(row: row.scoped(on: "books")!)
        author = Author(row: row.scoped(on: "authors")!)
    }
    
    static func all() -> AdaptedTypedRequest<AnyTypedRequest<BookAuthorPair>> {
        return SQLRequest("""
            SELECT books.*, authors.*
            FROM books
            JOIN authors ON authors.id = books.authorID
            """)
            .asRequest(of: BookAuthorPair.self)
            .adapted { db in
                try ScopeAdapter([
                    "books": SuffixRowAdapter(fromIndex: 0),
                    "authors": SuffixRowAdapter(fromIndex: db.columnCount(in: "books"))])
            }
    }
    
    static func fetchAll(_ db: Database) throws -> [BookAuthorPair] {
        return try all().fetchAll(db)
    }
}

for pair in try BookAuthorPair.fetchAll(db) {
    print("\(pair.book.title) by \(pair.author.name)")
}
```
