SQL Basics
==========

**In this section of the documentation, we will talk SQL.** Jump to the [query interface](#the-query-interface) if SQL is not your cup of tea.

- [Executing Updates](#executing-updates)
- [Fetch Queries](#fetch-queries)
    - [Fetching Methods](#fetching-methods)
    - [Row Queries](#row-queries)
    - [Value Queries](#value-queries)
- [Values](#values)
    - [Data](#data-and-memory-savings)
    - [Date and DateComponents](#date-and-datecomponents)
    - [NSNumber and NSDecimalNumber](#nsnumber-and-nsdecimalnumber)
    - [Swift enums](#swift-enums)
- [Transactions and Savepoints](#transactions-and-savepoints)
- [Database Backup](#database-backup)

## Executing Updates

Once granted with a [database connection](#database-connections), the `execute` method executes the SQL statements that do not return any database row, such as `CREATE TABLE`, `INSERT`, `DELETE`, `ALTER`, etc.

For example:

```swift
try dbQueue.inDatabase { db in
    try db.execute("""
        CREATE TABLE players (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            score INT)
        """)
    
    try db.execute(
        "INSERT INTO players (name, score) VALUES (:name, :score)",
        arguments: ["name": "Barbara", "score": 1000])
    
    // Join multiple statements with a semicolon:
    try db.execute("""
        INSERT INTO players (name, score) VALUES (?, ?);
        INSERT INTO players (name, score) VALUES (?, ?)
        """, arguments: ["Arthur", 750, "Barbara", 1000])
}
```

The `?` and colon-prefixed keys like `:name` in the SQL query are the **statements arguments**. You pass arguments with arrays or dictionaries, as in the example above. See [Values](#values) for more information on supported arguments types (Bool, Int, String, Date, Swift enums, etc.).

Never ever embed values directly in your SQL strings, and always use arguments instead. See [Avoiding SQL Injection](#avoiding-sql-injection) for more information.

**After an INSERT statement**, you can get the row ID of the inserted row:

```swift
try db.execute(
    "INSERT INTO players (name, score) VALUES (?, ?)",
    arguments: ["Arthur", 1000])
let playerId = db.lastInsertedRowID
```

Don't miss [Records](#records), that provide classic **persistence methods**:

```swift
let player = Player(name: "Arthur", score: 1000)
try player.insert(db)
let playerId = player.id
```


## Fetch Queries

[Database connections](#database-connections) let you fetch database rows, plain values, and custom models aka "records".

**Rows** are the raw results of SQL queries:

```swift
try dbQueue.inDatabase { db in
    if let row = try Row.fetchOne(db, "SELECT * FROM wines WHERE id = ?", arguments: [1]) {
        let name: String = row["name"]
        let color: Color = row["color"]
        print(name, color)
    }
}
```


**Values** are the Bool, Int, String, Date, Swift enums, etc. stored in row columns:

```swift
try dbQueue.inDatabase { db in
    let urls = try URL.fetchCursor(db, "SELECT url FROM wines")
    while let url = try urls.next() {
        print(url)
    }
}
```


**Records** are your application objects that can initialize themselves from rows:

```swift
let wines = try dbQueue.inDatabase { db in
    try Wine.fetchAll(db, "SELECT * FROM wines")
}
```

- [Fetching Methods](#fetching-methods) and [Cursors](#cursors)
- [Row Queries](#row-queries)
- [Value Queries](#value-queries)
- [Records](#records)


### Fetching Methods

**Throughout GRDB**, you can always fetch *cursors*, *arrays*, or *single values* of any fetchable type (database [row](#row-queries), simple [value](#value-queries), or custom [record](#records)):

```swift
try Row.fetchCursor(...) // A Cursor of Row
try Row.fetchAll(...)    // [Row]
try Row.fetchOne(...)    // Row?
```

- `fetchCursor` returns a **[cursor](#cursors)** over fetched values:
    
    ```swift
    let rows = try Row.fetchCursor(db, "SELECT ...") // A Cursor of Row
    ```
    
- `fetchAll` returns an **array**:
    
    ```swift
    let players = try Player.fetchAll(db, "SELECT ...") // [Player]
    ```

- `fetchOne` returns a **single optional value**, and consumes a single database row (if any).
    
    ```swift
    let count = try Int.fetchOne(db, "SELECT COUNT(*) ...") // Int?
    ```


#### Cursors

**Whenever you consume several rows from the database, you can fetch a Cursor, or an Array**.

The `fetchAll()` method returns a regular Swift array, that you iterate like all other arrays:

```swift
try dbQueue.inDatabase { db in
    // [Player]
    let players = try Player.fetchAll(db, "SELECT ...")
    for player in players {
        // use player
    }
}
```

Unlike arrays, cursors returned by `fetchCursor()` load their results step after step:

```swift
try dbQueue.inDatabase { db in
    // Cursor of Player
    let players = try Player.fetchCursor(db, "SELECT ...")
    while let player = try players.next() {
        // use player
    }
}
```

Both arrays and cursors can iterate over database results. How do you choose one or the other? Look at the differences:

- Arrays may be consumed on any thread.
- Arrays contain copies of database values. They can take a lot of memory, when there are many fetched results.
- Arrays can be iterated many times.
- Cursors can not be used on any thread: you must consume them in a protected database queue.
- Cursors iterate database results in a lazy fashion, and don't consume much memory.
- Cursors can be iterated only one time.
- Cursors are granted with direct access to SQLite: you can especially expect the best performance from cursors of raw database rows and some primitive types like `Int`, `String`, or `Bool` that adopt the [StatementColumnConvertible](http://groue.github.io/GRDB.swift/docs/1.3/Protocols/StatementColumnConvertible.html) protocol.

If you don't see, or don't care about the difference, use arrays. If you care about memory and performance, use cursors when appropriate.

**There are several cursor types**, depending on the type of fetched values (database [row](#row-queries), simple [value](#value-queries), or custom [record](#records)):

```swift
Row.fetchCursor(...)    // RowCursor
Int.fetchCursor(...)    // ColumnCursor<Int>
Date.fetchCursor(...)   // DatabaseValueCursor<Date>
Player.fetchCursor(...) // RecordCursor<Player>
```

All cursor types adopt the [Cursor](http://groue.github.io/GRDB.swift/docs/1.3/Protocols/Cursor.html) protocol, which looks a lot like standard [lazy sequences](https://developer.apple.com/reference/swift/lazysequenceprotocol) of Swift. As such, cursors come with many methods: `contains`, `enumerated`, `filter`, `first`, `flatMap`, `forEach`, `joined`, `map`, `reduce`:

```swift
// Iterate all Github links
try URL
    .fetchCursor(db, "SELECT url FROM links")
    .filter { url in url.host == "github.com" }
    .forEach { url in ... }

// Turn a cursor into an array:
let cursor = URL
    .fetchCursor(db, "SELECT url FROM links")
    .filter { url in url.host == "github.com" }
let githubURLs = try Array(cursor) // [URL]
```

> :point_up: Don't modify the fetched results during a cursor iteration:
> 
> ```swift
> // Undefined behavior
> while let place = try places.next() {
>     try db.execute("DELETE ...")
> }
> ```
>
> :point_up: **Don't turn a cursor of `Row` into an array**. You would not get the distinct rows you expect. To get a array of rows, use `Row.fetchAll(...)`. Generally speaking, make sure you copy a row whenever you extract it from a cursor for later use: `row.copy()`.


### Row Queries

- [Fetching Rows](#fetching-rows)
- [Column Values](#column-values)
- [DatabaseValue](#databasevalue)
- [Rows as Dictionaries](#rows-as-dictionaries)


#### Fetching Rows

Fetch **cursors** of rows, **arrays**, or **single** rows (see [fetching methods](#fetching-methods)):

```swift
try dbQueue.inDatabase { db in
    try Row.fetchCursor(db, "SELECT ...", arguments: ...) // A Cursor of Row
    try Row.fetchAll(db, "SELECT ...", arguments: ...)    // [Row]
    try Row.fetchOne(db, "SELECT ...", arguments: ...)    // Row?
    
    let rows = try Row.fetchCursor(db, "SELECT * FROM wines")
    while let row = try rows.next() {
        let name: String = row["name"]
        let color: Color = row["color"]
        print(name, color)
    }
}

let rows = try dbQueue.inDatabase { db in
    try Row.fetchAll(db, "SELECT * FROM players")
}
```

Arguments are optional arrays or dictionaries that fill the positional `?` and colon-prefixed keys like `:name` in the query:

```swift
let rows = try Row.fetchAll(db,
    "SELECT * FROM players WHERE name = ?",
    arguments: ["Arthur"])

let rows = try Row.fetchAll(db,
    "SELECT * FROM players WHERE name = :name",
    arguments: ["name": "Arthur"])
```

See [Values](#values) for more information on supported arguments types (Bool, Int, String, Date, Swift enums, etc.), and [StatementArguments](http://groue.github.io/GRDB.swift/docs/1.3/Structs/StatementArguments.html) for a detailed documentation of SQLite arguments.

Unlike row arrays that contain copies of the database rows, row cursors are close to the SQLite metal, and require a little care:

> :point_up: **Don't turn a cursor of `Row` into an array**. You would not get the distinct rows you expect. To get a array of rows, use `Row.fetchAll(...)`. Generally speaking, make sure you copy a row whenever you extract it from a cursor for later use: `row.copy()`.


#### Column Values

**Read column values** by index or column name:

```swift
let name: String = row[0]      // 0 is the leftmost column
let name: String = row["name"] // Leftmost matching column - lookup is case-insensitive
let name: String = row[Column("name")] // Using query interface's Column
```

Make sure to ask for an optional when the value may be NULL:

```swift
let name: String? = row["name"]
```

The `row[]` subscript returns the type you ask for. See [Values](#values) for more information on supported value types:

```swift
let bookCount: Int     = row["bookCount"]
let bookCount64: Int64 = row["bookCount"]
let hasBooks: Bool     = row["bookCount"] // false when 0

let string: String     = row["date"]      // "2015-09-11 18:14:15.123"
let date: Date         = row["date"]      // Date
self.date = row["date"] // Depends on the type of the property.
```

You can also use the `as` type casting operator:

```swift
row[...] as Int
row[...] as Int?
```

> :warning: **Warning**: avoid the `as!` and `as?` operators, because they misbehave in the context of type inference (see [rdar://21676393](http://openradar.appspot.com/radar?id=4951414862249984)):
> 
> ```swift
> if let int = row[...] as? Int { ... } // BAD - doesn't work
> if let int = row[...] as Int? { ... } // GOOD
> ```

Generally speaking, you can extract the type you need, *provided it can be converted from the underlying SQLite value*:

- **Successful conversions include:**
    
    - All numeric SQLite values to all numeric Swift types, and Bool (zero is the only false boolean).
    - Text SQLite values to Swift String.
    - Blob SQLite values to Foundation Data.
    
    See [Values](#values) for more information on supported types (Bool, Int, String, Date, Swift enums, etc.)

- **NULL returns nil.**

    ```swift
    let row = try Row.fetchOne(db, "SELECT NULL")!
    row[0] as Int? // nil
    row[0] as Int  // fatal error: could not convert NULL to Int.
    ```
    
    There is one exception, though: the [DatabaseValue](#databasevalue) type:
    
    ```swift
    row[0] as DatabaseValue // DatabaseValue.null
    ```
    
- **Missing columns return nil.**
    
    ```swift
    let row = try Row.fetchOne(db, "SELECT 'foo' AS foo")!
    row["missing"] as String? // nil
    row["missing"] as String  // fatal error: no such column: missing
    ```
    
    You can explicitly check for a column presence with the `hasColumn` method.

- **Invalid conversions throw a fatal error.**
    
    ```swift
    let row = try Row.fetchOne(db, "SELECT 'Mom’s birthday'")!
    row[0] as String // "Mom’s birthday"
    row[0] as Date?  // fatal error: could not convert "Mom’s birthday" to Date.
    row[0] as Date   // fatal error: could not convert "Mom’s birthday" to Date.
    ```
    
    This fatal error can be avoided with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method.
    
- **SQLite has a weak type system, and provides [convenience conversions](https://www.sqlite.org/c3ref/column_blob.html) that can turn Blob to String, String to Int, etc.**
    
    GRDB will sometimes let those conversions go through:
    
    ```swift
    let rows = try Row.fetchCursor(db, "SELECT '20 small cigars'")
    while let row = try rows.next() {
        row[0] as Int   // 20
    }
    ```
    
    Don't freak out: those conversions did not prevent SQLite from becoming the immensely successful database engine you want to use. And GRDB adds safety checks described just above. You can also prevent those convenience conversions altogether by using the [DatabaseValue](#databasevalue) type.


#### DatabaseValue

**DatabaseValue is an intermediate type between SQLite and your values, which gives information about the raw value stored in the database.**

You get DatabaseValue just like other value types:

```swift
let dbValue: DatabaseValue = row[0]
let dbValue: DatabaseValue = row["name"]

// Check for NULL:
dbValue.isNull // Bool

// All the five storage classes supported by SQLite:
switch dbValue.storage {
case .null:                 print("NULL")
case .int64(let int64):     print("Int64: \(int64)")
case .double(let double):   print("Double: \(double)")
case .string(let string):   print("String: \(string)")
case .blob(let data):       print("Data: \(data)")
}
```

You can extract regular [values](#values) (Bool, Int, String, Date, Swift enums, etc.) from DatabaseValue with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method:

```swift
let dbValue: DatabaseValue = row["bookCount"]
let bookCount   = Int.fromDatabaseValue(dbValue)   // Int?
let bookCount64 = Int64.fromDatabaseValue(dbValue) // Int64?
let hasBooks    = Bool.fromDatabaseValue(dbValue)  // Bool?, false when 0

let dbValue: DatabaseValue = row["date"]
let string = String.fromDatabaseValue(dbValue)     // "2015-09-11 18:14:15.123"
let date   = Date.fromDatabaseValue(dbValue)       // Date?
```

`fromDatabaseValue` returns nil for invalid conversions:

```swift
let row = try Row.fetchOne(db, "SELECT 'Mom’s birthday'")!
let dbValue: DatabaseValue = row[0]
let string = String.fromDatabaseValue(dbValue) // "Mom’s birthday"
let int    = Int.fromDatabaseValue(dbValue)    // nil
let date   = Date.fromDatabaseValue(dbValue)   // nil
```

This turns out useful when you process untrusted databases. Compare:

```swift
let date: Date? = row[0]  // fatal error: could not convert "Mom’s birthday" to Date.
let date = Date.fromDatabaseValue(row[0]) // nil
```


#### Rows as Dictionaries

Row adopts the standard [Collection](https://developer.apple.com/reference/swift/collection) protocol, and can be seen as a dictionary of [DatabaseValue](#databasevalue):

```swift
// All the (columnName, dbValue) tuples, from left to right:
for (columnName, dbValue) in row {
    ...
}
```

**You can build rows from dictionaries** (standard Swift dictionaries and NSDictionary). See [Values](#values) for more information on supported types:

```swift
let row: Row = ["name": "foo", "date": nil]
let row = Row(["name": "foo", "date": nil])
let row = Row(/* [AnyHashable: Any] */) // nil if invalid dictionary
```

Yet rows are not real dictionaries: they are ordered, and may contain duplicate keys:

```swift
let row = try Row.fetchOne(db, "SELECT 1 AS foo, 2 AS foo")!
row.columnNames    // ["foo", "foo"]
row.databaseValues // [1, 2]
row["foo"]         // 1 (leftmost matching column)
for (columnName, dbValue) in row { ... } // ("foo", 1), ("foo", 2)
```


### Value Queries

Instead of rows, you can directly fetch **[values](#values)**. Like rows, fetch them as **cursors**, **arrays**, or **single** values (see [fetching methods](#fetching-methods)). Values are extracted from the leftmost column of the SQL queries:

```swift
try dbQueue.inDatabase { db in
    try Int.fetchCursor(db, "SELECT ...", arguments: ...) // A Cursor of Int
    try Int.fetchAll(db, "SELECT ...", arguments: ...)    // [Int]
    try Int.fetchOne(db, "SELECT ...", arguments: ...)    // Int?
    
    // When database may contain NULL:
    try Optional<Int>.fetchCursor(db, "SELECT ...", arguments: ...) // A Cursor of Int?
    try Optional<Int>.fetchAll(db, "SELECT ...", arguments: ...)    // [Int?]
}

let playerCount = try dbQueue.inDatabase { db in
    try Int.fetchOne(db, "SELECT COUNT(*) FROM players")!
}
```

`fetchOne` returns an optional value which is nil in two cases: either the SELECT statement yielded no row, or one row with a NULL value.

There are many supported value types (Bool, Int, String, Date, Swift enums, etc.). See [Values](#values) for more information:

```swift
let count = try Int.fetchOne(db, "SELECT COUNT(*) FROM players")! // Int
let urls = try URL.fetchAll(db, "SELECT url FROM links")          // [URL]
```


## Values

GRDB ships with built-in support for the following value types:

- **Swift Standard Library**: Bool, Double, Float, all signed and unsigned integer types, String, [Swift enums](#swift-enums).
    
- **Foundation**: [Data](#data-and-memory-savings), [Date](#date-and-datecomponents), [DateComponents](#date-and-datecomponents), NSNull, [NSNumber](#nsnumber-and-nsdecimalnumber), NSString, URL, [UUID](#uuid).
    
- **CoreGraphics**: CGFloat.

- **[DatabaseValue](#databasevalue)**, the type which gives information about the raw value stored in the database.

- **Full-Text Patterns**: [FTS3Pattern](#fts3pattern) and [FTS5Pattern](#fts5pattern).

- Generally speaking, all types that adopt the [DatabaseValueConvertible](#custom-value-types) protocol.

Values can be used as [statement arguments](http://groue.github.io/GRDB.swift/docs/1.3/Structs/StatementArguments.html):

```swift
let url: URL = ...
let verified: Bool = ...
try db.execute(
    "INSERT INTO links (url, verified) VALUES (?, ?)",
    arguments: [url, verified])
```

Values can be [extracted from rows](#column-values):

```swift
let rows = try Row.fetchCursor(db, "SELECT * FROM links")
while let row = try rows.next() {
    let url: URL = row["url"]
    let verified: Bool = row["verified"]
}
```

Values can be [directly fetched](#value-queries):

```swift
let urls = try URL.fetchAll(db, "SELECT url FROM links")  // [URL]
```

Use values in [Records](#records):

```swift
class Link : Record {
    var url: URL
    var isVerified: Bool
    
    required init(row: Row) {
        url = row["url"]
        isVerified = row["verified"]
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["url"] = url
        container["verified"] = isVerified
    }
}
```

Use values in the [query interface](#the-query-interface):

```swift
let url: URL = ...
let link = try Link.filter(urlColumn == url).fetchOne(db)
```


### Data (and Memory Savings)

**Data** suits the BLOB SQLite columns. It can be stored and fetched from the database just like other [values](#values):

```swift
let rows = try Row.fetchCursor(db, "SELECT data, ...")
while let row = try rows.next() {
    let data: Data = row["data"]
}
```

At each step of the request iteration, the `row[]` subscript creates *two copies* of the database bytes: one fetched by SQLite, and another, stored in the Swift Data value.

**You have the opportunity to save memory** by not copying the data fetched by SQLite:

```swift
while let row = try rows.next() {
    let data = row.dataNoCopy(named: "data") // Data?
}
```

The non-copied data does not live longer than the iteration step: make sure that you do not use it past this point.


### Date and DateComponents

[**Date**](#date) and [**DateComponents**](#datecomponents) can be stored and fetched from the database.

Here is the support provided by GRDB for the various [date formats](https://www.sqlite.org/lang_datefunc.html) supported by SQLite:

| SQLite format                | Date         | DateComponents |
|:---------------------------- |:------------:|:--------------:|
| YYYY-MM-DD                   |     Read ¹   |   Read/Write   |
| YYYY-MM-DD HH:MM             |     Read ¹   |   Read/Write   |
| YYYY-MM-DD HH:MM:SS          |     Read ¹   |   Read/Write   |
| YYYY-MM-DD HH:MM:SS.SSS      | Read/Write ¹ |   Read/Write   |
| YYYY-MM-DD**T**HH:MM         |     Read ¹   |      Read      |
| YYYY-MM-DD**T**HH:MM:SS      |     Read ¹   |      Read      |
| YYYY-MM-DD**T**HH:MM:SS.SSS  |     Read ¹   |      Read      |
| HH:MM                        |              |   Read/Write   |
| HH:MM:SS                     |              |   Read/Write   |
| HH:MM:SS.SSS                 |              |   Read/Write   |
| Timestamps since unix epoch  |     Read ²   |                |
| `now`                        |              |                |

¹ Dates are stored and read in the UTC time zone. Missing components are assumed to be zero.

² GRDB 2.0 interprets numerical values as timestamps that fuel `Date(timeIntervalSince1970:)`. Previous GRDB versions used to interpret numbers as [julian days](https://en.wikipedia.org/wiki/Julian_day). GRDB 2.0 still supports julian days, with the `Date(julianDay:)` initializer.


#### Date

**Date** can be stored and fetched from the database just like other [values](#values):

```swift
try db.execute(
    "INSERT INTO players (creationDate, ...) VALUES (?, ...)",
    arguments: [Date(), ...])

let creationDate: Date = row["creationDate"]
```

Dates are stored using the format "YYYY-MM-DD HH:MM:SS.SSS" in the UTC time zone. It is precise to the millisecond.

> :point_up: **Note**: this format was chosen because it is the only format that is:
> 
> - Comparable (`ORDER BY date` works)
> - Comparable with the SQLite keyword CURRENT_TIMESTAMP (`WHERE date > CURRENT_TIMESTAMP` works)
> - Able to feed [SQLite date & time functions](https://www.sqlite.org/lang_datefunc.html)
> - Precise enough
> 
> Yet this format may not fit your needs. For example, you may want to store dates as timestamps. In this case, store and load Doubles instead of Date, and perform the required conversions.


#### DateComponents

DateComponents is indirectly supported, through the **DatabaseDateComponents** helper type.

DatabaseDateComponents reads date components from all [date formats supported by SQLite](https://www.sqlite.org/lang_datefunc.html), and stores them in the format of your choice, from HH:MM to YYYY-MM-DD HH:MM:SS.SSS.

DatabaseDateComponents can be stored and fetched from the database just like other [values](#values):

```swift
let components = DateComponents()
components.year = 1973
components.month = 9
components.day = 18

// Store "1973-09-18"
let dbComponents = DatabaseDateComponents(components, format: .YMD)
try db.execute(
    "INSERT INTO players (birthDate, ...) VALUES (?, ...)",
    arguments: [dbComponents, ...])

// Read "1973-09-18"
let row = try Row.fetchOne(db, "SELECT birthDate ...")!
let dbComponents: DatabaseDateComponents = row["birthDate"]
dbComponents.format         // .YMD (the actual format found in the database)
dbComponents.dateComponents // DateComponents
```


### NSNumber and NSDecimalNumber

**NSNumber** can be stored and fetched from the database just like other [values](#values). Floating point NSNumbers are stored as Double. Integer and boolean, as Int64. Integers that don't fit Int64 won't be stored: you'll get a fatal error instead. Be cautious when an NSNumber contains an UInt64, for example.

NSDecimalNumber deserves a longer discussion:

**SQLite has no support for decimal numbers.** Given the table below, SQLite will actually store integers or doubles:

```sql
CREATE TABLE transfers (
    amount DECIMAL(10,5) -- will store integer or double, actually
)
```

This means that computations will not be exact:

```swift
try db.execute("INSERT INTO transfers (amount) VALUES (0.1)")
try db.execute("INSERT INTO transfers (amount) VALUES (0.2)")
let sum = try NSDecimalNumber.fetchOne(db, "SELECT SUM(amount) FROM transfers")!

// Yikes! 0.3000000000000000512
print(sum)
```

Don't blame SQLite or GRDB, and instead store your decimal numbers differently.

A classic technique is to store *integers* instead, since SQLite performs exact computations of integers. For example, don't store Euros, but store cents instead:

```swift
// Store
let amount = NSDecimalNumber(string: "0.1")                       // 0.1
let integerAmount = amount.multiplying(byPowerOf10: 2).int64Value // 100
try db.execute("INSERT INTO transfers (amount) VALUES (?)", arguments: [integerAmount])

// Read
let integerAmount = try Int64.fetchOne(db, "SELECT SUM(amount) FROM transfers")!    // 100
let amount = NSDecimalNumber(value: integerAmount).multiplying(byPowerOf10: -2) // 0.1
```


### UUID

**UUID** can be stored and fetched from the database just like other [values](#values). GRDB stores uuids as 16-bytes data blobs.


### Swift Enums

**Swift enums** and generally all types that adopt the [RawRepresentable](https://developer.apple.com/library/tvos/documentation/Swift/Reference/Swift_RawRepresentable_Protocol/index.html) protocol can be stored and fetched from the database just like their raw [values](#values):

```swift
enum Color : Int {
    case red, white, rose
}

enum Grape : String {
    case chardonnay, merlot, riesling
}

// Declare empty DatabaseValueConvertible adoption
extension Color : DatabaseValueConvertible { }
extension Grape : DatabaseValueConvertible { }

// Store
try db.execute(
    "INSERT INTO wines (grape, color) VALUES (?, ?)",
    arguments: [Grape.merlot, Color.red])

// Read
let rows = try Row.fetchCursor(db, "SELECT * FROM wines")
while let row = try rows.next() {
    let grape: Grape = row["grape"]
    let color: Color = row["color"]
}
```

**When a database value does not match any enum case**, you get a fatal error. This fatal error can be avoided with the [DatabaseValueConvertible.fromDatabaseValue()](#custom-value-types) method:

```swift
let row = try Row.fetchOne(db, "SELECT 'syrah'")!

row[0] as String  // "syrah"
row[0] as Grape?  // fatal error: could not convert "syrah" to Grape.
row[0] as Grape   // fatal error: could not convert "syrah" to Grape.
Grape.fromDatabaseValue(row[0])  // nil
```


## Transactions and Savepoints

The `DatabaseQueue.inTransaction()` and `DatabasePool.writeInTransaction()` methods open an SQLite transaction and run their closure argument in a protected dispatch queue. They block the current thread until your database statements are executed:

```swift
try dbQueue.inTransaction { db in
    let wine = Wine(color: .red, name: "Pomerol")
    try wine.insert(db)
    return .commit
}
```

If an error is thrown within the transaction body, the transaction is rollbacked and the error is rethrown by the `inTransaction` method. If you return `.rollback` from your closure, the transaction is also rollbacked, but no error is thrown.

If you want to insert a transaction between other database statements, you can use the Database.inTransaction() function, or even raw SQL statements:

```swift
try dbQueue.inDatabase { db in  // or dbPool.write { db in
    ...
    try db.inTransaction {
        ...
        return .commit
    }
    ...
    try db.execute("BEGIN TRANSACTION")
    ...
    try db.execute("COMMIT")
}
```

You can ask a database if a transaction is currently opened:

```swift
func myCriticalMethod(_ db: Database) throws {
    precondition(db.isInsideTransaction, "This method requires a transaction")
    try ...
}
```

Yet, you have a better option than checking for transactions: critical sections of your application should use savepoints, described below:

```swift
func myCriticalMethod(_ db: Database) throws {
    try db.inSavepoint {
        // Here the database is guaranteed to be inside a transaction.
        try ...
    }
}
```


### Savepoints

**Statements grouped in a savepoint can be rollbacked without invalidating a whole transaction:**

```swift
try dbQueue.inTransaction { db in
    try db.inSavepoint { 
        try db.execute("DELETE ...")
        try db.execute("INSERT ...") // need to rollback the delete above if this fails
        return .commit
    }
    
    // Other savepoints, etc...
    return .commit
}
```

If an error is thrown within the savepoint body, the savepoint is rollbacked and the error is rethrown by the `inSavepoint` method. If you return `.rollback` from your closure, the body is also rollbacked, but no error is thrown.

**Unlike transactions, savepoints can be nested.** They implicitly open a transaction if no one was opened when the savepoint begins. As such, they behave just like nested transactions. Yet the database changes are only committed to disk when the outermost savepoint is committed:

```swift
try dbQueue.inDatabase { db in
    try db.inSavepoint {
        ...
        try db.inSavepoint {
            ...
            return .commit
        }
        ...
        return .commit  // writes changes to disk
    }
}
```

SQLite savepoints are more than nested transactions, though. For advanced savepoints uses, use [SQL queries](https://www.sqlite.org/lang_savepoint.html).


### Transaction Kinds

SQLite supports [three kinds of transactions](https://www.sqlite.org/lang_transaction.html): deferred (the default), immediate, and exclusive.

The transaction kind can be changed in the database configuration, or for each transaction:

```swift
// Set the default transaction kind to IMMEDIATE:
var config = Configuration()
config.defaultTransactionKind = .immediate
let dbQueue = try DatabaseQueue(path: "...", configuration: config)

// BEGIN IMMEDIATE TRANSACTION ...
dbQueue.inTransaction { db in ... }

// BEGIN EXCLUSIVE TRANSACTION ...
dbQueue.inTransaction(.exclusive) { db in ... }
```


## Database Backup

**You can backup (copy) a database into another.**

Backups can for example help you copying an in-memory database to and from a database file when you implement NSDocument subclasses.

```swift
let source: DatabaseQueue = ...      // or DatabasePool
let destination: DatabaseQueue = ... // or DatabasePool
try source.backup(to: destination)
```

The `backup` method blocks the current thread until the destination database contains the same contents as the source database.

When the source is a [database pool](#database-pools), concurrent writes can happen during the backup. Those writes may, or may not, be reflected in the backup, but they won't trigger any error.
