Database Observation
====================

**SQLite notifies its host application of changes performed to the database, as well of transaction commits and rollbacks.**

GRDB puts this SQLite feature to some good use, and lets you observe the database in various ways:

- [After Commit Hook](#after-commit-hook): The simplest way to handle successful transactions.
- [TransactionObserver Protocol](#transactionobserver-protocol): The low-level protocol for database observation
    - [Activate a Transaction Observer](#activate-a-transaction-observer)
    - [Database Changes And Transactions](#database-changes-and-transactions)
    - [Filtering Database Events](#filtering-database-events)
    - [Observation Extent](#observation-extent)
    - [Support for SQLite Pre-Update Hooks](#support-for-sqlite-pre-update-hooks)
- [FetchedRecordsController](#fetchedrecordscontroller): Automated tracking of changes in a query results, plus UITableView animations
- [RxGRDB](http://github.com/RxSwiftCommunity/RxGRDB): Automated tracking of changes in a query results, based on [RxSwift](https://github.com/ReactiveX/RxSwift)

Database observation requires that a single [database queue](#database-queues) or [pool](#database-pools) is kept open for all the duration of the database usage.


## After Commit Hook

**When your application needs to make sure a database transaction has been successfully committed before it executes some work, use the `Database.afterNextTransactionCommit(_:)` method.**

Its closure argument is called right after database changes have been successfully written to disk:

```swift
dbQueue.inTransaction { db in
    db.afterNextTransactionCommit { db in
        print("success")
    }
    ...
    return .commit // prints "success"
}
```

The closure runs in a protected dispatch queue, serialized with all database updates.

**This "after commit hook" helps synchronizing the database with other resources, such as files, or system sensors.**

In the example below, a [location manager](https://developer.apple.com/documentation/corelocation/cllocationmanager) starts monitoring a CLRegion if and only if it has successfully been stored in the database:

```swift
/// Inserts a region in the database, and start monitoring upon
/// successful insertion.
func startMonitoring(_ db: Database, region: CLRegion) throws {
    // Make sure database is inside a transaction
    try db.inSavepoint {
        
        // Save the region in the database
        try insert(...)
        
        // Start monitoring if and only if the insertion is
        // eventually committed
        db.afterNextTransactionCommit { _ in
            // locationManager prefers the main queue:
            DispatchQueue.main.async {
                locationManager.startMonitoring(for: region)
            }
        }
        
        return .commit
    }
}
```

The method above won't trigger the location manager if the transaction is eventually rollbacked (explicitely, or because of an error), as in the sample code below:

```swift
try dbQueue.inTransaction { db in
    // success
    try startMonitoring(db, region)
    
    // On error, the transaction is rollbacked, the region is not inserted, and
    // the location manager is not invoked.
    try failableMethod(db)
    
    return .commit
}
```


## TransactionObserver Protocol

The `TransactionObserver` protocol lets you **observe database changes and transactions**:

```swift
protocol TransactionObserver : class {
    /// Filters database changes that should be notified the the
    /// `databaseDidChange(with:)` method.
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool
    
    /// Notifies a database change:
    /// - event.kind (insert, update, or delete)
    /// - event.tableName
    /// - event.rowID
    ///
    /// For performance reasons, the event is only valid for the duration of
    /// this method call. If you need to keep it longer, store a copy:
    /// event.copy().
    func databaseDidChange(with event: DatabaseEvent)
    
    /// An opportunity to rollback pending changes by throwing an error.
    func databaseWillCommit() throws
    
    /// Database changes have been committed.
    func databaseDidCommit(_ db: Database)
    
    /// Database changes have been rollbacked.
    func databaseDidRollback(_ db: Database)
}
```

- [Activate a Transaction Observer](#activate-a-transaction-observer)
- [Database Changes And Transactions](#database-changes-and-transactions)
- [Filtering Database Events](#filtering-database-events)
- [Observation Extent](#observation-extent)
- [Support for SQLite Pre-Update Hooks](#support-for-sqlite-pre-update-hooks)


### Activate a Transaction Observer

**To activate a transaction observer, add it to the database queue or pool:**

```swift
let observer = MyObserver()
dbQueue.add(transactionObserver: observer)
```

By default, database holds weak references to its transaction observers: they are not retained, and stop getting notifications after they are deallocated. See [Observation Extent](#observation-extent) for more options.


### Database Changes And Transactions

**A transaction observer is notified of all database changes**: inserts, updates and deletes. This includes indirect changes triggered by ON DELETE and ON UPDATE actions associated to [foreign keys](https://www.sqlite.org/foreignkeys.html#fk_actions).

> :point_up: **Note**: the changes that are not notified are changes to internal system tables (such as `sqlite_master`), changes to [`WITHOUT ROWID`](https://www.sqlite.org/withoutrowid.html) tables, and the deletion of duplicate rows triggered by [`ON CONFLICT REPLACE`](https://www.sqlite.org/lang_conflict.html) clauses (this last exception might change in a future release of SQLite).

Notified changes are not actually written to disk until `databaseDidCommit` is called. On the other side, `databaseDidRollback` confirms their invalidation:

```swift
try dbQueue.inTransaction { db in
    try db.execute("INSERT ...") // 1. didChange
    try db.execute("UPDATE ...") // 2. didChange
    return .commit               // 3. willCommit, 4. didCommit
}

try dbQueue.inTransaction { db in
    try db.execute("INSERT ...") // 1. didChange
    try db.execute("UPDATE ...") // 2. didChange
    return .rollback             // 3. didRollback
}
```

Database statements that are executed outside of an explicit transaction do not drop off the radar:

```swift
try dbQueue.inDatabase { db in
    try db.execute("INSERT ...") // 1. didChange, 2. willCommit, 3. didCommit
    try db.execute("UPDATE ...") // 4. didChange, 5. willCommit, 6. didCommit
}
```

Changes that are on hold because of a [savepoint](https://www.sqlite.org/lang_savepoint.html) are only notified after the savepoint has been released. This makes sure that notified events are only events that have an opportunity to be committed:

```swift
try dbQueue.inTransaction { db in
    try db.execute("INSERT ...")            // 1. didChange
    
    try db.execute("SAVEPOINT foo")
    try db.execute("UPDATE ...")            // delayed
    try db.execute("UPDATE ...")            // delayed
    try db.execute("RELEASE SAVEPOINT foo") // 2. didChange, 3. didChange
    
    try db.execute("SAVEPOINT foo")
    try db.execute("UPDATE ...")            // not notified
    try db.execute("ROLLBACK TO SAVEPOINT foo")
    
    return .commit                          // 4. willCommit, 5. didCommit
}
```


**Eventual errors** thrown from `databaseWillCommit` are exposed to the application code:

```swift
do {
    try dbQueue.inTransaction { db in
        ...
        return .commit           // 1. willCommit (throws), 2. didRollback
    }
} catch {
    // 3. The error thrown by the transaction observer.
}
```

> :point_up: **Note**: all callbacks are called in a protected dispatch queue, and serialized with all database updates.
>
> :point_up: **Note**: the databaseDidChange(with:) and databaseWillCommit() callbacks must not touch the SQLite database. This limitation does not apply to databaseDidCommit and databaseDidRollback which can use their database argument.

[FetchedRecordsController](#fetchedrecordscontroller) and [RxGRDB](http://github.com/RxSwiftCommunity/RxGRDB) are based on the TransactionObserver protocol.

See also [TableChangeObserver.swift](https://gist.github.com/groue/2e21172719e634657dfd), which shows a transaction observer that notifies of modified database tables with NSNotificationCenter.


### Filtering Database Events

**Transaction observers can avoid being notified of database changes they are not interested in.**

The filtering happens in the `observes(eventsOfKind:)` method, which tells whether the observer wants notification of specific kinds of changes, or not. For example, here is how an observer can focus on the changes that happen on the "players" database table:

```swift
class PlayerObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        // Only observe changes to the "players" table.
        return eventKind.tableName == "players"
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        // This method is only called for changes that happen to
        // the "players" table.
    }
}
```

Generally speaking, the `observes(eventsOfKind:)` method can distinguish insertions from deletions and updates, and is also able to inspect the columns that are about to be changed:

```swift
class PlayerScoreObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        // Only observe changes to the "score" column of the "players" table.
        switch eventKind {
        case .insert(let tableName):
            return tableName == "players"
        case .delete(let tableName):
            return tableName == "players"
        case .update(let tableName, let columnNames):
            return tableName == "players" && columnNames.contains("score")
        }
    }
}
```

When the `observes(eventsOfKind:)` method returns false for all event kinds, the observer is still notified of commits and rollbacks:

```swift
class PureTransactionObserver: TransactionObserver {
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        // Ignore all individual changes
        return false
    }
    
    func databaseDidChange(with event: DatabaseEvent) { /* Never called */ }
    func databaseWillCommit() throws { /* Called before commit */ }
    func databaseDidRollback(_ db: Database) { /* Called on rollback */ }
    func databaseDidCommit(_ db: Database) { /* Called on commit */ }
}
```


### Observation Extent

**You can specify how long an observer is notified of database changes and transactions.**

The `remove(transactionObserver:)` method explicitely stops notifications, at any time:

```swift
// From a database queue or pool:
dbQueue.remove(transactionObserver: observer)

// From a database connection:
dbQueue.inDatabase { db in // or dbPool.write
    db.remove(transactionObserver: observer)
}
```

Alternatively, use the `extent` parameter of the `add(transactionObserver:extent:)` method:

```swift
let observer = MyObserver()

// On a database queue or pool:
dbQueue.add(transactionObserver: observer) // default extent
dbQueue.add(transactionObserver: observer, extent: .observerLifetime)
dbQueue.add(transactionObserver: observer, extent: .nextTransaction)
dbQueue.add(transactionObserver: observer, extent: .databaseLifetime)

// On a database connection:
dbQueue.inDatabase { db in
    db.add(transactionObserver: ...)
}
```

- The default extent is `.observerLifetime`: the database holds a weak reference to the observer, and the observation automatically ends when the observer is deallocated. Meanwhile, observer is notified of all changes and transactions.

- `.nextTransaction` activates the observer until the current or next transaction completes. The database keeps a strong reference to the observer until its `databaseDidCommit` or `databaseDidRollback` method is eventually called. Hereafter the observer won't get any further notification.

- `.databaseLifetime` has the database retain and notify the observer until the database connection is closed.


### Support for SQLite Pre-Update Hooks

A [custom SQLite build](Documentation/CustomSQLiteBuilds.md) can activate [SQLite "preupdate hooks"](http://www.sqlite.org/sessions/c3ref/preupdate_count.html). In this case, TransactionObserverType gets an extra callback which lets you observe individual column values in the rows modified by a transaction:

```swift
protocol TransactionObserverType : class {
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    /// Notifies before a database change (insert, update, or delete)
    /// with change information (initial / final values for the row's
    /// columns).
    ///
    /// The event is only valid for the duration of this method call. If you
    /// need to keep it longer, store a copy: event.copy().
    func databaseWillChange(with event: DatabasePreUpdateEvent)
    #endif
}
```


