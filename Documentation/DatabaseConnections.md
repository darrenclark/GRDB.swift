Database Connections
====================

GRDB provides two classes for accessing SQLite databases: `DatabaseQueue` and `DatabasePool`:

```swift
import GRDB

// Pick one:
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

The differences are:

- Database pools allow concurrent database accesses (this can improve the performance of multithreaded applications).
- Unless read-only, database pools open your SQLite database in the [WAL mode](https://www.sqlite.org/wal.html).
- Database queues support [in-memory databases](https://www.sqlite.org/inmemorydb.html).

**If you are not sure, choose DatabaseQueue.** You will always be able to switch to DatabasePool later.

- [Database Queues](#database-queues)
- [Database Pools](#database-pools)


## Database Queues

**Open a database queue** with the path to a database file:

```swift
import GRDB

let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")
let inMemoryDBQueue = DatabaseQueue()
```

SQLite creates the database file if it does not already exist. The connection is closed when the database queue gets deallocated.


**A database queue can be used from any thread.** The `inDatabase` and `inTransaction` methods are synchronous, and block the current thread until your database statements are executed in a protected dispatch queue. They safely serialize the database accesses:

```swift
// Execute database statements:
try dbQueue.inDatabase { db in
    try db.create(table: "places") { ... }
    try Place(...).insert(db)
}

// Wrap database statements in a transaction:
try dbQueue.inTransaction { db in
    if let place = try Place.fetchOne(db, key: 1) {
        try place.delete(db)
    }
    return .commit
}

// Read values:
try dbQueue.inDatabase { db in
    let places = try Place.fetchAll(db)
    let placeCount = try Place.fetchCount(db)
}

// Extract a value from the database:
let placeCount = try dbQueue.inDatabase { db in
    try Place.fetchCount(db)
}
```

**A database queue needs your application to follow rules in order to deliver its safety guarantees.** Please refer to the [Concurrency](#concurrency) chapter.

See [DemoApps/GRDBDemoiOS/Database.swift](DemoApps/GRDBDemoiOS/GRDBDemoiOS/Database.swift) for a sample code that sets up a database queue on iOS.


### DatabaseQueue Configuration

```swift
var config = Configuration()
config.readonly = true
config.foreignKeysEnabled = true // Default is already true
config.trace = { print($0) }     // Prints all SQL statements

let dbQueue = try DatabaseQueue(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Configuration](http://groue.github.io/GRDB.swift/docs/1.3/Structs/Configuration.html) for more details.


## Database Pools

**A Database Pool allows concurrent database accesses.**

When more efficient than [database queues](#database-queues), database pools also require a good mastery of database transactions. Details follow. If you don't feel comfortable with transactions, use a [database queue](#database-queues) instead.

```swift
import GRDB
let dbPool = try DatabasePool(path: "/path/to/database.sqlite")
```

SQLite creates the database file if it does not already exist. The connection is closed when the database pool gets deallocated.

> :point_up: **Note**: unless read-only, a database pool opens your database in the SQLite "WAL mode". The WAL mode does not fit all situations. Please have a look at https://www.sqlite.org/wal.html.


**A database pool can be used from any thread.** The `read`, `write` and `writeInTransaction` methods are synchronous, and block the current thread until your database statements are executed in a protected dispatch queue. They safely isolate the database accesses:

```swift
// Execute database statements:
try dbPool.write { db in
    try db.create(table: "places") { ... }
    try Place(...).insert(db)
}

// Wrap database statements in a transaction:
try dbPool.writeInTransaction { db in
    if let place = try Place.fetchOne(db, key: 1) {
        try place.delete(db)
    }
    return .commit
}

// Read values:
try dbPool.read { db in
    let places = try Place.fetchAll(db)
    let placeCount = try Place.fetchCount(db)
}

// Extract a value from the database:
let placeCount = try dbPool.read { db in
    try Place.fetchCount(db)
}
```

Database pools allow several threads to access the database at the same time:

- When you don't need to modify the database, prefer the `read` method, because several threads can perform reads in parallel.
    
    Reads are generally non-blocking, unless the maximum number of concurrent reads has been reached. In this case, a read has to wait for another read to complete. That maximum number can be [configured](#databasepool-configuration).

- Unlike reads, writes are serialized. There is never more than a single thread that is writing into the database.
    
- Reads are guaranteed an immutable view of the last committed state of the database, regardless of concurrent writes. This kind of isolation is called "snapshot isolation".
    
    To provide `read` closures an immutable view of the last executed writing block *as a whole*, use `writeInTransaction` instead of `write`.

**A database pool needs your application to follow rules in order to deliver its safety guarantees.** Please refer to the [Concurrency](#concurrency) chapter.

See [Advanced DatabasePool](#advanced-databasepool) for more DatabasePool hotness.

For a sample code that sets up a database pool on iOS, see [DemoApps/GRDBDemoiOS/Database.swift](DemoApps/GRDBDemoiOS/GRDBDemoiOS/Database.swift), and replace DatabaseQueue with DatabasePool.


### DatabasePool Configuration

```swift
var config = Configuration()
config.readonly = true
config.foreignKeysEnabled = true // Default is already true
config.trace = { print($0) }     // Prints all SQL statements
config.maximumReaderCount = 10   // The default is 5

let dbPool = try DatabasePool(
    path: "/path/to/database.sqlite",
    configuration: config)
```

See [Configuration](http://groue.github.io/GRDB.swift/docs/1.3/Structs/Configuration.html) for more details.


Database pools are more memory-hungry than database queues. See [Memory Management](#memory-management) for more information.
