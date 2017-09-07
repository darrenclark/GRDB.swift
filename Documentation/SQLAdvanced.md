Advanced SQL
============

- [Custom Value Types](#custom-value-types)
- [Prepared Statements](#prepared-statements)
- [Custom SQL Functions and Aggregates](#custom-sql-functions-and-aggregates)
- [Database Schema Introspection](#database-schema-introspection)
- [Row Adapters](#row-adapters)
- [Raw SQLite Pointers](#raw-sqlite-pointers)


## Custom Value Types

Conversion to and from the database is based on the `DatabaseValueConvertible` protocol:

```swift
protocol DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from dbValue, if possible.
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self?
}
```

All types that adopt this protocol can be used like all other [values](#values) (Bool, Int, String, Date, Swift enums, etc.)

The `databaseValue` property returns [DatabaseValue](#databasevalue), a type that wraps the five values supported by SQLite: NULL, Int64, Double, String and Data. Since DatabaseValue has no public initializer, use `DatabaseValue.null`, or another type that already adopts the protocol: `1.databaseValue`, `"foo".databaseValue`, etc. Conversion to DatabaseValue *must not* fail.

The `fromDatabaseValue()` factory method returns an instance of your custom type if the database value contains a suitable value. If the database value does not contain a suitable value, such as "foo" for Date, `fromDatabaseValue` *must* return nil (GRDB will interpret this nil result as a conversion error, and react accordingly).

The [GRDB Extension Guide](Documentation/ExtendingGRDB.md) contains sample code that has UIColor adopt DatabaseValueConvertible.


## Prepared Statements

**Prepared Statements** let you prepare an SQL query and execute it later, several times if you need, with different arguments.

There are two kinds of prepared statements: **select statements**, and **update statements**:

```swift
try dbQueue.inDatabase { db in
    let updateSQL = "INSERT INTO players (name, score) VALUES (:name, :score)"
    let updateStatement = try db.makeUpdateStatement(updateSQL)
    
    let selectSQL = "SELECT * FROM players WHERE name = ?"
    let selectStatement = try db.makeSelectStatement(selectSQL)
}
```

The `?` and colon-prefixed keys like `:name` in the SQL query are the statement arguments. You set them with arrays or dictionaries (arguments are actually of type [StatementArguments](http://groue.github.io/GRDB.swift/docs/1.3/Structs/StatementArguments.html), which happens to adopt the ExpressibleByArrayLiteral and ExpressibleByDictionaryLiteral protocols).

```swift
updateStatement.arguments = ["name": "Arthur", "score": 1000]
selectStatement.arguments = ["Arthur"]
```

After arguments are set, you can execute the prepared statement:

```swift
try updateStatement.execute()
```

Select statements can be used wherever a raw SQL query string would fit (see [fetch queries](#fetch-queries)):

```swift
let rows = try Row.fetchCursor(selectStatement)    // A Cursor of Row
let players = try Player.fetchAll(selectStatement) // [Player]
let player = try Player.fetchOne(selectStatement)  // Player?
```

You can set the arguments at the moment of the statement execution:

```swift
try updateStatement.execute(arguments: ["name": "Arthur", "score": 1000])
let player = try Player.fetchOne(selectStatement, arguments: ["Arthur"])
```

> :point_up: **Note**: it is a programmer error to reuse a prepared statement that has failed: GRDB may crash if you do so.

See [row queries](#row-queries), [value queries](#value-queries), and [Records](#records) for more information.


### Prepared Statements Cache

When the same query will be used several times in the lifetime of your application, you may feel a natural desire to cache prepared statements.

**Don't cache statements yourself.**

> :point_up: **Note**: This is because you don't have the necessary tools. Statements are tied to specific SQLite connections and dispatch queues which you don't manage yourself, especially when you use [database pools](#database-pools). A change in the database schema [may, or may not](https://www.sqlite.org/compile.html#max_schema_retry) invalidate a statement. On systems earlier than iOS 8.2 and OSX 10.10 that don't have the [sqlite3_close_v2 function](https://www.sqlite.org/c3ref/close.html), SQLite connections won't close properly if statements have been kept alive.

Instead, use the `cachedUpdateStatement` and `cachedSelectStatement` methods. GRDB does all the hard caching and [memory management](#memory-management) stuff for you:

```swift
let updateStatement = try db.cachedUpdateStatement(sql)
let selectStatement = try db.cachedSelectStatement(sql)
```

Should a cached prepared statement throw an error, don't reuse it (it is a programmer error). Instead, reload it from the cache.


## Custom SQL Functions and Aggregates

**SQLite lets you define SQL functions and aggregates.**

A custom SQL function or aggregate extends SQLite:

```sql
SELECT reverse(name) FROM players;   -- custom function
SELECT maxLength(name) FROM players; -- custom aggregate
```

- [Custom SQL Functions](#custom-sql-functions)
- [Custom Aggregates](#custom-aggregates)


### Custom SQL Functions

```swift
let reverse = DatabaseFunction("reverse", argumentCount: 1, pure: true) { (values: [DatabaseValue]) in
    // Extract string value, if any...
    guard let string = String.fromDatabaseValue(values[0]) else {
        return nil
    }
    // ... and return reversed string:
    return String(string.characters.reversed())
}
dbQueue.add(function: reverse)   // Or dbPool.add(function: ...)

try dbQueue.inDatabase { db in
    // "oof"
    try String.fetchOne(db, "SELECT reverse('foo')")!
}
```

The *function* argument takes an array of [DatabaseValue](#databasevalue), and returns any valid [value](#values) (Bool, Int, String, Date, Swift enums, etc.) The number of database values is guaranteed to be *argumentCount*.

SQLite has the opportunity to perform additional optimizations when functions are "pure", which means that their result only depends on their arguments. So make sure to set the *pure* argument to true when possible.


**Functions can take a variable number of arguments:**

When you don't provide any explicit *argumentCount*, the function can take any number of arguments:

```swift
let averageOf = DatabaseFunction("averageOf", pure: true) { (values: [DatabaseValue]) in
    let doubles = values.flatMap { Double.fromDatabaseValue($0) }
    return doubles.reduce(0, +) / Double(doubles.count)
}
dbQueue.add(function: averageOf)

try dbQueue.inDatabase { db in
    // 2.0
    try Double.fetchOne(db, "SELECT averageOf(1, 2, 3)")!
}
```


**Functions can throw:**

```swift
let sqrt = DatabaseFunction("sqrt", argumentCount: 1, pure: true) { (values: [DatabaseValue]) in
    guard let double = Double.fromDatabaseValue(values[0]) else {
        return nil
    }
    guard double >= 0 else {
        throw DatabaseError(message: "invalid negative number")
    }
    return sqrt(double)
}
dbQueue.add(function: sqrt)

// SQLite error 1 with statement `SELECT sqrt(-1)`: invalid negative number
try dbQueue.inDatabase { db in
    try Double.fetchOne(db, "SELECT sqrt(-1)")!
}
```


**Use custom functions in the [query interface](#the-query-interface):**

```swift
// SELECT reverseString("name") FROM players
Player.select(reverseString.apply(nameColumn))
```


**GRDB ships with built-in SQL functions that perform unicode-aware string transformations.** See [Unicode](#unicode).


### Custom Aggregates

Before registering a custom aggregate, you need to define a type that adopts the `DatabaseAggregate` protocol:

```swift
protocol DatabaseAggregate {
    // Initializes an aggregate
    init()
    
    // Called at each step of the aggregation
    mutating func step(_ dbValues: [DatabaseValue]) throws
    
    // Returns the final result
    func finalize() throws -> DatabaseValueConvertible?
}
```

For example:

```swift
struct MaxLength : DatabaseAggregate {
    var maxLength: Int = 0
    
    mutating func step(_ dbValues: [DatabaseValue]) {
        // At each step, extract string value, if any...
        guard let string = String.fromDatabaseValue(dbValues[0]) else {
            return
        }
        // ... and update the result
        let length = string.characters.count
        if length > maxLength {
            maxLength = length
        }
    }
    
    func finalize() -> DatabaseValueConvertible? {
        return maxLength
    }
}

let maxLength = DatabaseFunction(
    "maxLength",
    argumentCount: 1,
    pure: true,
    aggregate: MaxLength.self)

dbQueue.add(function: maxLength)   // Or dbPool.add(function: ...)

try dbQueue.inDatabase { db in
    // Some Int
    try Int.fetchOne(db, "SELECT maxLength(name) FROM players")!
}
```

The `step` method of the aggregate takes an array of [DatabaseValue](#databasevalue). This array contains as many values as the *argumentCount* parameter (or any number of values, when *argumentCount* is omitted).

The `finalize` method of the aggregate returns the final aggregated [value](#values) (Bool, Int, String, Date, Swift enums, etc.).

SQLite has the opportunity to perform additional optimizations when aggregates are "pure", which means that their result only depends on their inputs. So make sure to set the *pure* argument to true when possible.


**Use custom aggregates in the [query interface](#the-query-interface):**

```swift
// SELECT maxLength("name") FROM players
Player.select(maxLength.apply(nameColumn))
    .asRequest(of: Int.self)
    .fetchOne(db) // Int?
```


## Database Schema Introspection

**SQLite provides database schema introspection tools**, such as the [sqlite_master](https://www.sqlite.org/faq.html#q7) table, and the pragma [table_info](https://www.sqlite.org/pragma.html#pragma_table_info):

```swift
try db.create(table: "players") { t in
    t.column("id", .integer).primaryKey()
    t.column("name", .text)
}

// <Row type:"table" name:"players" tbl_name:"players" rootpage:2
//      sql:"CREATE TABLE players(id INTEGER PRIMARY KEY, name TEXT)">
for row in try Row.fetchAll(db, "SELECT * FROM sqlite_master") {
    print(row)
}

// <Row cid:0 name:"id" type:"INTEGER" notnull:0 dflt_value:NULL pk:1>
// <Row cid:1 name:"name" type:"TEXT" notnull:0 dflt_value:NULL pk:0>
for row in try Row.fetchAll(db, "PRAGMA table_info('players')") {
    print(row)
}
```

GRDB provides high-level methods as well:

```swift
try db.tableExists("players")     // Bool, true if the table exists
try db.columnCount(in: "players") // Int, the number of columns in table
try db.indexes(on: "players")     // [IndexInfo], the indexes defined on the table
try db.table("players", hasUniqueKey: ["email"]) // Bool, true if column(s) is a unique key
try db.foreignKeys(on: "players") // [ForeignKeyInfo], the foreign keys defined on the table
try db.primaryKey("players")      // PrimaryKeyInfo?
```


## Row Adapters

**Row adapters let you present database rows in the way expected by the row consumers.**

They basically help two incompatible row interfaces to work together. For example, a row consumer expects a column named "consumed", but the produced row has a column named "produced".

In this case, the `ColumnMapping` row adapter comes in handy:

```swift
// Fetch a 'produced' column, and consume a 'consumed' column:
let adapter = ColumnMapping(["consumed": "produced"])
let row = try Row.fetchOne(db, "SELECT 'Hello' AS produced", adapter: adapter)!
row["consumed"] // "Hello"
row["produced"] // nil
```

Row adapters are values that adopt the [RowAdapter](http://groue.github.io/GRDB.swift/docs/1.3/Protocols/RowAdapter.html) protocol. You can implement your own custom adapters ([**:fire: EXPERIMENTAL**](#what-are-experimental-features)), or use one of the four built-in adapters:


### ColumnMapping

ColumnMapping renames columns. Build one with a dictionary whose keys are adapted column names, and values the column names in the raw row:

```swift
// <Row newName:"Hello">
let adapter = ColumnMapping(["newName": "oldName"])
let row = try Row.fetchOne(db, "SELECT 'Hello' AS oldName", adapter: adapter)!
```

### SuffixRowAdapter

`SuffixRowAdapter` hides the first columns in a row:

```swift
// <Row b:1 c:2>
let adapter = SuffixRowAdapter(fromIndex: 1)
let row = try Row.fetchOne(db, "SELECT 0 AS a, 1 AS b, 2 AS c", adapter: adapter)!
```

### RangeRowAdapter

`RangeRowAdapter` only exposes a range of columns.

```swift
// <Row b:1>
let adapter = RangeRowAdapter(1..<2)
let row = try Row.fetchOne(db, "SELECT 0 AS a, 1 AS b, 2 AS c", adapter: adapter)!
```

### ScopeAdapter

`ScopeAdapter` defines *row scopes*:

```swift
let adapter = ScopeAdapter([
    "left": RangeRowAdapter(0..<2),
    "right": RangeRowAdapter(2..<4)])
let row = try Row.fetchOne(db, "SELECT 0 AS a, 1 AS b, 2 AS c, 3 AS d", adapter: adapter)!
```

ScopeAdapter does not change the columns and values of the fetched row. Instead, it defines *scopes*, which you access with the `scoped(on:)` method. It returns an optional Row, which is nil if the scope is missing.

```swift
row                       // <Row a:0 b:1 c:2 d:3>
row.scoped(on: "left")    // <Row a:0 b:1>
row.scoped(on: "right")   // <Row c:2 d:3>
row.scoped(on: "missing") // nil
```

Scopes can be nested:

```swift
let adapter = ScopeAdapter([
    "left": ScopeAdapter([
        "left": RangeRowAdapter(0..<1),
        "right": RangeRowAdapter(1..<2)]),
    "right": ScopeAdapter([
        "left": RangeRowAdapter(2..<3),
        "right": RangeRowAdapter(3..<4)])
    ])
let row = try Row.fetchOne(db, "SELECT 0 AS a, 1 AS b, 2 AS c, 3 AS d", adapter: adapter)!

let leftRow = row.scoped(on: "left")!
leftRow.scoped(on: "left")  // <Row a:0>
leftRow.scoped(on: "right") // <Row b:1>

let rightRow = row.scoped(on: "right")!
rightRow.scoped(on: "left")  // <Row c:2>
rightRow.scoped(on: "right") // <Row d:3>
```

Any adapter can be extended with scopes:

```swift
let adapter = RangeRowAdapter(0..<2)
    .addingScopes(["remainder": SuffixRowAdapter(fromIndex: 2)])
let row = try Row.fetchOne(db, "SELECT 0 AS a, 1 AS b, 2 AS c, 3 AS d", adapter: adapter)!

row // <Row a:0 b:1>
row.scoped(on: "remainder") // <Row c:2 d:3>
```


## Raw SQLite Pointers

**If not all SQLite APIs are exposed in GRDB, you can still use the [SQLite C Interface](https://www.sqlite.org/c3ref/intro.html) and call [SQLite C functions](https://www.sqlite.org/c3ref/funclist.html).**

Those functions are embedded right into the GRDBCustom and GRCBCipher modules. For the "regular" GRDB framework: you'll need to import `SQLite3`, or `CSQLite`, depending on whether you use the Swift Package Manager or not:

```swift
#if SWIFT_PACKAGE
    import CSQLite // For Swift Package Manager
#else
    import SQLite3 // Otherwise
#endif

let sqliteVersion = String(cString: sqlite3_libversion())
```

Raw pointers to database connections and statements are available through the `Database.sqliteConnection` and `Statement.sqliteStatement` properties:

```swift
try dbQueue.inDatabase { db in
    // The raw pointer to a database connection:
    let sqliteConnection = db.sqliteConnection

    // The raw pointer to a statement:
    let statement = try db.makeSelectStatement("SELECT ...")
    let sqliteStatement = statement.sqliteStatement
}
```

> :point_up: **Notes**
>
> - Those pointers are owned by GRDB: don't close connections or finalize statements created by GRDB.
> - GRDB opens SQLite connections in the "[multi-thread mode](https://www.sqlite.org/threadsafe.html)", which (oddly) means that **they are not thread-safe**. Make sure you touch raw databases and statements inside their dedicated dispatch queues.
> - Use the raw SQLite C Interface at your own risk. GRDB won't prevent you from shooting yourself in the foot.

Before jumping in the low-level wagon, here is the list of all SQLite APIs used by GRDB:

- `sqlite3_aggregate_context`, `sqlite3_create_function_v2`, `sqlite3_result_blob`, `sqlite3_result_double`, `sqlite3_result_error`, `sqlite3_result_error_code`, `sqlite3_result_int64`, `sqlite3_result_null`, `sqlite3_result_text`, `sqlite3_user_data`, `sqlite3_value_blob`, `sqlite3_value_bytes`, `sqlite3_value_double`, `sqlite3_value_int64`, `sqlite3_value_text`, `sqlite3_value_type`: see [Custom SQL Functions and Aggregates](#custom-sql-functions-and-aggregates)
- `sqlite3_backup_finish`, `sqlite3_backup_init`, `sqlite3_backup_step`: see [Backup](#backup)
- `sqlite3_bind_blob`, `sqlite3_bind_double`, `sqlite3_bind_int64`, `sqlite3_bind_null`, `sqlite3_bind_parameter_count`, `sqlite3_bind_parameter_name`, `sqlite3_bind_text`, `sqlite3_clear_bindings`, `sqlite3_column_blob`, `sqlite3_column_bytes`, `sqlite3_column_count`, `sqlite3_column_double`, `sqlite3_column_int64`, `sqlite3_column_name`, `sqlite3_column_text`, `sqlite3_column_type`, `sqlite3_exec`, `sqlite3_finalize`, `sqlite3_prepare_v2`, `sqlite3_reset`, `sqlite3_step`: see [Executing Updates](#executing-updates), [Fetch Queries](#fetch-queries), [Prepared Statements](#prepared-statements), [Values](#values)
- `sqlite3_busy_handler`, `sqlite3_busy_timeout`: see [Configuration.busyMode](http://groue.github.io/GRDB.swift/docs/1.3/Structs/Configuration.html)
- `sqlite3_changes`, `sqlite3_total_changes`: see [Database.changesCount and Database.totalChangesCount](http://groue.github.io/GRDB.swift/docs/1.3/Classes/Database.html)
- `sqlite3_close`, `sqlite3_close_v2`, `sqlite3_next_stmt`, `sqlite3_open_v2`: see [Database Connections](#database-connections)
- `sqlite3_commit_hook`, `sqlite3_rollback_hook`, `sqlite3_update_hook`: see [TransactionObserver Protocol](#transactionobserver-protocol), [FetchedRecordsController](#fetchedrecordscontroller)
- `sqlite3_config`: see [Error Log](#error-log)
- `sqlite3_create_collation_v2`: see [String Comparison](#string-comparison)
- `sqlite3_db_release_memory`: see [Memory Management](#memory-management)
- `sqlite3_errcode`, `sqlite3_errmsg`, `sqlite3_errstr`, `sqlite3_extended_result_codes`: see [Error Handling](#error-handling)
- `sqlite3_key`, `sqlite3_rekey`: see [Encryption](#encryption)
- `sqlite3_last_insert_rowid`: see [Executing Updates](#executing-updates)
- `sqlite3_preupdate_count`, `sqlite3_preupdate_depth`, `sqlite3_preupdate_hook`, `sqlite3_preupdate_new`, `sqlite3_preupdate_old`: see [Support for SQLite Pre-Update Hooks](#support-for-sqlite-pre-update-hooks)
- `sqlite3_set_authorizer`: **reserved by GRDB**
- `sqlite3_sql`: see [Statement.sql](http://groue.github.io/GRDB.swift/docs/1.3/Classes/Statement.html)
- `sqlite3_trace`: see [Configuration.trace](http://groue.github.io/GRDB.swift/docs/1.3/Structs/Configuration.html)
- `sqlite3_wal_checkpoint_v2`: see [DatabasePool.checkpoint](http://groue.github.io/GRDB.swift/docs/1.3/Classes/DatabasePool.html)

