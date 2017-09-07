Concurrency
===========

- [Guarantees and Rules](#guarantees-and-rules)
- [Advanced DatabasePool](#advanced-databasepool)
- [DatabaseWriter and DatabaseReader Protocols](#databasewriter-and-databasereader-protocols)
- [Unsafe Concurrency APIs](#unsafe-concurrency-apis)
- [Dealing with External Connections](#dealing-with-external-connections)


## Guarantees and Rules

GRDB ships with two concurrency modes:

- [DatabaseQueue](#database-queues) opens a single database connection, and serializes all database accesses.
- [DatabasePool](#database-pools) manages a pool of several database connections, and allows concurrent reads and writes.

**Both foster application safety**: regardless of the concurrency mode you choose, GRDB provides you with the same guarantees, as long as you follow three rules.

- :bowtie: **Guarantee 1: writes are always serialized**. At every moment, there is no more than a single thread that is writing into the database.

- :bowtie: **Guarantee 2: reads are always isolated**. This means that they are guaranteed an immutable view of the last committed state of the database, and that you can perform subsequent fetches without fearing eventual concurrent writes to mess with your application logic:
    
    ```swift
    try dbPool.read { db in // or dbQueue.inDatabase { ... }
        // Guaranteed to be equal
        let count1 = try Player.fetchCount(db)
        let count2 = try Player.fetchCount(db)
    }
    ```

- :bowtie: **Guarantee 3: requests don't fail**, unless a database constraint violation, a [programmer mistake](#error-handling), or a very low-level issue such as a disk error or an unreadable database file. GRDB grants *correct* use of SQLite, and particularly avoids locking errors and other SQLite misuses.

Those guarantees hold as long as you follow three rules:

- :point_up: **Rule 1**: Have a unique instance of DatabaseQueue or DatabasePool connected to any database file.
    
    This means that opening a new connection each time you access the database is probably a very bad idea. Do share a single connection instead.
    
    See, for example, [DemoApps/GRDBDemoiOS/Database.swift](DemoApps/GRDBDemoiOS/GRDBDemoiOS/Database.swift) for a sample code that properly sets up a single database queue that is available throughout the application.
    
    If there are several instances of database queues or pools that access the same database, a multi-threaded application will eventually face "database is locked" errors. See [Dealing with External Connections](#dealing-with-external-connections).
    
    ```swift
    // SAFE CONCURRENCY
    func currentUser(_ db: Database) throws -> User? {
        return try User.fetchOne(db)
    }
    // dbQueue is a singleton defined somewhere in your app
    let user = try dbQueue.inDatabase { db in // or dbPool.read { ... }
        try currentUser(db)
    }
    
    // UNSAFE CONCURRENCY
    // This method fails when some other thread is currently writing into
    // the database.
    func currentUser() throws -> User? {
        let dbQueue = try DatabaseQueue(...)
        return try dbQueue.inDatabase { db in
            try User.fetchOne(db)
        }
    }
    let user = try currentUser()
    ```
    
- :point_up: **Rule 2**: Group related statements within a single call to a DatabaseQueue or DatabasePool database access method.
    
    Those methods isolate your groups of related statements against eventual database updates performed by other threads, and guarantee a consistent view of the database. This isolation is only guaranteed *inside* the closure argument of those methods. Two consecutive calls *do not* guarantee isolation:
    
    ```swift
    // SAFE CONCURRENCY
    try dbPool.read { db in  // or dbQueue.inDatabase { ... }
        // Guaranteed to be equal:
        let count1 = try Place.fetchCount(db)
        let count2 = try Place.fetchCount(db)
    }
    
    // UNSAFE CONCURRENCY
    // Those two values may be different because some other thread may have
    // modified the database between the two blocks:
    let count1 = try dbPool.read { db in try Place.fetchCount(db) }
    let count2 = try dbPool.read { db in try Place.fetchCount(db) }
    ```
    
    In the same vein, when you fetch values that depends on some database updates, group them:
    
    ```swift
    // SAFE CONCURRENCY
    try dbPool.write { db in
        // The count is guaranteed to be non-zero
        try Place(...).insert(db)
        let count = try Place.fetchCount(db)
    }
    
    // UNSAFE CONCURRENCY
    // The count may be zero because some other thread may have performed
    // a deletion between the two blocks:
    try dbPool.write { db in try Place(...).insert(db) }
    let count = try dbPool.read { db in try Place.fetchCount(db) }
    ```
    
    On that last example, see [Advanced DatabasePool](#advanced-databasepool) if you look after extra performance.

- :point_up: **Rule 3**: When you perform several modifications of the database that temporarily put the database in an inconsistent state, group those modifications within a [transaction](#transactions-and-savepoints):
    
    ```swift
    // SAFE CONCURRENCY
    try dbPool.writeInTransaction { db in  // or dbQueue.inTransaction { ... }
        try Credit(destinationAccout, amount).insert(db)
        try Debit(sourceAccount, amount).insert(db)
        return .commit
    }
    
    // UNSAFE CONCURRENCY
    try dbPool.write { db in  // or dbQueue.inDatabase { ... }
        try Credit(destinationAccout, amount).insert(db)
        try Debit(sourceAccount, amount).insert(db)
    }
    ```
    
    Without transaction, `DatabasePool.read { ... }` may see the first statement, but not the second, and access a database where the balance of accounts is not zero. A highly bug-prone situation.
    
    So do use [transactions](#transactions-and-savepoints) in order to guarantee database consistency accross your application threads: that's what they are made for.


## Advanced DatabasePool

[Database pools](#database-pools) are very concurrent, since all reads can run in parallel, and can even run during write operations. But writes are still serialized: at any given point in time, there is no more than a single thread that is writing into the database.

When your application modifies the database, and then reads some value that depends on those modifications, you may want to avoid locking the writer queue longer than necessary:

```swift
try dbPool.write { db in
    // Increment the number of players
    try Player(...).insert(db)
    
    // Read the number of players. The writer queue is still locked :-(
    let count = try Player.fetchCount(db)
}
```

A wrong solution is to chain a write then a read, as below. Don't do that, because another thread may modify the database in between, and make the read unreliable:

```swift
// WRONG
try dbPool.write { db in
    // Increment the number of players
    try Player(...).insert(db)
}
try dbPool.read { db in
    // Read some random value :-(
    let count = try Player.fetchCount(db)
}
```

The correct solution is the `readFromCurrentState` method, which must be called from within a write block:

```swift
// CORRECT
try dbPool.write { db in
    // Increment the number of players
    try Player(...).insert(db)
    
    try dbPool.readFromCurrentState { db
        // Read the number of players. The writer queue has been unlocked :-)
        let count = try Player.fetchCount(db)
    }
}
```

`readFromCurrentState` blocks until it can guarantee its closure argument an isolated access to the last committed state of the database. It then asynchronously executes the closure. If the isolated access can't be established, `readFromCurrentState` throws an error, and the closure is not executed.

The closure can run concurrently with eventual updates performed after `readFromCurrentState`: those updates won't be visible from within the closure. In the example below, the number of players is guaranteed to be non-zero, even though it is fetched concurrently with the player deletion:

```swift
try dbPool.write { db in
    // Increment the number of players
    try Player(...).insert(db)
    
    try dbPool.readFromCurrentState { db
        // Guaranteed to be non-zero
        let count = try Player.fetchCount(db)
    }
    
    try Player.deleteAll(db)
}
```

[Transaction Observers](#transactionobserver-protocol) can also use `readFromCurrentState` in their `databaseDidCommit` method in order to process database changes without blocking other threads that want to write into the database.


## DatabaseWriter and DatabaseReader Protocols

Both DatabaseQueue and DatabasePool adopt the [DatabaseReader](http://groue.github.io/GRDB.swift/docs/1.3/Protocols/DatabaseReader.html) and [DatabaseWriter](http://groue.github.io/GRDB.swift/docs/1.3/Protocols/DatabaseWriter.html) protocols.

These protocols provide a unified API that lets you write safe concurrent code that targets both classes.

However, database queues are not database pools, and DatabaseReader and DatabaseWriter provide the *smallest* common guarantees. They require more discipline:

- Pools are less forgiving than queues when one overlooks a transaction (see [concurrency rule 3](#guarantees-and-rules)).
- DatabaseWriter.readFromCurrentState is synchronous, or asynchronous, depending on whether it is run by a queue or a pool (see [advanced DatabasePool](#advanced-databasepool)). It thus requires higher libDispatch skills, and more complex synchronization code.
- The definition of "current state" in DatabaseWriter.readFromCurrentState is [delicate](http://groue.github.io/GRDB.swift/docs/1.3/Protocols/DatabaseWriter.html#/s:FP4GRDB14DatabaseWriter20readFromCurrentStateFzFCS_8DatabaseT_T_).

DatabaseReader and DatabaseWriter are not a tool for applications that hesitate between DatabaseQueue and DatabasePool, and look for a common API. As seen above, the protocols actually make applications harder to write correctly. Instead, they target reusable agnostic code that has *both* queues and pools in mind. For example, GRDB uses those protocols for [migrations](#migrations) and [FetchedRecordsController](#fetchedrecordscontroller), two tools that accept both queues and pools.


## Unsafe Concurrency APIs

**Database queues, pools, as well as their common protocols `DatabaseReader` and `DatabaseWriter` provide *unsafe* APIs.** Unsafe APIs lift [concurrency guarantees](#guarantees-and-rules), and allow advanced yet unsafe patterns.

- **`unsafeRead`**
    
    The `unsafeRead` method is synchronous, and blocks the current thread until your database statements are executed in a protected dispatch queue. GRDB does just the bare minimum to provide a database connection that can read.
    
    When used on a database pool, reads are no longer isolated:
    
    ```swift
    dbPool.unsafeRead { db in
        // Those two values may be different because some other thread
        // may have inserted or deleted a player between the two requests:
        let count1 = try Player.fetchCount(db)
        let count2 = try Player.fetchCount(db)
    }
    ```
    
    When used on a datase queue, the closure argument is allowed to write in the database.
    
- **`unsafeReentrantRead`**
    
    The `unsafeReentrantRead` behaves just as `unsafeRead` (see above), and allows reentrant calls:
    
    ```swift
    dbPool.read { db1 in
        // No "Database methods are not reentrant" fatal error:
        dbPool.unsafeReentrantRead { db2 in
            dbPool.unsafeReentrantRead { db3 in
                ...
            }
        }
    }
    ```
    
    Reentrant database accesses make it very easy to break the second [safety rule](#guarantees-and-rules), which says: "group related statements within a single call to a DatabaseQueue or DatabasePool database access method.". Using a reentrant method is pretty much likely the sign of a wrong application architecture that needs refactoring.
    
    Reentrant methods have been introduced in order to support [RxGRDB](http://github.com/RxSwiftCommunity/RxGRDB), a set of reactive extensions to GRDB based on [RxSwift](https://github.com/ReactiveX/RxSwift) that need precise scheduling.
    
- **`unsafeReentrantWrite`**
    
    The `unsafeReentrantWrite` method is synchronous, and blocks the current thread until your database statements are executed in a protected dispatch queue. Writes are serialized: eventual concurrent database updates are postponed until the block has executed.
    
    Reentrant calls are allowed:
    
    ```swift
    dbQueue.inDatabase { db1 in
        // No "Database methods are not reentrant" fatal error:
        dbQueue.unsafeReentrantWrite { db2 in
            dbQueue.unsafeReentrantWrite { db3 in
                ...
            }
        }
    }
    ```
    
    Reentrant database accesses make it very easy to break the second [safety rule](#guarantees-and-rules), which says: "group related statements within a single call to a DatabaseQueue or DatabasePool database access method.". Using a reentrant method is pretty much likely the sign of a wrong application architecture that needs refactoring.
    
    Reentrant methods have been introduced in order to support [RxGRDB](http://github.com/RxSwiftCommunity/RxGRDB), a set of reactive extensions to GRDB based on [RxSwift](https://github.com/ReactiveX/RxSwift) that need precise scheduling.


## Dealing with External Connections

The first rule of GRDB is:

- **[Rule 1](#guarantees-and-rules)**: Have a unique instance of DatabaseQueue or DatabasePool connected to any database file.

This means that dealing with external connections is not a focus of GRDB. [Guarantees](#guarantees-and-rules) of GRDB may or may not hold as soon as some external connection modifies a database.

If you absolutely need multiple connections, then:

- Reconsider your position
- Read about [isolation in SQLite](https://www.sqlite.org/isolation.html)
- Learn about [locks and transactions](https://www.sqlite.org/lang_transaction.html)
- Become a master of the [WAL mode](https://www.sqlite.org/wal.html)
- Prepare to setup a [busy handler](https://www.sqlite.org/c3ref/busy_handler.html) with [Configuration.busyMode](http://groue.github.io/GRDB.swift/docs/1.3/Structs/Configuration.html)
- [Ask questions](https://github.com/groue/GRDB.swift/issues)
